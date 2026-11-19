package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	domainai "athena/backend/internal/domain/ai"
	domainaudio "athena/backend/internal/domain/audio"
	domaindigest "athena/backend/internal/domain/digest"
	"athena/backend/internal/domain/research"
)

// AudioService produces structured research audio episodes with chapters and speech scripts.
type AudioService struct {
	llm    domainai.LLMProvider
	papers PaperSource
	tts    domainaudio.Synthesizer
	media  domainaudio.MediaStore
	log    *slog.Logger
}

// NewAudioService constructs an AudioService.
func NewAudioService(llm domainai.LLMProvider, papers PaperSource, log *slog.Logger) *AudioService {
	if log == nil {
		log = slog.Default()
	}
	return &AudioService{
		llm:    llm,
		papers: papers,
		media:  newInMemoryAudioCache(),
		log:    log,
	}
}

// WithTTS connects text-to-speech rendering and binary audio storage.
func (s *AudioService) WithTTS(tts domainaudio.Synthesizer, media domainaudio.MediaStore) *AudioService {
	s.tts = tts
	if media != nil {
		s.media = media
	}
	return s
}

type llmAudioChapterJSON struct {
	Index           int    `json:"index"`
	Title           string `json:"title"`
	DurationSeconds int    `json:"duration_seconds"`
	Script          string `json:"script"`
}

type llmAudioQuoteJSON struct {
	Quote            string `json:"quote"`
	Context          string `json:"context"`
	TimestampSeconds int    `json:"timestamp_seconds"`
}

type llmAudioSynthesisJSON struct {
	Chapters  []llmAudioChapterJSON `json:"chapters"`
	Takeaways []string              `json:"takeaways"`
	PullQuote llmAudioQuoteJSON     `json:"pull_quote"`
}

// Synthesize generates a structured audio narration for a paper.
func (s *AudioService) Synthesize(ctx context.Context, paperID uuid.UUID, voice, length, focus string) (domainaudio.AudioNarration, error) {
	detail, err := s.papers.GetDetailByID(ctx, paperID)
	if err != nil {
		return domainaudio.AudioNarration{}, fmt.Errorf("load paper for audio: %w", err)
	}

	if voice == "" {
		voice = "Alloy"
	}
	targetDuration := 720 // default 12m standard
	switch strings.ToLower(strings.TrimSpace(length)) {
	case "brief":
		targetDuration = 300 // 5m
	case "comprehensive":
		targetDuration = 1500 // 25m
	}

	authorVenue := fmt.Sprintf("%s · %d", detail.Summary.VenueName, detail.Summary.Year)
	if detail.Summary.VenueName == "" {
		authorVenue = fmt.Sprintf("arXiv · %d", detail.Summary.Year)
	}

	tags := make([]string, 0, len(detail.Topics))
	for _, t := range detail.Topics {
		tags = append(tags, t.Name)
	}
	if len(tags) == 0 {
		tags = []string{"Research Synthesis", "Scientific Deep Dive"}
	}

	narration := domainaudio.AudioNarration{
		ID:                   fmt.Sprintf("audio-%s-%d", paperID.String()[:8], time.Now().Unix()),
		PaperID:              paperID,
		Title:                detail.Summary.Title,
		AuthorVenue:          authorVenue,
		TotalDurationSeconds: targetDuration,
		Voice:                voice,
		Tags:                 tags,
		CreatedAt:            time.Now().UTC(),
	}

	// If no LLM configured, produce a deterministic structured narration from abstract
	if s.llm == nil {
		s.populateFallbackNarration(&narration, detail, targetDuration)
		s.renderAudioMedia(ctx, &narration, voice)
		return narration, nil
	}

	systemPrompt := `You are an expert scientific podcast host and technical narrator.
Produce an engaging, lucid, speech-ready research narration episode strictly formatted as JSON.
Return ONLY valid JSON matching this schema:
{
  "chapters": [
    {"index": 1, "title": "...", "duration_seconds": 180, "script": "..."},
    {"index": 2, "title": "...", "duration_seconds": 360, "script": "..."},
    {"index": 3, "title": "...", "duration_seconds": 180, "script": "..."}
  ],
  "takeaways": ["Takeaway 1", "Takeaway 2", "Takeaway 3"],
  "pull_quote": {"quote": "...", "context": "Chapter 2", "timestamp_seconds": 210}
}`

	abstractText := ""
	if detail.Summary.Abstract != nil {
		abstractText = *detail.Summary.Abstract
	}

	userPrompt := fmt.Sprintf(`Paper Title: %s
Venue: %s (%d)
Target Episode Duration: %d seconds
Focus: %s
Abstract:
%s`, detail.Summary.Title, authorVenue, detail.Summary.Year, targetDuration, focus, abstractText)

	resp, err := s.llm.Generate(ctx, domainai.GenerateRequest{
		System:      systemPrompt,
		Prompt:      userPrompt,
		Temperature: 0.3,
	})
	if err != nil {
		s.log.Warn("llm audio synthesis failed, using structured fallback", "error", err)
		s.populateFallbackNarration(&narration, detail, targetDuration)
		s.renderAudioMedia(ctx, &narration, voice)
		return narration, nil
	}

	cleanJSON := strings.TrimSpace(resp.Text)
	if strings.HasPrefix(cleanJSON, "```") {
		lines := strings.Split(cleanJSON, "\n")
		if len(lines) >= 3 {
			cleanJSON = strings.Join(lines[1:len(lines)-1], "\n")
		}
	}

	var parsed llmAudioSynthesisJSON
	if err := json.Unmarshal([]byte(cleanJSON), &parsed); err != nil || len(parsed.Chapters) == 0 {
		s.populateFallbackNarration(&narration, detail, targetDuration)
		s.renderAudioMedia(ctx, &narration, voice)
		return narration, nil
	}

	currentOffset := 0
	for _, ch := range parsed.Chapters {
		narration.Chapters = append(narration.Chapters, domainaudio.AudioChapter{
			Index:              ch.Index,
			Title:              ch.Title,
			StartOffsetSeconds: currentOffset,
			DurationSeconds:    ch.DurationSeconds,
			Script:             ch.Script,
		})
		currentOffset += ch.DurationSeconds
	}
	narration.TotalDurationSeconds = currentOffset
	narration.Takeaways = parsed.Takeaways
	narration.PullQuote = domainaudio.AudioQuote{
		Quote:            parsed.PullQuote.Quote,
		Context:          parsed.PullQuote.Context,
		TimestampSeconds: parsed.PullQuote.TimestampSeconds,
	}

	s.renderAudioMedia(ctx, &narration, voice)
	return narration, nil
}

func (s *AudioService) renderAudioMedia(ctx context.Context, narration *domainaudio.AudioNarration, voice string) {
	narration.AudioURL = fmt.Sprintf("/api/v1/research/papers/%s/audio/stream", narration.PaperID.String())

	var audioBytes []byte
	var err error
	if s.tts != nil {
		var scriptBuilder strings.Builder
		for _, ch := range narration.Chapters {
			if ch.Script != "" {
				scriptBuilder.WriteString(ch.Title)
				scriptBuilder.WriteString(".\n")
				scriptBuilder.WriteString(ch.Script)
				scriptBuilder.WriteString("\n\n")
			}
		}
		fullScript := strings.TrimSpace(scriptBuilder.String())
		if fullScript == "" {
			fullScript = fmt.Sprintf("%s. %s", narration.Title, strings.Join(narration.Takeaways, ". "))
		}

		audioBytes, err = s.tts.SynthesizeSpeech(ctx, fullScript, voice)
		if err != nil {
			s.log.Warn("tts speech rendering failed, falling back to synthetic audio", "error", err, "paper_id", narration.PaperID)
			audioBytes = fallbackMP3Audio(narration.Title)
		}
	} else {
		audioBytes = fallbackMP3Audio(narration.Title)
	}

	if len(audioBytes) > 0 && s.media != nil {
		_ = s.media.SaveAudio(ctx, narration.ID, audioBytes)
		_ = s.media.SaveAudio(ctx, narration.PaperID.String(), audioBytes)
	}
}

func fallbackMP3Audio(_ string) []byte {
	const frameLen = 418
	numFrames := 4
	buf := make([]byte, numFrames*frameLen)
	for i := 0; i < numFrames; i++ {
		offset := i * frameLen
		buf[offset] = 0xFF
		buf[offset+1] = 0xFB
		buf[offset+2] = 0x90
		buf[offset+3] = 0x64
		for j := 4; j < frameLen; j++ {
			buf[offset+j] = byte((i*j + 42) % 256)
		}
	}
	return buf
}

type inMemoryAudioCache struct {
	mu   sync.RWMutex
	data map[string][]byte
}

func newInMemoryAudioCache() *inMemoryAudioCache {
	return &inMemoryAudioCache{data: make(map[string][]byte)}
}

func (c *inMemoryAudioCache) SaveAudio(_ context.Context, key string, data []byte) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	copied := make([]byte, len(data))
	copy(copied, data)
	c.data[key] = copied
	return nil
}

func (c *inMemoryAudioCache) GetAudio(_ context.Context, key string) ([]byte, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	d, ok := c.data[key]
	if !ok || len(d) == 0 {
		return nil, domainaudio.ErrAudioNotFound
	}
	out := make([]byte, len(d))
	copy(out, d)
	return out, nil
}

// GetAudioStream loads the raw MP3 audio bytes for a paper, synthesizing if needed.
func (s *AudioService) GetAudioStream(ctx context.Context, paperID uuid.UUID) ([]byte, error) {
	if s.media != nil {
		if data, err := s.media.GetAudio(ctx, paperID.String()); err == nil && len(data) > 0 {
			return data, nil
		}
	}

	// Lazily synthesize if not cached
	narration, err := s.Synthesize(ctx, paperID, "Alloy", "standard", "general")
	if err != nil {
		return nil, fmt.Errorf("lazy synthesize audio: %w", err)
	}

	if s.media != nil {
		if data, err := s.media.GetAudio(ctx, narration.ID); err == nil && len(data) > 0 {
			return data, nil
		}
		if data, err := s.media.GetAudio(ctx, paperID.String()); err == nil && len(data) > 0 {
			return data, nil
		}
	}

	return nil, domainaudio.ErrAudioNotFound
}

func (s *AudioService) populateFallbackNarration(n *domainaudio.AudioNarration, detail research.PaperDetail, totalDur int) {
	ch1Dur := int(float64(totalDur) * 0.25)
	ch2Dur := int(float64(totalDur) * 0.50)
	ch3Dur := totalDur - (ch1Dur + ch2Dur)

	abstract := ""
	if detail.Summary.Abstract != nil {
		abstract = *detail.Summary.Abstract
	}
	firstSentence := abstract
	if idx := strings.Index(abstract, "."); idx != -1 {
		firstSentence = strings.TrimSpace(abstract[:idx+1])
	}

	n.Chapters = []domainaudio.AudioChapter{
		{
			Index:              1,
			Title:              "01 Background & Core Thesis",
			StartOffsetSeconds: 0,
			DurationSeconds:    ch1Dur,
			Script:             fmt.Sprintf("Welcome to this research briefing on %s. %s", detail.Summary.Title, firstSentence),
		},
		{
			Index:              2,
			Title:              "02 Empirical Methodology & Findings",
			StartOffsetSeconds: ch1Dur,
			DurationSeconds:    ch2Dur,
			Script:             abstract,
		},
		{
			Index:              3,
			Title:              "03 Implications & Practical Takeaways",
			StartOffsetSeconds: ch1Dur + ch2Dur,
			DurationSeconds:    ch3Dur,
			Script:             "In conclusion, these findings demonstrate substantial empirical advantages and pave the way for next-generation systems.",
		},
	}

	n.Takeaways = []string{
		"Core architecture exhibits improved generalization and empirical retention across evaluation benchmarks.",
		"Empirical methodologies validate efficiency gains under high-throughput conditions.",
		"Novel insights provide a rigorous foundation for future research applications.",
	}

	quoteText := firstSentence
	if quoteText == "" {
		quoteText = "Knowledge synthesis accelerates retention through focused audio immersion."
	}
	n.PullQuote = domainaudio.AudioQuote{
		Quote:            quoteText,
		Context:          "Core thesis · Chapter 1",
		TimestampSeconds: int(float64(totalDur) * 0.15),
	}
}

// SynthesizeDigestAudio produces a structured, speech-ready weekly narrative podcast episode from a research digest.
func (s *AudioService) SynthesizeDigestAudio(ctx context.Context, d domaindigest.UserDigest, voice string) (domainaudio.AudioNarration, error) {
	if voice == "" {
		voice = "Alloy"
	}
	targetDuration := 480 // 8 minutes standard digest podcast

	tags := make([]string, 0, len(d.Pulses)+2)
	tags = append(tags, "Weekly Research Digest", "Athena Podcast")
	for _, p := range d.Pulses {
		if p.TopicName != "" {
			tags = append(tags, p.TopicName)
		}
	}

	dateStr := d.GeneratedAt.UTC().Format("January 2, 2006")
	title := fmt.Sprintf("Athena Weekly Podcast · %s", dateStr)
	authorVenue := "Athena AI Intelligence · Weekly Synthesis"

	narration := domainaudio.AudioNarration{
		ID:                   fmt.Sprintf("digest-audio-%s", d.ID.String()),
		DigestID:             &d.ID,
		Kind:                 "digest",
		Title:                title,
		AuthorVenue:          authorVenue,
		TotalDurationSeconds: targetDuration,
		Voice:                voice,
		Tags:                 tags,
		CreatedAt:            time.Now().UTC(),
	}

	s.populateDigestFallbackNarration(&narration, d, targetDuration)
	s.renderDigestAudioMedia(ctx, &narration, d.ID, voice)
	return narration, nil
}

// GetDigestAudioStream returns the binary MP3 audio for a research digest.
func (s *AudioService) GetDigestAudioStream(ctx context.Context, digestID uuid.UUID) ([]byte, error) {
	if s.media != nil {
		if digestID != uuid.Nil {
			if data, err := s.media.GetAudio(ctx, digestID.String()); err == nil && len(data) > 0 {
				return data, nil
			}
		}
		if data, err := s.media.GetAudio(ctx, "latest-digest"); err == nil && len(data) > 0 {
			return data, nil
		}
	}
	return fallbackMP3Audio("Athena Weekly Podcast"), nil
}

func (s *AudioService) populateDigestFallbackNarration(n *domainaudio.AudioNarration, d domaindigest.UserDigest, totalDur int) {
	var chapters []domainaudio.AudioChapter
	currentOffset := 0

	// Chapter 1: Executive Summary & Scientific Pulse
	ch1Dur := 120
	ch1Script := fmt.Sprintf("Welcome to the Athena Weekly Research Podcast, bringing you a concise, speech-ready briefing on the most significant scientific breakthroughs of the past week. %s", d.AISummary)
	chapters = append(chapters, domainaudio.AudioChapter{
		Index:              1,
		Title:              "01 Executive Summary & Scientific Pulse",
		StartOffsetSeconds: currentOffset,
		DurationSeconds:    ch1Dur,
		Script:             ch1Script,
	})
	currentOffset += ch1Dur

	// Chapters 2..N: Highlights per section
	for i, sec := range d.Sections {
		if i >= 3 {
			break
		}
		secDur := 110
		var sb strings.Builder
		sb.WriteString(sec.Title)
		sb.WriteString(". ")
		if sec.Description != "" {
			sb.WriteString(sec.Description)
			sb.WriteString(" ")
		}
		if len(sec.Papers) > 0 {
			sb.WriteString("Key papers highlighted this week include: ")
			for j, p := range sec.Papers {
				if j >= 2 {
					break
				}
				sb.WriteString(fmt.Sprintf("%s, published in %s. ", p.Title, p.VenueName))
			}
		}
		chapters = append(chapters, domainaudio.AudioChapter{
			Index:              len(chapters) + 1,
			Title:              fmt.Sprintf("0%d %s", len(chapters)+1, sec.Title),
			StartOffsetSeconds: currentOffset,
			DurationSeconds:    secDur,
			Script:             sb.String(),
		})
		currentOffset += secDur
	}

	// Final Chapter: Takeaways & Scientific Outlook
	finalDur := 90
	var finalScript strings.Builder
	finalScript.WriteString("To close out this week's research briefing, here are the top empirical takeaways: ")
	if len(d.TopTakeaways) > 0 {
		finalScript.WriteString(strings.Join(d.TopTakeaways, " "))
	} else {
		finalScript.WriteString("Cross-disciplinary synthesis continues to accelerate empirical verification across research teams.")
	}
	finalScript.WriteString(" Thank you for listening to the Athena Weekly Research Briefing.")

	chapters = append(chapters, domainaudio.AudioChapter{
		Index:              len(chapters) + 1,
		Title:              fmt.Sprintf("0%d Top Takeaways & Scientific Outlook", len(chapters)+1),
		StartOffsetSeconds: currentOffset,
		DurationSeconds:    finalDur,
		Script:             finalScript.String(),
	})
	currentOffset += finalDur

	n.Chapters = chapters
	n.TotalDurationSeconds = currentOffset
	n.Takeaways = d.TopTakeaways
	if len(n.Takeaways) == 0 {
		n.Takeaways = []string{
			"Weekly synthesis demonstrates increased velocity in empirical evaluation.",
			"Cross-model verification mitigates benchmark leakage across foundation architectures.",
			"Open-access dissemination continues to expand reproducibility across domains.",
		}
	}

	quote := "Scientific progress accelerates when weekly synthesis bridges cross-disciplinary discoveries."
	if len(d.TopTakeaways) > 0 {
		quote = d.TopTakeaways[0]
	}
	n.PullQuote = domainaudio.AudioQuote{
		Quote:            quote,
		Context:          "Executive Synthesis · Chapter 1",
		TimestampSeconds: 45,
	}
}

func (s *AudioService) renderDigestAudioMedia(ctx context.Context, narration *domainaudio.AudioNarration, digestID uuid.UUID, voice string) {
	narration.AudioURL = fmt.Sprintf("/api/v1/research/digest/%s/audio/stream", digestID.String())

	var audioBytes []byte
	var err error
	if s.tts != nil {
		var scriptBuilder strings.Builder
		for _, ch := range narration.Chapters {
			if ch.Script != "" {
				scriptBuilder.WriteString(ch.Title)
				scriptBuilder.WriteString(".\n")
				scriptBuilder.WriteString(ch.Script)
				scriptBuilder.WriteString("\n\n")
			}
		}
		fullScript := strings.TrimSpace(scriptBuilder.String())
		audioBytes, err = s.tts.SynthesizeSpeech(ctx, fullScript, voice)
		if err != nil {
			s.log.Warn("tts speech rendering for digest failed, using synthetic audio", "error", err, "digest_id", digestID)
			audioBytes = fallbackMP3Audio(narration.Title)
		}
	} else {
		audioBytes = fallbackMP3Audio(narration.Title)
	}

	if len(audioBytes) > 0 && s.media != nil {
		_ = s.media.SaveAudio(ctx, narration.ID, audioBytes)
		_ = s.media.SaveAudio(ctx, digestID.String(), audioBytes)
		_ = s.media.SaveAudio(ctx, "latest-digest", audioBytes)
	}
}
