// Package stub provides a deterministic, network-free AI provider for
// development and tests. It exercises the full grounding pipeline (context
// assembly, citation validation, persistence) without external calls.
package stub

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"regexp"
	"strings"

	"athena/backend/internal/domain/ai"
)

// Provider implements ai.LLMProvider.
type Provider struct{}

// New builds a stub LLM provider.
func New() *Provider { return &Provider{} }

// Model reports the stub model id.
func (p *Provider) Model() string { return "stub-1" }

var chunkRef = regexp.MustCompile(`(?m)^\[chunk (\d+)\]`)

var _ = chunkRef // referenced below via literal markers only

// Generate returns deterministic structured output. When the prompt embeds
// context chunks the reply cites [chunk N]; JSON requests get valid JSON.
func (p *Provider) Generate(_ context.Context, req ai.GenerateRequest) (ai.GenerateResponse, error) {
	text := stubText(req.Prompt)
	return ai.GenerateResponse{
		Text:  text,
		Model: p.Model(),
		Usage: usageFor(text),
	}, nil
}

// GenerateStream emits the same output in word-sized deltas.
func (p *Provider) GenerateStream(ctx context.Context, req ai.GenerateRequest) (ai.StreamReader, error) {
	return &wordStream{words: strings.Fields(stubText(req.Prompt)), ctx: ctx}, nil
}

// stubText derives its answer from prompt markers:
//
//	CONTEXT CHUNKS section present -> grounded chat-style reply with citations
//	TITLE: line + JSON instruction -> summary JSON
func stubText(prompt string) string {
	hasContext := strings.Contains(prompt, "### CONTEXT")
	if hasContext {
		n := countContextChunks(prompt)
		var b strings.Builder
		b.WriteString("Based on the provided context, here is what the paper says.\n\n")
		for i := 1; i <= n; i++ {
			fmt.Fprintf(&b, "[chunk %d] The context states relevant findings.\n", i)
		}
		b.WriteString("\nIf you need more detail than this, the evidence is insufficient.")
		return b.String()
	}
	if strings.Contains(prompt, "TITLE:") {
		title := extractLine(prompt, "TITLE:")
		abstract := extractLine(prompt, "ABSTRACT:")
		payload := map[string]any{
			"tldr":                  "Stub TL;DR for " + title,
			"simple_explanation":    "Stub simple explanation.",
			"academic_explanation":  "Stub academic explanation of " + title,
			"key_findings":          []string{"Stub finding one.", "Stub finding two."},
			"methodology":           "Stub methodology description.",
			"results":               "Stub results statement.",
			"limitations":           []string{"Stub limitation."},
			"why_it_matters":        "Stub significance statement.",
			"_echo_abstract_length": len(abstract),
		}
		out, _ := json.Marshal(payload)
		return string(out)
	}
	return "This is a stub response."
}

func countContextChunks(prompt string) int {
	max := 0
	for _, m := range regexp.MustCompile(`\[chunk (\d+)\]`).FindAllStringSubmatch(prompt, -1) {
		if len(m) == 2 && m[1] != "" {
			n := 0
			for _, r := range m[1] {
				n = n*10 + int(r-'0')
			}
			if n > max {
				max = n
			}
		}
	}
	return max
}

func extractLine(s, prefix string) string {
	idx := strings.Index(s, prefix)
	if idx < 0 {
		return ""
	}
	rest := s[idx+len(prefix):]
	if nl := strings.IndexByte(rest, '\n'); nl >= 0 {
		rest = rest[:nl]
	}
	return strings.TrimSpace(rest)
}

func usageFor(text string) ai.TokenUsage {
	sum := sha256.Sum256([]byte(text))
	n := int(hex.EncodeToString(sum[:2])[0])%64 + 8 // stable pseudo-count 8..71
	return ai.TokenUsage{PromptTokens: n * 3, CompletionTokens: n, TotalTokens: n * 4}
}

// ---- streaming -------------------------------------------------------------

type wordStream struct {
	words []string
	i     int
	ctx   context.Context
}

func (w *wordStream) Next(_ context.Context) (string, error) {
	select {
	case <-w.ctx.Done():
		return "", w.ctx.Err()
	default:
	}
	if w.i >= len(w.words) {
		return "", io.EOF
	}
	tok := w.words[w.i] + " "
	w.i++
	return tok, nil
}

func (w *wordStream) Close() error { return nil }

// ---- embeddings -------------------------------------------------------------

// Embedder is a deterministic hashing embedder for dev/tests. Vectors are
// normalized so cosine similarity behaves like the real thing.
type Embedder struct {
	Dim int
}

// NewEmbedder builds a stub embedding provider with the given dimension.
func NewEmbedder(dim int) *Embedder {
	if dim <= 0 {
		dim = 1536
	}
	return &Embedder{Dim: dim}
}

// Model reports the stub embedding model id.
func (e *Embedder) Model() string { return fmt.Sprintf("stub-embed-%d", e.Dim) }

// Embed produces stable unit vectors from token hashes.
func (e *Embedder) Embed(_ context.Context, texts []string) ([][]float32, error) {
	out := make([][]float32, len(texts))
	for i, t := range texts {
		v := make([]float32, e.Dim)
		words := strings.Fields(strings.ToLower(t))
		if len(words) == 0 {
			words = []string{"empty"}
		}
		for wi, w := range words {
			sum := sha256.Sum256([]byte(w))
			slot := (int(sum[0])<<8 | int(sum[1])) % e.Dim
			sign := float32(1)
			if sum[2]&1 == 1 {
				sign = -1
			}
			decay := 1.0 / float32(wi+1)
			v[slot] += sign * decay
		}
		var norm float64
		for _, c := range v {
			norm += float64(c) * float64(c)
		}
		if norm == 0 {
			v[0] = 1
		} else {
			inv := float32(1 / normSqrt(norm))
			for j := range v {
				v[j] *= inv
			}
		}
		out[i] = v
	}
	return out, nil
}

func normSqrt(x float64) float64 {
	// small Newton iterations to avoid importing math in a hot path
	if x == 0 {
		return 0
	}
	z := x
	for i := 0; i < 24; i++ {
		z = z - (z*z-x)/(2*z)
	}
	return z
}
