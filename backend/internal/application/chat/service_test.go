package chat

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"strings"
	"testing"

	"github.com/google/uuid"

	domainai "athena/backend/internal/domain/ai"
	"athena/backend/internal/domain/research"
)

// ---- fakes ------------------------------------------------------------------

type fakeChatLLM struct {
	responses  []string // popped per stream open
	streams    int
	lastSys    string
	lastPrompt string
}

func (f *fakeChatLLM) Model() string { return "fake-chat-1" }

func (f *fakeChatLLM) Generate(context.Context, domainai.GenerateRequest) (domainai.GenerateResponse, error) {
	return domainai.GenerateResponse{}, errors.New("unused")
}

func (f *fakeChatLLM) GenerateStream(_ context.Context, req domainai.GenerateRequest) (domainai.StreamReader, error) {
	f.streams++
	f.lastSys = req.System
	f.lastPrompt = req.Prompt
	resp := RefusalSentence
	if len(f.responses) > 0 {
		resp = f.responses[0]
		f.responses = f.responses[1:]
	}
	return &sliceStream{words: strings.Fields(resp)}, nil
}

type sliceStream struct {
	words []string
	i     int
}

func (s *sliceStream) Next(context.Context) (string, error) {
	if s.i >= len(s.words) {
		return "", io.EOF
	}
	t := s.words[s.i] + " "
	s.i++
	return t, nil
}

func (s *sliceStream) Close() error { return nil }

type fakeSessions struct {
	sessions map[uuid.UUID]domainai.Session
	messages []domainai.Message
}

func (f *fakeSessions) CreateSession(_ context.Context, in domainai.NewSessionInput) (domainai.Session, error) {
	s := domainai.Session{ID: uuid.New(), PaperID: in.PaperID, Title: in.Title}
	if f.sessions == nil {
		f.sessions = map[uuid.UUID]domainai.Session{}
	}
	f.sessions[s.ID] = s
	return s, nil
}

func (f *fakeSessions) GetSession(_ context.Context, id uuid.UUID) (domainai.Session, error) {
	if s, ok := f.sessions[id]; ok {
		return s, nil
	}
	return domainai.Session{}, domainai.ErrNotFound
}

func (f *fakeSessions) ListMessages(_ context.Context, sessionID uuid.UUID, limit int) ([]domainai.Message, error) {
	var out []domainai.Message
	for _, m := range f.messages {
		if m.SessionID == sessionID {
			out = append(out, m)
		}
	}
	if limit > 0 && len(out) > limit {
		out = out[len(out)-limit:]
	}
	return out, nil
}

func (f *fakeSessions) AppendMessage(_ context.Context, m domainai.Message) (domainai.Message, error) {
	m.ID = uuid.New()
	f.messages = append(f.messages, m)
	return m, nil
}

type fakeRetriever struct{ chunks []domainai.RetrievedChunk }

func (f *fakeRetriever) Retrieve(context.Context, domainai.ChunkQuery) ([]domainai.RetrievedChunk, error) {
	return f.chunks, nil
}

type fakeChatPapers struct{}

func (f *fakeChatPapers) GetDetailByID(context.Context, uuid.UUID) (research.PaperDetail, error) {
	abs := "Transformers beat RNNs."
	return research.PaperDetail{
		Summary: research.PaperSummary{
			ID: uuid.New(), Title: "Attention Is All You Need", Abstract: &abs,
		},
	}, nil
}

// ---- fixtures ----------------------------------------------------------------

func twoChunks() []domainai.RetrievedChunk {
	return []domainai.RetrievedChunk{
		{Chunk: domainai.Chunk{ID: uuid.New(), Seq: 0, SectionPath: "3. Methods",
			Content: "We trained on eight GPUs. The model uses multi-head attention."}, Score: 1.2},
		{Chunk: domainai.Chunk{ID: uuid.New(), Seq: 1, Heading: "Results",
			Content: "BLEU score reached 28.4 on WMT14."}, Score: 0.9},
	}
}

func newHarness(t *testing.T, responses []string, chunks []domainai.RetrievedChunk) (*Service, *fakeSessions, *fakeChatLLM) {
	t.Helper()
	llm := &fakeChatLLM{responses: responses}
	sessions := &fakeSessions{}
	retriever := &fakeRetriever{chunks: chunks}
	svc := NewService(llm, sessions, retriever, &fakeChatPapers{},
		slog.New(slog.DiscardHandler))
	return svc, sessions, llm
}

// ---- tests ------------------------------------------------------------------

// Acceptance: "Chat answers carry valid citations…"
func TestAskStreamsGroundedAnswerWithCitations(t *testing.T) {
	answer := "The model uses multi-head attention [chunk 1] and reached 28.4 BLEU [chunk 2]."
	svc, sessions, llm := newHarness(t, []string{answer}, twoChunks())

	var streamed strings.Builder
	msg, err := svc.Ask(context.Background(),
		mustSession(t, svc), "What architecture did they use?",
		func(d string) { streamed.WriteString(d) })
	if err != nil {
		t.Fatal(err)
	}
	if msg.Content != answer {
		t.Fatalf("content mismatch: %q", msg.Content)
	}
	if len(msg.Citations) != 2 {
		t.Fatalf("want 2 citations, got %+v", msg.Citations)
	}
	if msg.Citations[0].Quote == "" || msg.Citations[0].SectionPath != "3. Methods" {
		t.Fatalf("citation metadata missing: %+v", msg.Citations[0])
	}
	if !strings.Contains(streamed.String(), "multi-head") && llm.streams == 1 {
		t.Fatalf("deltas not streamed: %q", streamed.String())
	}
	if llm.streams != 1 {
		t.Fatalf("valid first answer must not regenerate, streams=%d", llm.streams)
	}

	// Transcript persisted: user question + assistant answer.
	all, _ := sessions.ListMessages(context.Background(), msg.SessionID, 0)
	if len(all) != 2 || all[0].Role != domainai.RoleUser || all[1].Role != domainai.RoleAssistant {
		t.Fatalf("transcript wrong: %+v", all)
	}
}

// A fabricated [chunk 9] must trigger exactly one strict regeneration.
func TestAskRegeneratesOnceOnInvalidCitation(t *testing.T) {
	bad := "Invented claim citing nothing real [chunk 9]."
	good := "Grounded statement [chunk 1]."
	svc, _, llm := newHarness(t, []string{bad, good}, twoChunks())

	msg, err := svc.Ask(context.Background(), mustSession(t, svc), "?", nil)
	if err != nil {
		t.Fatal(err)
	}
	if llm.streams != 2 {
		t.Fatalf("want exactly one regeneration, streams=%d", llm.streams)
	}
	if msg.Content != good || len(msg.Citations) != 1 {
		t.Fatalf("regenerated answer wrong: %q", msg.Content)
	}
}

// Acceptance: "…or explicit 'insufficient evidence' refusal on adversarial questions."
func TestAskRefusesWhenEvidenceInsufficient(t *testing.T) {
	svc, _, _ := newHarness(t, []string{RefusalSentence}, twoChunks())
	msg, err := svc.Ask(context.Background(), mustSession(t, svc), "What is the meaning of life?", nil)
	if err != nil {
		t.Fatal(err)
	}
	if msg.Content != RefusalSentence {
		t.Fatalf("expected refusal, got %q", msg.Content)
	}
	if len(msg.Citations) != 0 {
		t.Fatal("refusal must carry no citations")
	}
}

// Two consecutive invalid answers degrade to the refusal — never a hallucination.
func TestAskDegradesToRefusalAfterFailedRegeneration(t *testing.T) {
	svc, _, _ := newHarness(t, []string{
		"Hallucinated [chunk 42].",
		"Still hallucinating [chunk 99].",
	}, twoChunks())
	msg, err := svc.Ask(context.Background(), mustSession(t, svc), "?", nil)
	if err != nil {
		t.Fatal(err)
	}
	if msg.Content != RefusalSentence {
		t.Fatalf("must degrade to refusal, got %q", msg.Content)
	}
}

// Metadata-only papers still answer — from the abstract — with no citations.
func TestAskMetadataOnlyAnswersWithoutCitations(t *testing.T) {
	svc, _, llm := newHarness(t, []string{"Based only on the abstract, transformers beat RNNs."},
		nil) // no chunks at all
	msg, err := svc.Ask(context.Background(), mustSession(t, svc), "What did they do?", nil)
	if err != nil {
		t.Fatal(err)
	}
	if len(msg.Citations) != 0 {
		t.Fatalf("metadata-only answer cannot cite chunks: %+v", msg.Citations)
	}
	if strings.Contains(llm.lastPrompt, "[chunk 1]") {
		t.Fatal("no chunks were retrieved; prompt must not contain chunk blocks")
	}
}

// citedChunkIndices unit table.
func TestCitedChunkIndices(t *testing.T) {
	cases := []struct {
		name string
		text string
		n    int
		want []int
	}{
		{"valid single", "x [chunk 1]", 2, []int{1}},
		{"valid multiple sorted", "b [chunk 2] a [chunk 1]", 3, []int{1, 2}},
		{"out of range invalidates", "[chunk 5]", 2, nil},
		{"no citations", "nothing here", 2, nil},
		{"mixed invalid", "[chunk 1] [chunk 7]", 3, nil},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := citedChunkIndices(tc.text, tc.n)
			if len(got) != len(tc.want) {
				t.Fatalf("got %v want %v", got, tc.want)
			}
			for i := range got {
				if got[i] != tc.want[i] {
					t.Fatalf("got %v want %v", got, tc.want)
				}
			}
		})
	}
}

func TestCitationsForExtractsQuotes(t *testing.T) {
	chunks := twoChunks()
	cits := citationsFor([]int{2}, chunks)
	if len(cits) != 1 || cits[0].ChunkID != chunks[1].ID ||
		!strings.Contains(cits[0].Quote, "BLEU") {
		t.Fatalf("bad citations: %+v", cits)
	}
}

// ---- helpers ----------------------------------------------------------------

func mustSession(t *testing.T, svc *Service) uuid.UUID {
	t.Helper()
	s, err := svc.CreateSession(context.Background(),
		domainai.NewSessionInput{PaperID: uuid.New()})
	if err != nil {
		t.Fatal(err)
	}
	return s.ID
}
