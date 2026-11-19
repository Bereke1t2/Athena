// Package ollama adapts local offline Ollama endpoints (http://localhost:11434)
// to the domain LLMProvider and EmbeddingProvider ports for air-gapped and
// privacy-sensitive deployments (ADR-0004).
package ollama

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"athena/backend/internal/domain/ai"
)

const (
	defaultBaseURL      = "http://localhost:11434"
	defaultChatModel    = "llama3.2"
	defaultEmbedModel   = "nomic-embed-text"
	defaultEmbedDim     = 768
	defaultTimeout      = 120 * time.Second
)

// Config configures the Ollama client.
type Config struct {
	BaseURL    string
	Model      string
	Dimensions int
	Timeout    time.Duration
}

// Client implements ai.LLMProvider against a local or remote Ollama server.
type Client struct {
	cfg   Config
	http  *http.Client
	model string
}

// NewClient initializes a new Ollama LLM provider.
func NewClient(cfg Config) *Client {
	if cfg.Timeout <= 0 {
		cfg.Timeout = defaultTimeout
	}
	if cfg.BaseURL == "" {
		cfg.BaseURL = defaultBaseURL
	}
	if cfg.Model == "" {
		cfg.Model = defaultChatModel
	}
	return &Client{
		cfg: cfg,
		http: &http.Client{
			Timeout: cfg.Timeout,
			Transport: &http.Transport{
				MaxIdleConnsPerHost: 8,
			},
		},
		model: cfg.Model,
	}
}

// Model returns the configured Ollama model name.
func (c *Client) Model() string {
	return c.model
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatOptions struct {
	Temperature float64 `json:"temperature,omitempty"`
	NumPredict  int     `json:"num_predict,omitempty"`
}

type chatRequest struct {
	Model    string        `json:"model"`
	Messages []chatMessage `json:"messages"`
	Stream   bool          `json:"stream"`
	Options  *chatOptions  `json:"options,omitempty"`
}

type chatResponse struct {
	Model           string      `json:"model"`
	CreatedAt       string      `json:"created_at"`
	Message         chatMessage `json:"message"`
	Done            bool        `json:"done"`
	TotalDuration   int64       `json:"total_duration"`
	PromptEvalCount int         `json:"prompt_eval_count"`
	EvalCount       int         `json:"eval_count"`
	Error           string      `json:"error,omitempty"`
}

// HTTPError carries non-200 responses from Ollama.
type HTTPError struct {
	Status int
	Body   string
}

func (e *HTTPError) Error() string {
	return fmt.Sprintf("ollama provider returned %d: %s", e.Status, e.Body)
}

func (c *Client) buildMessages(req ai.GenerateRequest) []chatMessage {
	msgs := make([]chatMessage, 0, 2)
	if req.System != "" {
		msgs = append(msgs, chatMessage{Role: "system", Content: req.System})
	}
	msgs = append(msgs, chatMessage{Role: "user", Content: req.Prompt})
	return msgs
}

// Generate performs a synchronous completion call against Ollama.
func (c *Client) Generate(ctx context.Context, req ai.GenerateRequest) (ai.GenerateResponse, error) {
	opts := &chatOptions{
		Temperature: req.Temperature,
	}
	if req.MaxTokens > 0 {
		opts.NumPredict = req.MaxTokens
	}

	body := chatRequest{
		Model:    c.model,
		Messages: c.buildMessages(req),
		Stream:   false,
		Options:  opts,
	}

	payload, err := json.Marshal(body)
	if err != nil {
		return ai.GenerateResponse{}, fmt.Errorf("encode ollama request: %w", err)
	}

	endpoint := strings.TrimRight(c.cfg.BaseURL, "/") + "/api/chat"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
	if err != nil {
		return ai.GenerateResponse{}, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Accept", "application/json")

	resp, err := c.http.Do(httpReq)
	if err != nil {
		return ai.GenerateResponse{}, fmt.Errorf("ollama call failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		snippet, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return ai.GenerateResponse{}, &HTTPError{Status: resp.StatusCode, Body: string(snippet)}
	}

	var out chatResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return ai.GenerateResponse{}, fmt.Errorf("decode ollama response: %w", err)
	}

	if out.Error != "" {
		return ai.GenerateResponse{}, fmt.Errorf("ollama error: %s", out.Error)
	}

	return ai.GenerateResponse{
		Text:  out.Message.Content,
		Model: firstNonEmpty(out.Model, c.model),
		Usage: ai.TokenUsage{
			PromptTokens:     out.PromptEvalCount,
			CompletionTokens: out.EvalCount,
			TotalTokens:      out.PromptEvalCount + out.EvalCount,
		},
	}, nil
}

// GenerateStream initiates an NDJSON streaming completion from Ollama.
func (c *Client) GenerateStream(ctx context.Context, req ai.GenerateRequest) (ai.StreamReader, error) {
	opts := &chatOptions{
		Temperature: req.Temperature,
	}
	if req.MaxTokens > 0 {
		opts.NumPredict = req.MaxTokens
	}

	body := chatRequest{
		Model:    c.model,
		Messages: c.buildMessages(req),
		Stream:   true,
		Options:  opts,
	}

	payload, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("encode ollama stream request: %w", err)
	}

	endpoint := strings.TrimRight(c.cfg.BaseURL, "/") + "/api/chat"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("ollama stream call failed: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		snippet, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		resp.Body.Close()
		return nil, &HTTPError{Status: resp.StatusCode, Body: string(snippet)}
	}

	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 64*1024), 2*1024*1024)

	return &streamReader{
		scanner: scanner,
		body:    resp.Body,
		model:   c.model,
	}, nil
}

type streamReader struct {
	scanner *bufio.Scanner
	body    io.Closer
	model   string
	usage   ai.TokenUsage
	done    bool
}

// Next returns the next text delta in the NDJSON stream or io.EOF when finished.
func (r *streamReader) Next(ctx context.Context) (string, error) {
	if r.done {
		return "", io.EOF
	}

	for r.scanner.Scan() {
		select {
		case <-ctx.Done():
			r.done = true
			return "", ctx.Err()
		default:
		}

		line := strings.TrimSpace(r.scanner.Text())
		if line == "" {
			continue
		}

		var chunk chatResponse
		if err := json.Unmarshal([]byte(line), &chunk); err != nil {
			continue
		}

		if chunk.Error != "" {
			r.done = true
			return "", fmt.Errorf("ollama stream error: %s", chunk.Error)
		}

		if chunk.PromptEvalCount > 0 {
			r.usage.PromptTokens = chunk.PromptEvalCount
		}
		if chunk.EvalCount > 0 {
			r.usage.CompletionTokens = chunk.EvalCount
			r.usage.TotalTokens = r.usage.PromptTokens + r.usage.CompletionTokens
		}

		content := chunk.Message.Content
		if chunk.Done {
			r.done = true
			if content != "" {
				return content, nil
			}
			return "", io.EOF
		}

		if content != "" {
			return content, nil
		}
	}

	err := r.scanner.Err()
	r.done = true
	if err == nil {
		return "", io.EOF
	}
	return "", fmt.Errorf("ollama stream read: %w", err)
}

func (r *streamReader) Close() error {
	return r.body.Close()
}

// ---- embeddings -------------------------------------------------------------

type embedRequest struct {
	Model string   `json:"model"`
	Input []string `json:"input"`
}

type embedResponse struct {
	Model      string      `json:"model"`
	Embeddings [][]float32 `json:"embeddings"`
	Error      string      `json:"error,omitempty"`
}

type legacyEmbedRequest struct {
	Model  string `json:"model"`
	Prompt string `json:"prompt"`
}

type legacyEmbedResponse struct {
	Embedding []float32 `json:"embedding"`
	Error     string    `json:"error,omitempty"`
}

// Embedder implements ai.EmbeddingProvider using Ollama.
type Embedder struct {
	cfg   Config
	http  *http.Client
	model string
}

// NewEmbedder initializes a new Ollama embedding provider.
func NewEmbedder(cfg Config) *Embedder {
	if cfg.Timeout <= 0 {
		cfg.Timeout = defaultTimeout
	}
	if cfg.BaseURL == "" {
		cfg.BaseURL = defaultBaseURL
	}
	if cfg.Model == "" {
		cfg.Model = defaultEmbedModel
	}
	if cfg.Dimensions <= 0 {
		cfg.Dimensions = defaultEmbedDim
	}
	return &Embedder{
		cfg: cfg,
		http: &http.Client{
			Timeout: cfg.Timeout,
		},
		model: cfg.Model,
	}
}

// Model returns the embedding model id.
func (e *Embedder) Model() string {
	return e.model
}

// Embed converts text passages to float32 vectors.
// It first attempts the batch /api/embed endpoint, falling back to /api/embeddings if unavailable.
func (e *Embedder) Embed(ctx context.Context, texts []string) ([][]float32, error) {
	if len(texts) == 0 {
		return nil, nil
	}

	vectors, err := e.batchEmbed(ctx, texts)
	if err == nil {
		return vectors, nil
	}

	var he *HTTPError
	if errors.As(err, &he) && he.Status == http.StatusNotFound {
		return e.legacyEmbed(ctx, texts)
	}

	return nil, err
}

func (e *Embedder) batchEmbed(ctx context.Context, texts []string) ([][]float32, error) {
	body := embedRequest{
		Model: e.model,
		Input: texts,
	}
	payload, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	endpoint := strings.TrimRight(e.cfg.BaseURL, "/") + "/api/embed"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := e.http.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("ollama embed call failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		snippet, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return nil, &HTTPError{Status: resp.StatusCode, Body: string(snippet)}
	}

	var out embedResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, fmt.Errorf("decode ollama embed response: %w", err)
	}

	if out.Error != "" {
		return nil, fmt.Errorf("ollama embed error: %s", out.Error)
	}

	if len(out.Embeddings) != len(texts) {
		return nil, fmt.Errorf("ollama embed returned %d embeddings for %d inputs", len(out.Embeddings), len(texts))
	}

	return out.Embeddings, nil
}

func (e *Embedder) legacyEmbed(ctx context.Context, texts []string) ([][]float32, error) {
	endpoint := strings.TrimRight(e.cfg.BaseURL, "/") + "/api/embeddings"
	vectors := make([][]float32, len(texts))

	for i, text := range texts {
		body := legacyEmbedRequest{
			Model:  e.model,
			Prompt: text,
		}
		payload, err := json.Marshal(body)
		if err != nil {
			return nil, err
		}

		httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
		if err != nil {
			return nil, err
		}
		httpReq.Header.Set("Content-Type", "application/json")

		resp, err := e.http.Do(httpReq)
		if err != nil {
			return nil, fmt.Errorf("ollama legacy embed call failed: %w", err)
		}

		if resp.StatusCode != http.StatusOK {
			snippet, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
			resp.Body.Close()
			return nil, &HTTPError{Status: resp.StatusCode, Body: string(snippet)}
		}

		var out legacyEmbedResponse
		if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
			resp.Body.Close()
			return nil, fmt.Errorf("decode ollama legacy embed response: %w", err)
		}
		resp.Body.Close()

		if out.Error != "" {
			return nil, fmt.Errorf("ollama legacy embed error: %s", out.Error)
		}

		vectors[i] = out.Embedding
	}

	return vectors, nil
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}
