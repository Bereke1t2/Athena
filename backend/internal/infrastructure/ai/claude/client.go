// Package claude adapts Anthropic's Messages API (Claude 3.5 Sonnet, Claude 3 Opus,
// Claude 3.5 Haiku) to the domain LLMProvider interface (ADR-0004).
package claude

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

const (
	defaultBaseURL      = "https://api.anthropic.com/v1"
	defaultModel        = "claude-3-5-sonnet-20241022"
	anthropicAPIVersion = "2023-06-01"
	maxRetries          = 3
	defaultMaxTokens    = 2048
)

// Config configures the Anthropic Claude adapter.
type Config struct {
	BaseURL string
	APIKey  string
	Model   string
	Timeout time.Duration
}

// Client implements ai.LLMProvider using Anthropic Messages API.
type Client struct {
	cfg   Config
	http  *http.Client
	model string
}

// NewClient initializes a new Anthropic Claude provider client.
func NewClient(cfg Config) *Client {
	if cfg.Timeout <= 0 {
		cfg.Timeout = 90 * time.Second
	}
	if cfg.BaseURL == "" {
		cfg.BaseURL = defaultBaseURL
	}
	if cfg.Model == "" {
		cfg.Model = defaultModel
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

// Model returns the configured Claude model identifier.
func (c *Client) Model() string {
	return c.model
}

type messagePayload struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type messagesRequest struct {
	Model       string           `json:"model"`
	Messages    []messagePayload `json:"messages"`
	System      string           `json:"system,omitempty"`
	MaxTokens   int              `json:"max_tokens"`
	Temperature float64          `json:"temperature,omitempty"`
	Stream      bool             `json:"stream,omitempty"`
}

type contentBlock struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

type usageDTO struct {
	InputTokens  int `json:"input_tokens"`
	OutputTokens int `json:"output_tokens"`
}

type errorDetail struct {
	Type    string `json:"type"`
	Message string `json:"message"`
}

type messagesResponse struct {
	ID         string         `json:"id"`
	Type       string         `json:"type"`
	Role       string         `json:"role"`
	Content    []contentBlock `json:"content"`
	Model      string         `json:"model"`
	StopReason string         `json:"stop_reason"`
	Usage      usageDTO       `json:"usage"`
	Error      *errorDetail   `json:"error,omitempty"`
}

type sseDeltaPayload struct {
	Type  string `json:"type"`
	Delta struct {
		Type string `json:"type"`
		Text string `json:"text"`
	} `json:"delta"`
	Usage *usageDTO    `json:"usage,omitempty"`
	Error *errorDetail `json:"error,omitempty"`
}

// HTTPError carries non-200 responses from Anthropic.
type HTTPError struct {
	Status int
	Body   string
}

func (e *HTTPError) Error() string {
	return fmt.Sprintf("claude provider returned %d: %s", e.Status, e.Body)
}

func (c *Client) do(ctx context.Context, body messagesRequest) (*http.Response, error) {
	payload, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("encode claude request: %w", err)
	}

	endpoint := strings.TrimRight(c.cfg.BaseURL, "/") + "/messages"

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

		req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
		if err != nil {
			return nil, err
		}

		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Anthropic-Version", anthropicAPIVersion)
		if c.cfg.APIKey != "" {
			req.Header.Set("x-api-key", c.cfg.APIKey)
		}
		if body.Stream {
			req.Header.Set("Accept", "text/event-stream")
		} else {
			req.Header.Set("Accept", "application/json")
		}

		resp, err := c.http.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("claude call failed: %w", err)
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

		if resp.StatusCode >= 500 {
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

// Generate executes a non-streaming completion against Claude.
func (c *Client) Generate(ctx context.Context, req ai.GenerateRequest) (ai.GenerateResponse, error) {
	maxTok := req.MaxTokens
	if maxTok <= 0 {
		maxTok = defaultMaxTokens
	}

	body := messagesRequest{
		Model:       c.model,
		Messages:    []messagePayload{{Role: "user", Content: req.Prompt}},
		System:      req.System,
		MaxTokens:   maxTok,
		Temperature: req.Temperature,
		Stream:      false,
	}

	resp, err := c.do(ctx, body)
	if err != nil {
		return ai.GenerateResponse{}, err
	}
	defer resp.Body.Close()

	var out messagesResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return ai.GenerateResponse{}, fmt.Errorf("decode claude response: %w", err)
	}

	if out.Error != nil {
		return ai.GenerateResponse{}, fmt.Errorf("claude error: %s (%s)", out.Error.Message, out.Error.Type)
	}

	var sb strings.Builder
	for _, blk := range out.Content {
		if blk.Type == "text" {
			sb.WriteString(blk.Text)
		}
	}

	return ai.GenerateResponse{
		Text:  sb.String(),
		Model: firstNonEmpty(out.Model, c.model),
		Usage: ai.TokenUsage{
			PromptTokens:     out.Usage.InputTokens,
			CompletionTokens: out.Usage.OutputTokens,
			TotalTokens:      out.Usage.InputTokens + out.Usage.OutputTokens,
		},
	}, nil
}

// GenerateStream executes a streaming completion yielding text tokens via StreamReader.
func (c *Client) GenerateStream(ctx context.Context, req ai.GenerateRequest) (ai.StreamReader, error) {
	maxTok := req.MaxTokens
	if maxTok <= 0 {
		maxTok = defaultMaxTokens
	}

	body := messagesRequest{
		Model:       c.model,
		Messages:    []messagePayload{{Role: "user", Content: req.Prompt}},
		System:      req.System,
		MaxTokens:   maxTok,
		Temperature: req.Temperature,
		Stream:      true,
	}

	resp, err := c.do(ctx, body)
	if err != nil {
		return nil, err
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

// Next yields the next text delta or io.EOF when stream concludes.
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
		if data == "" || data == "[DONE]" {
			continue
		}

		var payload sseDeltaPayload
		if err := json.Unmarshal([]byte(data), &payload); err != nil {
			continue
		}

		if payload.Error != nil {
			r.done = true
			return "", fmt.Errorf("claude stream error: %s (%s)", payload.Error.Message, payload.Error.Type)
		}

		if payload.Usage != nil {
			r.usage.CompletionTokens = payload.Usage.OutputTokens
			r.usage.TotalTokens = r.usage.PromptTokens + r.usage.CompletionTokens
		}

		if payload.Type == "message_stop" {
			r.done = true
			return "", io.EOF
		}

		if payload.Type == "content_block_delta" && payload.Delta.Type == "text_delta" && payload.Delta.Text != "" {
			return payload.Delta.Text, nil
		}
	}

	err := r.scanner.Err()
	r.done = true
	if err == nil {
		return "", io.EOF
	}
	return "", fmt.Errorf("claude stream read: %w", err)
}

func (r *streamReader) Close() error {
	return r.body.Close()
}

func isTimeout(err error) bool {
	if errors.Is(err, context.DeadlineExceeded) {
		return true
	}
	var ne net.Error
	return errors.As(err, &ne) && ne.Timeout()
}

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

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}
