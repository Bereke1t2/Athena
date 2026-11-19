package claude

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"athena/backend/internal/domain/ai"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestClaudeGenerateSuccess(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodPost, r.Method)
		assert.Equal(t, "/messages", r.URL.Path)
		assert.Equal(t, "test-api-key", r.Header.Get("x-api-key"))
		assert.Equal(t, "2023-06-01", r.Header.Get("anthropic-version"))
		assert.Equal(t, "application/json", r.Header.Get("Content-Type"))

		w.Header().Set("Content-Type", "application/json")
		_, _ = fmt.Fprint(w, `{
			"id": "msg_01234",
			"type": "message",
			"role": "assistant",
			"model": "claude-3-5-sonnet-20241022",
			"content": [
				{"type": "text", "text": "This is a synthesized academic summary."}
			],
			"stop_reason": "end_turn",
			"usage": {
				"input_tokens": 42,
				"output_tokens": 18
			}
		}`)
	}))
	defer server.Close()

	client := NewClient(Config{
		BaseURL: server.URL,
		APIKey:  "test-api-key",
		Model:   "claude-3-5-sonnet-20241022",
		Timeout: 5 * time.Second,
	})

	assert.Equal(t, "claude-3-5-sonnet-20241022", client.Model())

	resp, err := client.Generate(context.Background(), ai.GenerateRequest{
		System:      "You are an academic researcher.",
		Prompt:      "Summarize the paper.",
		MaxTokens:   500,
		Temperature: 0.2,
	})
	require.NoError(t, err)
	assert.Equal(t, "This is a synthesized academic summary.", resp.Text)
	assert.Equal(t, "claude-3-5-sonnet-20241022", resp.Model)
	assert.Equal(t, 42, resp.Usage.PromptTokens)
	assert.Equal(t, 18, resp.Usage.CompletionTokens)
	assert.Equal(t, 60, resp.Usage.TotalTokens)
}

func TestClaudeGenerateStream(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodPost, r.Method)
		assert.Equal(t, "text/event-stream", r.Header.Get("Accept"))

		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)

		events := []string{
			`event: message_start` + "\n" + `data: {"type": "message_start", "message": {"id": "msg_1", "model": "claude-3-5-sonnet-20241022", "usage": {"input_tokens": 15}}}` + "\n\n",
			`event: content_block_start` + "\n" + `data: {"type": "content_block_start", "index": 0, "content_block": {"type": "text", "text": ""}}` + "\n\n",
			`event: content_block_delta` + "\n" + `data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "Continuous "}}` + "\n\n",
			`event: content_block_delta` + "\n" + `data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "representation."}}` + "\n\n",
			`event: content_block_stop` + "\n" + `data: {"type": "content_block_stop", "index": 0}` + "\n\n",
			`event: message_delta` + "\n" + `data: {"type": "message_delta", "delta": {"stop_reason": "end_turn"}, "usage": {"output_tokens": 6}}` + "\n\n",
			`event: message_stop` + "\n" + `data: {"type": "message_stop"}` + "\n\n",
		}

		for _, ev := range events {
			_, _ = fmt.Fprint(w, ev)
		}
	}))
	defer server.Close()

	client := NewClient(Config{
		BaseURL: server.URL,
		APIKey:  "stream-api-key",
	})

	stream, err := client.GenerateStream(context.Background(), ai.GenerateRequest{
		Prompt: "Explain word embeddings.",
	})
	require.NoError(t, err)
	defer stream.Close()

	d1, err := stream.Next(context.Background())
	require.NoError(t, err)
	assert.Equal(t, "Continuous ", d1)

	d2, err := stream.Next(context.Background())
	require.NoError(t, err)
	assert.Equal(t, "representation.", d2)

	_, err = stream.Next(context.Background())
	assert.ErrorIs(t, err, io.EOF)
}

func TestClaudeRateLimitRetry(t *testing.T) {
	attempts := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		attempts++
		if attempts < 2 {
			w.WriteHeader(http.StatusTooManyRequests)
			_, _ = fmt.Fprint(w, `{"type": "error", "error": {"type": "rate_limit_error", "message": "Rate limit exceeded"}}`)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = fmt.Fprint(w, `{
			"id": "msg_retry",
			"content": [{"type": "text", "text": "Success after retry"}],
			"usage": {"input_tokens": 5, "output_tokens": 5}
		}`)
	}))
	defer server.Close()

	client := NewClient(Config{
		BaseURL: server.URL,
		APIKey:  "key",
		Timeout: 5 * time.Second,
	})

	resp, err := client.Generate(context.Background(), ai.GenerateRequest{
		Prompt: "Testing retry",
	})
	require.NoError(t, err)
	assert.Equal(t, "Success after retry", resp.Text)
	assert.Equal(t, 2, attempts)
}

func TestClaudeErrorResponse(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = fmt.Fprint(w, `{"type": "error", "error": {"type": "invalid_request_error", "message": "max_tokens too large"}}`)
	}))
	defer server.Close()

	client := NewClient(Config{
		BaseURL: server.URL,
		APIKey:  "key",
	})

	_, err := client.Generate(context.Background(), ai.GenerateRequest{
		Prompt: "Invalid request test",
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "claude provider returned 400")
}
