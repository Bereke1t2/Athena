// Package chat implements grounded, streaming paper chat (ADR-0004,
// docs/architecture/ai-rag.md §7): retrieval-assembled context, the grounding
// contract baked into prompts, post-generation citation validation with one
// regeneration attempt, and honest refusal when evidence is insufficient.
package chat

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"

	appai "athena/backend/internal/application/ai"
	domainai "athena/backend/internal/domain/ai"
	"athena/backend/internal/domain/research"
)

// RefusalSentence is the exact string the grounding contract mandates when
// evidence is insufficient.
const RefusalSentence = "The provided material does not contain enough evidence to answer this."

// SessionStore persists chat sessions/messages (implemented by AIStore).
type SessionStore interface {
	CreateSession(ctx context.Context, in domainai.NewSessionInput) (domainai.Session, error)
	GetSession(ctx context.Context, id uuid.UUID) (domainai.Session, error)
	ListMessages(ctx context.Context, sessionID uuid.UUID, limit int) ([]domainai.Message, error)
	AppendMessage(ctx context.Context, m domainai.Message) (domainai.Message, error)
}

// PaperSource loads the paper metadata card for context assembly.
type PaperSource interface {
	GetDetailByID(ctx context.Context, id uuid.UUID) (research.PaperDetail, error)
}

var chunkRefRe = regexp.MustCompile(`\[chunk (\d+)\]`)

// Service orchestrates grounded single-paper conversations.
type Service struct {
	LLM       domainai.LLMProvider // nil ⇒ AI disabled upstream
	Sessions  SessionStore
	Retriever domainai.ChunkRetriever // nil ⇒ metadata-only grounding
	Papers    PaperSource
	Logger    *slog.Logger

	// Indexer optionally builds full-text chunks on first use.
	Indexer appai.Indexer

	HistoryTurns int
	TopK         int

	indexTimeout time.Duration
}

func NewService(llm domainai.LLMProvider, sessions SessionStore,
	retriever domainai.ChunkRetriever, papers PaperSource, log *slog.Logger) *Service {
	return &Service{LLM: llm, Sessions: sessions, Retriever: retriever,
		Papers: papers, Logger: log, HistoryTurns: 8, TopK: 8,
		indexTimeout: 30 * time.Second}
}

// CreateSession opens a single-paper chat container.
func (s *Service) CreateSession(ctx context.Context, in domainai.NewSessionInput) (domainai.Session, error) {
	return s.Sessions.CreateSession(ctx, in)
}

// Messages lists the transcript oldest-first.
func (s *Service) Messages(ctx context.Context, sessionID uuid.UUID) ([]domainai.Message, error) {
	if _, err := s.Sessions.GetSession(ctx, sessionID); err != nil {
		return nil, mapReadErr(err)
	}
	return s.Sessions.ListMessages(ctx, sessionID, 0)
}

// Ask answers one question: stores the user turn, streams grounded deltas to
// onDelta, validates citations (regenerating once on failure), then stores
// and returns the final assistant message.
func (s *Service) Ask(ctx context.Context, sessionID uuid.UUID, question string, onDelta func(string)) (domainai.Message, error) {
	session, err := s.Sessions.GetSession(ctx, sessionID)
	if err != nil {
		return domainai.Message{}, mapReadErr(err)
	}
	question = strings.TrimSpace(question)
	if question == "" {
		return domainai.Message{}, fmt.Errorf("%w: empty question", domainai.ErrInvalidQuery)
	}

	detail, err := s.Papers.GetDetailByID(ctx, session.PaperID)
	if err != nil {
		if errors.Is(err, research.ErrNotFound) {
			return domainai.Message{}, domainai.ErrNotFound
		}
		return domainai.Message{}, err
	}

	chunks := s.retrieve(ctx, session.PaperID, question)

	if _, err := s.Sessions.AppendMessage(ctx, domainai.Message{
		SessionID: sessionID, Role: domainai.RoleUser, Content: question,
	}); err != nil {
		s.Logger.Error("Ask append user message failed", "error", err)
		return domainai.Message{}, fmt.Errorf("store user message: %w", err)
	}

	if s.LLM == nil {
		return domainai.Message{}, domainai.ErrNotGrounded // AI disabled
	}

	history := s.historyWindow(ctx, sessionID)
	answer, usage, modelID := s.groundedAnswer(ctx, detail, chunks, history, question, onDelta)

	cited := citedChunkIndices(answer, len(chunks))
	refused := strings.Contains(answer, RefusalSentence)
	if len(chunks) > 0 && len(cited) == 0 && !refused {
		s.Logger.Warn("citation validation failed; regenerating", "session", sessionID)
		answer2, usage2, model2 := s.groundedAnswerStrict(ctx, detail, chunks, question, answer, onDelta)
		usage.TotalTokens += usage2.TotalTokens
		if idx2 := citedChunkIndices(answer2, len(chunks)); len(idx2) > 0 || strings.Contains(answer2, RefusalSentence) {
			answer, modelID = answer2, model2
			cited, refused = idx2, strings.Contains(answer2, RefusalSentence)
		} else {
			answer, refused = RefusalSentence, true
			modelID += "+refused"
		}
	}

	switch {
	case len(cited) > 0:
		appai.RecordChatStatus("ok")
	case refused:
		appai.RecordChatStatus("refused")
	default:
		appai.RecordChatStatus("uncited")
	}

	msg, err := s.Sessions.AppendMessage(ctx, domainai.Message{
		SessionID:  sessionID,
		Role:       domainai.RoleAssistant,
		Content:    answer,
		Citations:  citationsFor(cited, chunks),
		ModelID:    modelID,
		TokenUsage: usage,
	})
	if err != nil {
		return domainai.Message{}, fmt.Errorf("store assistant message: %w", err)
	}
	return msg, nil
}

// retrieve wraps hybrid retrieval; failures degrade to metadata-only so the
// model refuses honestly instead of hallucinating. An empty result triggers
// one lazy full-text indexing attempt before giving up.
func (s *Service) retrieve(ctx context.Context, paperID uuid.UUID, question string) []domainai.RetrievedChunk {
	if s.Retriever == nil {
		return nil
	}
	q := domainai.ChunkQuery{PaperID: paperID, Question: question, TopK: s.TopK}
	chunks, err := s.Retriever.Retrieve(ctx, q)
	if err != nil {
		s.Logger.Warn("chat retrieval failed; answering from metadata only", "error", err)
		return nil
	}
	if len(chunks) == 0 && s.Indexer != nil {
		ictx, cancel := context.WithTimeout(ctx, s.indexTimeout)
		defer cancel()
		if _, ierr := s.Indexer.IngestPaper(ictx, paperID); ierr != nil {
			s.Logger.Info("lazy rag indexing unavailable; metadata grounding",
				"paper_id", paperID, "error", ierr)
			return nil
		}
		if chunks, err = s.Retriever.Retrieve(ctx, q); err != nil {
			return nil
		}
	}
	return chunks
}

func (s *Service) historyWindow(ctx context.Context, sessionID uuid.UUID) []domainai.HistoryTurn {
	msgs, err := s.Sessions.ListMessages(ctx, sessionID, s.HistoryTurns*2+4)
	if err != nil {
		return nil
	}
	if max := s.HistoryTurns * 2; len(msgs) > max {
		msgs = msgs[len(msgs)-max:]
	}
	turns := make([]domainai.HistoryTurn, 0, len(msgs))
	for _, m := range msgs {
		turns = append(turns, domainai.HistoryTurn{Role: m.Role, Content: m.Content})
	}
	return turns
}

func (s *Service) buildContext(d research.PaperDetail, chunks []domainai.RetrievedChunk) string {
	var b strings.Builder
	fmt.Fprintf(&b, "PAPER: %s\n", d.Summary.Title)
	if d.Summary.Abstract != nil && *d.Summary.Abstract != "" {
		fmt.Fprintf(&b, "ABSTRACT: %s\n", *d.Summary.Abstract)
	}

	b.WriteString("\n### CONTEXT\n")
	if len(chunks) == 0 {
		b.WriteString("(No full-text excerpts are available for this paper — you may only use the title/abstract above. State this limitation if relevant.)\n")
		return b.String()
	}
	for i, c := range chunks {
		label := firstNonEmpty(c.SectionPath, c.Heading, "body")
		fmt.Fprintf(&b, "\n[chunk %d] (%s)\n%s\n", i+1, label, truncate(c.Content, 4000))
	}
	return b.String()
}

func (s *Service) runStream(ctx context.Context, system, prompt string, onDelta func(string)) (string, domainai.TokenUsage, string, error) {
	stream, err := s.LLM.GenerateStream(ctx, domainai.GenerateRequest{
		System: system, Prompt: prompt, Temperature: 0.3, MaxTokens: 900,
	})
	if err != nil {
		s.Logger.Error("open stream failed", "error", err)
		appai.RecordChatStatus("error")
		return "", domainai.TokenUsage{}, s.LLM.Model(), fmt.Errorf("open stream: %w", err)
	}
	defer stream.Close()

	var b strings.Builder
	for {
		delta, err := stream.Next(ctx)
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return "", domainai.TokenUsage{}, s.LLM.Model(), fmt.Errorf("stream: %w", err)
		}
		b.WriteString(delta)
		if onDelta != nil {
			onDelta(delta)
		}
	}
	text := strings.TrimSpace(b.String())
	usage := appai.EstimateUsage(system+prompt, text)
	appai.RecordUsage("chat", s.LLM.Model(), usage)
	return text, usage, s.LLM.Model(), nil
}

func (s *Service) groundedAnswer(ctx context.Context, d research.PaperDetail,
	chunks []domainai.RetrievedChunk, history []domainai.HistoryTurn,
	question string, onDelta func(string)) (string, domainai.TokenUsage, string) {

	system := appai.GroundingSystem()
	if len(chunks) == 0 {
		system = `You are Athena, a careful research assistant.

Rules you must never break:
1. Answer using the provided title and abstract context.
2. Distinguish findings from interpretation from speculation; keep stated limitations.
3. If the title/abstract is insufficient to answer, reply exactly: "The provided material does not contain enough evidence to answer this."
4. Numbers and statistics must appear verbatim in the context or be omitted.
5. Never invent citations, authors, papers, or figures.`
	}

	var b strings.Builder
	b.WriteString(s.buildContext(d, chunks))
	b.WriteString("\n### HISTORY\n")
	b.WriteString(renderHistory(history))
	b.WriteString("\n### QUESTION\n")
	b.WriteString(question)
	b.WriteString("\n\n")
	if len(chunks) > 0 {
		b.WriteString("Answer from the context only, citing [chunk N]. If it is not there, reply exactly:\n")
	} else {
		b.WriteString("Answer from the title and abstract context above. If the title/abstract is insufficient, reply exactly:\n")
	}
	b.WriteString(RefusalSentence)

	text, usage, model, err := s.runStream(ctx, system, b.String(), onDelta)
	if err != nil {
		s.Logger.Error("chat generation failed", "error", err, "prompt", b.String())
		return RefusalSentence, usage, "failed:" + model
	}
	s.Logger.Info("chat generated response", "text", text, "model", model)
	return text, usage, model
}

func (s *Service) groundedAnswerStrict(ctx context.Context, d research.PaperDetail,
	chunks []domainai.RetrievedChunk, question, badAnswer string, onDelta func(string)) (string, domainai.TokenUsage, string) {

	system := appai.GroundingSystem() + `

CRITICAL: Your previous answer violated citation rules. Every claim must carry a [chunk N] marker that exists in the provided CONTEXT, or you must refuse with exactly:
` + RefusalSentence

	prompt := s.buildContext(d, chunks) +
		"\n### QUESTION\n" + question +
		"\n\nPrevious invalid answer:\n" + truncate(badAnswer, 800) +
		"\n\nRewrite the answer correctly or refuse."

	text, usage, model, err := s.runStream(ctx, system, prompt, onDelta)
	if err != nil {
		return RefusalSentence, usage, "failed:" + model
	}
	return text, usage, model
}

// citedChunkIndices extracts [chunk N] references that exist in the retrieved
// set. Any unknown index invalidates the whole answer.
func citedChunkIndices(answer string, n int) []int {
	seen := map[int]bool{}
	valid := true
	found := false
	for _, m := range chunkRefRe.FindAllStringSubmatch(answer, -1) {
		found = true
		idx, err := strconv.Atoi(m[1])
		if err != nil || idx < 1 || idx > n {
			valid = false
			continue
		}
		seen[idx] = true
	}
	if !found || !valid {
		return nil
	}
	out := make([]int, 0, len(seen))
	for i := range seen {
		out = append(out, i)
	}
	sortInts(out)
	return out
}

func citationsFor(indices []int, chunks []domainai.RetrievedChunk) []domainai.Citation {
	out := make([]domainai.Citation, 0, len(indices))
	for _, i := range indices {
		c := chunks[i-1]
		out = append(out, domainai.Citation{
			ChunkID:     c.ID,
			SectionPath: firstNonEmpty(c.SectionPath, c.Heading),
			Quote:       firstSentence(c.Content),
		})
	}
	return out
}

func renderHistory(turns []domainai.HistoryTurn) string {
	if len(turns) == 0 {
		return "(new conversation)"
	}
	var b strings.Builder
	for _, t := range turns {
		var role string
		switch t.Role {
		case domainai.RoleUser:
			role = "USER"
		case domainai.RoleAssistant:
			role = "ASSISTANT"
		default:
			continue
		}
		fmt.Fprintf(&b, "%s: %s\n", role, truncate(t.Content, 600))
	}
	return b.String()
}

func firstSentence(s string) string {
	s = strings.TrimSpace(s)
	for i := 0; i < len(s); i++ {
		if (s[i] == '.' || s[i] == '!' || s[i] == '?') &&
			(i+1 >= len(s) || s[i+1] == ' ' || s[i+1] == '\n') {
			return s[:i+1]
		}
	}
	return truncate(s, 140)
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}

func sortInts(a []int) {
	for i := 1; i < len(a); i++ {
		for j := i; j > 0 && a[j] < a[j-1]; j-- {
			a[j], a[j-1] = a[j-1], a[j]
		}
	}
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}

func mapReadErr(err error) error {
	if errors.Is(err, domainai.ErrNotFound) || errors.Is(err, research.ErrNotFound) {
		return domainai.ErrNotFound
	}
	return err
}
