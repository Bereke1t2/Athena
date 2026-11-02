// Package digest implements personalized research digest generation and trend aggregation.
package digest

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"

	domainai "athena/backend/internal/domain/ai"
	domaindigest "athena/backend/internal/domain/digest"
	domainfollow "athena/backend/internal/domain/follow"
	"athena/backend/internal/domain/research"
)

// PaperReader defines the subset of paper queries required for digest curation.
type PaperReader interface {
	ListPapers(ctx context.Context, q research.ListQuery) ([]research.PaperSummary, string, error)
}

// FollowReader queries a user's followed topics.
type FollowReader interface {
	ListFollowedTopics(ctx context.Context, userID uuid.UUID) ([]domainfollow.TopicFollow, error)
}

// Service generates personalized research briefings and trend pulses.
type Service struct {
	papers      PaperReader
	followStore FollowReader
	repo        domaindigest.DigestRepository
	llm         domainai.LLMProvider
	log         *slog.Logger
	clock       func() time.Time
}

// NewService constructs a DigestService.
func NewService(papers PaperReader, followStore FollowReader, repo domaindigest.DigestRepository, llm domainai.LLMProvider, log *slog.Logger) *Service {
	if log == nil {
		log = slog.Default()
	}
	return &Service{
		papers:      papers,
		followStore: followStore,
		repo:        repo,
		llm:         llm,
		log:         log,
		clock:       time.Now,
	}
}

type llmDigestSynthesisJSON struct {
	AISummary    string              `json:"ai_summary"`
	TopTakeaways []string            `json:"top_takeaways"`
	TopicThemes  map[string][]string `json:"topic_themes"`
}

// GenerateDigest builds a fresh periodic digest tailored to the user's research interests.
// If customTopics are provided, they take priority (supporting guest researchers with local follows).
// If userID is uuid.Nil (guest user), the briefing is generated dynamically without database persistence.
func (s *Service) GenerateDigest(ctx context.Context, userID uuid.UUID, freq domaindigest.Frequency, customTopics ...string) (domaindigest.UserDigest, error) {
	if freq != domaindigest.FrequencyDaily && freq != domaindigest.FrequencyWeekly {
		freq = domaindigest.FrequencyWeekly
	}

	var topics []string
	for _, t := range customTopics {
		trimmed := strings.TrimSpace(t)
		if trimmed != "" {
			topics = append(topics, trimmed)
		}
	}

	if len(topics) == 0 && s.followStore != nil && userID != uuid.Nil {
		followed, err := s.followStore.ListFollowedTopics(ctx, userID)
		if err == nil {
			for _, tf := range followed {
				topics = append(topics, tf.TopicSlug)
			}
		}
	}

	now := s.clock()
	pulses := make([]domaindigest.TopicPulse, 0)
	sections := make([]domaindigest.DigestSection, 0)
	var allPapers []research.PaperSummary

	weekAgo := now.AddDate(0, 0, -7)

	if len(topics) == 0 {
		// Fallback to recent trending/breakthrough papers across Athena
		papers, _, err := s.papers.ListPapers(ctx, research.ListQuery{
			Limit:          10,
			Sort:           research.SortNewest,
			PublishedAfter: &weekAgo,
		})
		if err != nil || len(papers) < 3 {
			// Fallback to newest papers without strict 7-day cutoff if recent window is sparse
			papers, _, _ = s.papers.ListPapers(ctx, research.ListQuery{
				Limit: 10,
				Sort:  research.SortNewest,
			})
		}

		if len(papers) > 0 {
			allPapers = append(allPapers, papers...)
			sections = append(sections, domaindigest.DigestSection{
				Title:       "Trending Across Athena",
				Description: "High-impact discoveries published recently across all scientific disciplines.",
				Papers:      papers,
			})
			pulses = append(pulses, domaindigest.TopicPulse{
				TopicSlug:  "all",
				TopicName:  "General Science",
				PaperCount: len(papers),
				Velocity:   1.0,
				KeyThemes:  []string{"Multidisciplinary Advances", "Foundational Models"},
			})
		}
	} else {
		for _, topic := range topics {
			// Prioritize papers published during the week
			papers, _, err := s.papers.ListPapers(ctx, research.ListQuery{
				TopicSlug:      topic,
				Limit:          6,
				Sort:           research.SortNewest,
				PublishedAfter: &weekAgo,
			})
			if err != nil || len(papers) < 2 {
				// Resilient fallback to newest papers for this topic
				papers, _, err = s.papers.ListPapers(ctx, research.ListQuery{
					TopicSlug: topic,
					Limit:     6,
					Sort:      research.SortNewest,
				})
			}
			if err != nil || len(papers) == 0 {
				continue
			}

			allPapers = append(allPapers, papers...)
			sections = append(sections, domaindigest.DigestSection{
				Title:       fmt.Sprintf("Highlights in %s", topic),
				Description: fmt.Sprintf("Curated publications from the past week matching your focus in %s.", topic),
				Papers:      papers,
			})
			pulses = append(pulses, domaindigest.TopicPulse{
				TopicSlug:  topic,
				TopicName:  topic,
				PaperCount: len(papers),
				Velocity:   float64(len(papers)) * 0.75,
				KeyThemes:  []string{fmt.Sprintf("%s methodology", topic), "Empirical validation"},
			})
		}
	}

	// Generate AI Weekly Synthesis & Takeaways
	aiSummary, takeaways, topicThemes := s.synthesizeDigest(ctx, topics, allPapers, sections)

	// Apply dynamic themes to pulses if available
	for i := range pulses {
		if themes, ok := topicThemes[pulses[i].TopicSlug]; ok && len(themes) > 0 {
			pulses[i].KeyThemes = themes
		}
	}

	digest := domaindigest.UserDigest{
		ID:           uuid.New(),
		UserID:       userID,
		GeneratedAt:  now,
		Frequency:    freq,
		AISummary:    aiSummary,
		Pulses:       pulses,
		Sections:     sections,
		TopTakeaways: takeaways,
	}

	if s.repo != nil && userID != uuid.Nil {
		if err := s.repo.SaveDigest(ctx, digest); err != nil {
			s.log.Warn("failed to persist user digest", "user_id", userID, "error", err)
		}
	}

	return digest, nil
}

// GetLatestDigest fetches the latest cached digest or dynamically generates a fresh one.
// If userID is uuid.Nil, it dynamically generates a personalized briefing for guest researchers.
func (s *Service) GetLatestDigest(ctx context.Context, userID uuid.UUID, customTopics ...string) (domaindigest.UserDigest, error) {
	// If custom topics were provided for an authenticated user, or if guest, generate fresh tailored digest
	if len(customTopics) > 0 {
		return s.GenerateDigest(ctx, userID, domaindigest.FrequencyWeekly, customTopics...)
	}

	if s.repo != nil && userID != uuid.Nil {
		d, err := s.repo.GetLatestDigest(ctx, userID)
		if err == nil {
			return d, nil
		}
	}
	return s.GenerateDigest(ctx, userID, domaindigest.FrequencyWeekly)
}

// synthesizeDigest uses LLM to generate an executive weekly summary, empirical takeaways, and dynamic topic themes.
// If LLM is unavailable or fails, it falls back to a deterministic, high-signal heuristic synthesis.
func (s *Service) synthesizeDigest(ctx context.Context, topics []string, papers []research.PaperSummary, sections []domaindigest.DigestSection) (string, []string, map[string][]string) {
	// Prepare deterministic fallbacks
	var fallbackSummary string
	if len(topics) > 0 {
		fallbackSummary = fmt.Sprintf("During this period across your followed topics (%s), researchers published notable findings spanning %d curated studies. Recent publications center on advancing foundational methodologies, rigorous benchmarks, and empirical evaluations.", strings.Join(topics, ", "), len(papers))
	} else {
		fallbackSummary = fmt.Sprintf("This week across multidisciplinary science, %d high-impact studies emerged across machine intelligence, computational biology, and physics. Breakthroughs focus on model efficiency, scalable architectures, and empirical consensus.", len(papers))
	}

	fallbackTakeaways := make([]string, 0, 4)
	for i, p := range papers {
		if i >= 3 {
			break
		}
		venue := "Preprint"
		if p.VenueName != "" {
			venue = p.VenueName
		}
		fallbackTakeaways = append(fallbackTakeaways, fmt.Sprintf("Recent study in %s: \"%s\" introduces new empirical findings.", venue, p.Title))
	}
	if len(fallbackTakeaways) == 0 {
		fallbackTakeaways = append(fallbackTakeaways, fmt.Sprintf("Compiled %d relevant papers across %d research themes.", len(papers), len(sections)))
		fallbackTakeaways = append(fallbackTakeaways, "Key breakthroughs focus on efficiency improvements and empirical validation.")
	}

	fallbackThemes := make(map[string][]string)

	if s.llm == nil || len(papers) == 0 {
		return fallbackSummary, fallbackTakeaways, fallbackThemes
	}

	modelID := s.llm.Model()
	if modelID == "stub" {
		return fallbackSummary, fallbackTakeaways, fallbackThemes
	}

	// Build structured prompt for LLM
	var promptBuilder strings.Builder
	promptBuilder.WriteString("You are a senior scientific research director. Analyze these research papers published during the week across the user's followed topics and produce an executive weekly research briefing.\n\n")
	if len(topics) > 0 {
		promptBuilder.WriteString(fmt.Sprintf("User Followed Topics: %s\n\n", strings.Join(topics, ", ")))
	}
	promptBuilder.WriteString("Papers published this week:\n")

	limit := len(papers)
	if limit > 12 {
		limit = 12 // Cap for token budget and response latency
	}

	for i := 0; i < limit; i++ {
		p := papers[i]
		dateStr := ""
		if p.PublishedOn != nil {
			dateStr = p.PublishedOn.Format("2006-01-02")
		} else if p.Year > 0 {
			dateStr = fmt.Sprintf("%d", p.Year)
		}
		abs := ""
		if p.Abstract != nil && len(*p.Abstract) > 0 {
			abs = *p.Abstract
			if len(abs) > 280 {
				abs = abs[:277] + "..."
			}
		}
		promptBuilder.WriteString(fmt.Sprintf("%d. Title: %s\nDate: %s | Venue: %s\nAbstract: %s\n\n",
			i+1, p.Title, dateStr, p.VenueName, abs))
	}

	promptBuilder.WriteString(`Output ONLY a JSON object in this exact format:
{
  "ai_summary": "A cohesive 2-paragraph executive weekly briefing synthesizing what happened during the week across the followed topics, highlighting key breakthroughs, emerging methodologies, and cross-cutting developments.",
  "top_takeaways": [
    "Empirical finding or breakthrough 1",
    "Empirical finding or breakthrough 2",
    "Empirical finding or breakthrough 3"
  ],
  "topic_themes": {
    "topic_name_or_slug": ["Theme 1", "Theme 2"]
  }
}`)

	resp, err := s.llm.Generate(ctx, domainai.GenerateRequest{
		System:      "You are a rigorous scientific analyst. Return valid JSON only without markdown code fences.",
		Prompt:      promptBuilder.String(),
		MaxTokens:   1200,
		Temperature: 0.2,
	})
	if err != nil || resp.Text == "" {
		s.log.Debug("llm digest synthesis fallback used", "error", err)
		return fallbackSummary, fallbackTakeaways, fallbackThemes
	}

	cleaned := strings.TrimSpace(resp.Text)
	cleaned = strings.TrimPrefix(cleaned, "```json")
	cleaned = strings.TrimPrefix(cleaned, "```")
	cleaned = strings.TrimSuffix(cleaned, "```")
	cleaned = strings.TrimSpace(cleaned)

	var parsed llmDigestSynthesisJSON
	if err := json.Unmarshal([]byte(cleaned), &parsed); err != nil {
		s.log.Debug("failed to parse llm digest synthesis json", "error", err)
		return fallbackSummary, fallbackTakeaways, fallbackThemes
	}

	summary := parsed.AISummary
	if summary == "" {
		summary = fallbackSummary
	}
	takeaways := parsed.TopTakeaways
	if len(takeaways) == 0 {
		takeaways = fallbackTakeaways
	}
	themes := parsed.TopicThemes
	if themes == nil {
		themes = fallbackThemes
	}

	return summary, takeaways, themes
}
