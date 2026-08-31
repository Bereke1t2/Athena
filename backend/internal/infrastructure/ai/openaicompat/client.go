// Package openaicompat adapts any OpenAI-compatible chat/embeddings API
// (OpenAI, Azure-compatible gateways, vLLM, Ollama, Groq) to the domain
// LLMProvider/EmbeddingProvider ports (ADR-0004).
package openaicompat

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"athena/backend/internal/domain/ai"
)

// Config configures one adapter instance.
type Config struct {
	BaseURL string // e.g. https://api.openai.com/v1
	APIKey  string
	Model   string
	Timeout time.Duration
}

type message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatRequest struct {
	Model       string    `json:"model"`
	Messages    []message `json:"messages"`
	MaxTokens   int       `json:"max_tokens,omitempty"`
	Temperature float64   `json:"temperature"`
	Stream      bool      `json:"stream"`
}

type usageDTO struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
	TotalTokens      int `json:"total_tokens"`
}

type chatChoice struct {
	Message struct {
		Content string `json:"content"`
	} `json:"message"`
	Delta struct {
		Content string `json:"content"`
	} `json:"delta"`
}

type chatResponse struct {
	Model   string       `json:"model"`
	Choices []chatChoice `json:"choices"`
	Usage   usageDTO     `json:"usage"`
	Error   *struct {
		Message string `json:"message"`
		Type    string `json:"type"`
	} `json:"error,omitempty"`
}

// Client implements ai.LLMProvider.
type Client struct {
	cfg    Config
	http   *http.Client
	model  string
}

// NewClient builds an adapter; timeout defaults to 60s.
func NewClient(cfg Config) *Client {
	if cfg.Timeout <= 0 {
		cfg.Timeout = time.Minute
	}
	if cfg.Model == "" {
		cfg.Model = "gpt-4o-mini"
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

// Model reports the configured model id.
func (c *Client) Model() string { return c.model }

const maxRetries = 3

func (c *Client) do(ctx context.Context, body chatRequest) (*http.Response, error) {
	payload, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("encode request: %w", err)
	}

	var lastErr error
	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			delay := retryDelay(attempt, lastErr)
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(delay):
			}
		}

		req, err := http.NewRequestWithContext(ctx, http.MethodPost,
			strings.TrimRight(c.cfg.BaseURL, "/")+"/chat/completions", bytes.NewReader(payload))
		if err != nil {
			return nil, err
		}
		req.Header.Set("Content-Type", "application/json")
		if !body.Stream {
			req.Header.Set("Accept", "application/json")
		}
		if c.cfg.APIKey != "" {
			req.Header.Set("Authorization", "Bearer "+c.cfg.APIKey)
		}
		resp, err := c.http.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("llm call failed: %w", err)
			// A client/context timeout won't heal on retry — retrying just
			// multiplies the wait (previously up to ~4×60s before the handler
			// gave up). Fail fast; only genuinely transient errors retry.
			if ctx.Err() != nil || isTimeout(err) {
				return nil, lastErr
			}
			continue
		}
		if resp.StatusCode == http.StatusTooManyRequests {
			snippet, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
			resp.Body.Close()
			lastErr = &HTTPError{Status: resp.StatusCode, Body: string(snippet)}
			continue
		}
		if resp.StatusCode != http.StatusOK {
			snippet, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
			resp.Body.Close()
			return nil, &HTTPError{Status: resp.StatusCode, Body: string(snippet)}
		}
		return resp, nil
	}
	var he *HTTPError
	if errors.As(lastErr, &he) && he.Status == http.StatusTooManyRequests {
		delay := retryDelay(maxRetries, lastErr)
		return nil, fmt.Errorf("%w: %s (retry-after: %v)", ai.ErrRateLimited, he.Body, delay)
	}
	return nil, lastErr
}

// isTimeout reports whether err is a client-side or context deadline timeout,
// which retrying cannot fix.
func isTimeout(err error) bool {
	if errors.Is(err, context.DeadlineExceeded) {
		return true
	}
	var ne net.Error
	return errors.As(err, &ne) && ne.Timeout()
}

// retryDelay parses the Retry-After or Retry-Info header hint, falling back
// to exponential backoff: 2^attempt seconds.
func retryDelay(attempt int, err error) time.Duration {
	if he := (*HTTPError)(nil); errors.As(err, &he) {
		if delay := parseRetryAfter(he.Body); delay > 0 {
			return delay
		}
	}
	return time.Duration(math.Pow(2, float64(attempt))) * time.Second
}

func parseRetryAfter(body string) time.Duration {
	var obj struct {
		Error struct {
			Details []struct {
				RetryDelay string `json:"retryDelay"`
			} `json:"details"`
		} `json:"error"`
	}
	if err := json.Unmarshal([]byte(body), &obj); err == nil {
		for _, d := range obj.Error.Details {
			if d.RetryDelay != "" {
				if dur, err := time.ParseDuration(d.RetryDelay); err == nil {
					return dur
				}
				if secs, err := strconv.Atoi(strings.TrimSuffix(d.RetryDelay, "s")); err == nil {
					return time.Duration(secs) * time.Second
				}
			}
		}
	}
	return 0
}

// HTTPError carries non-200 upstream responses.
type HTTPError struct {
	Status int
	Body   string
}

func (e *HTTPError) Error() string {
	return fmt.Sprintf("llm provider returned %d: %s", e.Status, e.Body)
}

// Generate performs one completion.
func (c *Client) Generate(ctx context.Context, req ai.GenerateRequest) (ai.GenerateResponse, error) {
	resp, err := c.do(ctx, chatRequest{
		Model:       c.model,
		Messages:    messages(req),
		MaxTokens:   req.MaxTokens,
		Temperature: req.Temperature,
	})
	if err != nil {
		return ai.GenerateResponse{}, err
	}
	defer resp.Body.Close()
	var out chatResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return ai.GenerateResponse{}, fmt.Errorf("decode llm response: %w", err)
	}
	if out.Error != nil {
		return ai.GenerateResponse{}, fmt.Errorf("llm error: %s", out.Error.Message)
	}
	if len(out.Choices) == 0 {
		return ai.GenerateResponse{}, fmt.Errorf("llm response had no choices")
	}
	return ai.GenerateResponse{
		Text:  out.Choices[0].Message.Content,
		Model: firstNonEmpty(out.Model, c.model),
		Usage: TokenUsage(out.Usage),
	}, nil
}

func (c *Client) GenerateStream(ctx context.Context, req ai.GenerateRequest) (ai.StreamReader, error) {
	resp, err := c.do(ctx, chatRequest{
		Model:       c.model,
		Messages:    messages(req),
		MaxTokens:   req.MaxTokens,
		Temperature: req.Temperature,
		Stream:      true,
	})
	if err != nil {
		return nil, err
	}
	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 64*1024), 2*1024*1024)
	return &streamReader{scanner: scanner, body: resp.Body, model: c.model}, nil
}

func messages(req ai.GenerateRequest) []message {
	msgs := make([]message, 0, 2)
	if req.System != "" {
		msgs = append(msgs, message{Role: "system", Content: req.System})
	}
	msgs = append(msgs, message{Role: "user", Content: req.Prompt})
	return msgs
}

func TokenUsage(u usageDTO) ai.TokenUsage {
	return ai.TokenUsage{
		PromptTokens:     u.PromptTokens,
		CompletionTokens: u.CompletionTokens,
		TotalTokens:      u.TotalTokens,
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

// streamReader parses SSE frames of an OpenAI-style stream.
type streamReader struct {
	scanner *bufio.Scanner
	body    io.Closer
	model   string
	usage   ai.TokenUsage
	done    bool
}

// Next returns the next text delta or io.EOF.
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
		if !strings.HasPrefix(line, "data:") {
			continue
		}
		data := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
		if data == "[DONE]" {
			r.done = true
			return "", io.EOF
		}
		var frame chatResponse
		if err := json.Unmarshal([]byte(data), &frame); err != nil {
			continue // tolerate keep-alive comments / malformed frames
		}
		if frame.Usage.TotalTokens > 0 {
			r.usage = TokenUsage(frame.Usage)
		}
		var delta string
		for _, ch := range frame.Choices {
			delta += ch.Delta.Content
			if ch.Message.Content != "" && delta == "" {
				delta = ch.Message.Content
			}
		}
		if delta != "" {
			return delta, nil
		}
	}
	err := r.scanner.Err()
	r.done = true
	if err == nil {
		return "", io.EOF
	}
	return "", fmt.Errorf("stream read: %w", err)
}

func (r *streamReader) Close() error { return r.body.Close() }

// ---- embeddings -------------------------------------------------------------

type embeddingsRequest struct {
	Model string   `json:"model"`
	Input []string `json:"input"`
}

type embeddingsResponse struct {
	Data []struct {
		Index     int       `json:"index"`
		Embedding []float32 `json:"embedding"`
	} `json:"data"`
	Usage usageDTO `json:"usage"`
}

// Embedder implements ai.EmbeddingProvider against the same base URL.
type Embedder struct {
	cfg   Config
	http  *http.Client
	model string
}

// NewEmbedder builds an embeddings adapter.
func NewEmbedder(cfg Config) *Embedder {
	if cfg.Timeout <= 0 {
		cfg.Timeout = time.Minute
	}
	if cfg.Model == "" {
		cfg.Model = "text-embedding-3-small"
	}
	return &Embedder{
		cfg:   cfg,
		http:  &http.Client{Timeout: cfg.Timeout},
		model: cfg.Model,
	}
}

// Model reports the embedding model id.
func (e *Embedder) Model() string { return e.model }

// Embed maps texts to vectors, preserving input order.
func (e *Embedder) Embed(ctx context.Context, texts []string) ([][]float32, error) {
	if len(texts) == 0 {
		return nil, nil
	}
	payload, err := json.Marshal(embeddingsRequest{Model: e.model, Input: texts})
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		strings.TrimRight(e.cfg.BaseURL, "/")+"/embeddings", bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if e.cfg.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+e.cfg.APIKey)
	}
	resp, err := e.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("embedding call failed: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		snippet, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return nil, &HTTPError{Status: resp.StatusCode, Body: string(snippet)}
	}
	var out embeddingsResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, fmt.Errorf("decode embedding response: %w", err)
	}
	vectors := make([][]float32, len(texts))
	for _, d := range out.Data {
		if d.Index >= 0 && d.Index < len(vectors) {
			vectors[d.Index] = d.Embedding
		}
	}
	for i, v := range vectors {
		if v == nil {
			return nil, fmt.Errorf("embedding provider omitted vector at index %d", i)
		}
	}
	return vectors, nil
}
