// Package gemini adapts Google Gemini's native Generative Language REST API
// (Gemini 1.5 Flash, Gemini 1.5 Pro, text-embedding-004) to the domain
// LLMProvider and EmbeddingProvider ports (ADR-0004).
package gemini

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
	defaultBaseURL      = "https://generativelanguage.googleapis.com/v1beta"
	defaultModel        = "gemini-1.5-flash"
	defaultEmbedModel   = "text-embedding-004"
	defaultEmbedDim     = 768
	maxRetries          = 3
	apiKeyHeader        = "x-goog-api-key"
)

// Config configures the Google Gemini adapter.
type Config struct {
	BaseURL    string
	APIKey     string
	Model      string
	Dimensions int
	Timeout    time.Duration
}

// Client implements ai.LLMProvider using the native Gemini REST API.
type Client struct {
	cfg   Config
	http  *http.Client
	model string
}

// NewClient builds a native Gemini LLM provider.
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

// Model returns the configured Gemini model name.
func (c *Client) Model() string {
	return c.model
}

type geminiPart struct {
	Text string `json:"text"`
}

type geminiContent struct {
	Role  string       `json:"role,omitempty"`
	Parts []geminiPart `json:"parts"`
}

type generationConfig struct {
	Temperature     float64 `json:"temperature,omitempty"`
	MaxOutputTokens int     `json:"maxOutputTokens,omitempty"`
}

type generateRequest struct {
	Contents          []geminiContent   `json:"contents"`
	SystemInstruction *geminiContent    `json:"systemInstruction,omitempty"`
	GenerationConfig  *generationConfig `json:"generationConfig,omitempty"`
}

type usageMetadata struct {
	PromptTokenCount     int `json:"promptTokenCount"`
	CandidatesTokenCount int `json:"candidatesTokenCount"`
	TotalTokenCount      int `json:"totalTokenCount"`
}

type candidate struct {
	Content struct {
		Role  string       `json:"role"`
		Parts []geminiPart `json:"parts"`
	} `json:"content"`
	FinishReason string `json:"finishReason"`
}

type apiError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Status  string `json:"status"`
}

type generateResponse struct {
	Candidates    []candidate    `json:"candidates"`
	UsageMetadata usageMetadata  `json:"usageMetadata"`
	Error         *apiError      `json:"error,omitempty"`
}

// HTTPError carries non-200 upstream responses.
type HTTPError struct {
	Status int
	Body   string
}

func (e *HTTPError) Error() string {
	return fmt.Sprintf("gemini provider returned %d: %s", e.Status, e.Body)
}

func (c *Client) buildPayload(req ai.GenerateRequest) ([]byte, error) {
	genReq := generateRequest{
		Contents: []geminiContent{
			{
				Role:  "user",
				Parts: []geminiPart{{Text: req.Prompt}},
			},
		},
	}
	if req.System != "" {
		genReq.SystemInstruction = &geminiContent{
			Parts: []geminiPart{{Text: req.System}},
		}
	}
	if req.Temperature > 0 || req.MaxTokens > 0 {
		genReq.GenerationConfig = &generationConfig{
			Temperature:     req.Temperature,
			MaxOutputTokens: req.MaxTokens,
		}
	}
	return json.Marshal(genReq)
}

func (c *Client) do(ctx context.Context, endpoint string, payload []byte, isStream bool) (*http.Response, error) {
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

		httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
		if err != nil {
			return nil, err
		}
		httpReq.Header.Set("Content-Type", "application/json")
		if isStream {
			httpReq.Header.Set("Accept", "text/event-stream")
		} else {
			httpReq.Header.Set("Accept", "application/json")
		}
		if c.cfg.APIKey != "" {
			httpReq.Header.Set(apiKeyHeader, c.cfg.APIKey)
		}

		resp, err := c.http.Do(httpReq)
		if err != nil {
			lastErr = fmt.Errorf("gemini call failed: %w", err)
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

// Generate performs a synchronous completion call against Google Gemini.
func (c *Client) Generate(ctx context.Context, req ai.GenerateRequest) (ai.GenerateResponse, error) {
	payload, err := c.buildPayload(req)
	if err != nil {
		return ai.GenerateResponse{}, fmt.Errorf("encode gemini request: %w", err)
	}

	modelPath := c.model
	if !strings.HasPrefix(modelPath, "models/") {
		modelPath = "models/" + modelPath
	}
	endpoint := fmt.Sprintf("%s/%s:generateContent", strings.TrimRight(c.cfg.BaseURL, "/"), modelPath)

	resp, err := c.do(ctx, endpoint, payload, false)
	if err != nil {
		return ai.GenerateResponse{}, err
	}
	defer resp.Body.Close()

	var out generateResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return ai.GenerateResponse{}, fmt.Errorf("decode gemini response: %w", err)
	}

	if out.Error != nil {
		return ai.GenerateResponse{}, fmt.Errorf("gemini error: %s (%s)", out.Error.Message, out.Error.Status)
	}

	if len(out.Candidates) == 0 {
		return ai.GenerateResponse{}, fmt.Errorf("gemini response had no candidates")
	}

	var sb strings.Builder
	for _, part := range out.Candidates[0].Content.Parts {
		sb.WriteString(part.Text)
	}

	return ai.GenerateResponse{
		Text:  sb.String(),
		Model: c.model,
		Usage: ai.TokenUsage{
			PromptTokens:     out.UsageMetadata.PromptTokenCount,
			CompletionTokens: out.UsageMetadata.CandidatesTokenCount,
			TotalTokens:      out.UsageMetadata.TotalTokenCount,
		},
	}, nil
}

// GenerateStream initiates an SSE streaming completion from Google Gemini.
func (c *Client) GenerateStream(ctx context.Context, req ai.GenerateRequest) (ai.StreamReader, error) {
	payload, err := c.buildPayload(req)
	if err != nil {
		return nil, fmt.Errorf("encode gemini request: %w", err)
	}

	modelPath := c.model
	if !strings.HasPrefix(modelPath, "models/") {
		modelPath = "models/" + modelPath
	}
	endpoint := fmt.Sprintf("%s/%s:streamGenerateContent?alt=sse", strings.TrimRight(c.cfg.BaseURL, "/"), modelPath)

	resp, err := c.do(ctx, endpoint, payload, true)
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

		var frame generateResponse
		if err := json.Unmarshal([]byte(data), &frame); err != nil {
			continue
		}

		if frame.Error != nil {
			r.done = true
			return "", fmt.Errorf("gemini stream error: %s (%s)", frame.Error.Message, frame.Error.Status)
		}

		if frame.UsageMetadata.TotalTokenCount > 0 {
			r.usage.PromptTokens = frame.UsageMetadata.PromptTokenCount
			r.usage.CompletionTokens = frame.UsageMetadata.CandidatesTokenCount
			r.usage.TotalTokens = frame.UsageMetadata.TotalTokenCount
		}

		var delta string
		for _, cand := range frame.Candidates {
			for _, part := range cand.Content.Parts {
				delta += part.Text
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
	return "", fmt.Errorf("gemini stream read: %w", err)
}

func (r *streamReader) Close() error {
	return r.body.Close()
}

// ---- embeddings -------------------------------------------------------------

type embedContentRequest struct {
	Model   string        `json:"model"`
	Content geminiContent `json:"content"`
}

type batchEmbedRequest struct {
	Requests []embedContentRequest `json:"requests"`
}

type batchEmbedResponse struct {
	Embeddings []struct {
		Values []float32 `json:"values"`
	} `json:"embeddings"`
	Error *apiError `json:"error,omitempty"`
}

// Embedder implements ai.EmbeddingProvider using Google Gemini's batchEmbedContents endpoint.
type Embedder struct {
	cfg   Config
	http  *http.Client
	model string
}

// NewEmbedder builds a native Gemini batch embeddings adapter.
func NewEmbedder(cfg Config) *Embedder {
	if cfg.Timeout <= 0 {
		cfg.Timeout = 90 * time.Second
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

// Model returns the embedding model name.
func (e *Embedder) Model() string {
	return e.model
}

// Embed maps texts to vector embeddings using Gemini's batchEmbedContents API.
func (e *Embedder) Embed(ctx context.Context, texts []string) ([][]float32, error) {
	if len(texts) == 0 {
		return nil, nil
	}

	modelPath := e.model
	if !strings.HasPrefix(modelPath, "models/") {
		modelPath = "models/" + modelPath
	}

	reqs := make([]embedContentRequest, len(texts))
	for i, text := range texts {
		reqs[i] = embedContentRequest{
			Model: modelPath,
			Content: geminiContent{
				Parts: []geminiPart{{Text: text}},
			},
		}
	}

	body := batchEmbedRequest{Requests: reqs}
	payload, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("encode gemini embed request: %w", err)
	}

	endpoint := fmt.Sprintf("%s/%s:batchEmbedContents", strings.TrimRight(e.cfg.BaseURL, "/"), modelPath)
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	if e.cfg.APIKey != "" {
		httpReq.Header.Set(apiKeyHeader, e.cfg.APIKey)
	}

	resp, err := e.http.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("gemini embed call failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		snippet, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return nil, &HTTPError{Status: resp.StatusCode, Body: string(snippet)}
	}

	var out batchEmbedResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, fmt.Errorf("decode gemini embed response: %w", err)
	}

	if out.Error != nil {
		return nil, fmt.Errorf("gemini embed error: %s (%s)", out.Error.Message, out.Error.Status)
	}

	if len(out.Embeddings) != len(texts) {
		return nil, fmt.Errorf("gemini embed returned %d embeddings for %d inputs", len(out.Embeddings), len(texts))
	}

	vectors := make([][]float32, len(texts))
	for i, emb := range out.Embeddings {
		vectors[i] = emb.Values
	}

	return vectors, nil
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
