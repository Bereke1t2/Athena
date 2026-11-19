package openaicompat

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

func TestOpenAICompatGenerateSuccess(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodPost, r.Method)
		assert.Equal(t, "/chat/completions", r.URL.Path)
		assert.Equal(t, "Bearer test-key", r.Header.Get("Authorization"))

		w.Header().Set("Content-Type", "application/json")
		_, _ = fmt.Fprint(w, `{
			"model": "gpt-4o-mini",
			"choices": [
				{
					"message": {
						"content": "Deep residual learning for image recognition."
					}
				}
			],
			"usage": {
				"prompt_tokens": 15,
				"completion_tokens": 8,
				"total_tokens": 23
			}
		}`)
	}))
	defer server.Close()

	client := NewClient(Config{
		BaseURL: server.URL,
		APIKey:  "test-key",
		Model:   "gpt-4o-mini",
		Timeout: 5 * time.Second,
	})

	assert.Equal(t, "gpt-4o-mini", client.Model())

	resp, err := client.Generate(context.Background(), ai.GenerateRequest{
		System: "Summarizer",
		Prompt: "Explain ResNet",
	})
	require.NoError(t, err)
	assert.Equal(t, "Deep residual learning for image recognition.", resp.Text)
	assert.Equal(t, "gpt-4o-mini", resp.Model)
	assert.Equal(t, 15, resp.Usage.PromptTokens)
	assert.Equal(t, 8, resp.Usage.CompletionTokens)
	assert.Equal(t, 23, resp.Usage.TotalTokens)
}

func TestOpenAICompatGenerateStream(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodPost, r.Method)
		assert.Equal(t, "/chat/completions", r.URL.Path)

		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)

		events := []string{
			`data: {"choices": [{"delta": {"content": "Residual "}}]}` + "\n\n",
			`data: {"choices": [{"delta": {"content": "connections."}}]}` + "\n\n",
			`data: [DONE]` + "\n\n",
		}
		for _, ev := range events {
			_, _ = fmt.Fprint(w, ev)
		}
	}))
	defer server.Close()

	client := NewClient(Config{
		BaseURL: server.URL,
		Model:   "gpt-4o-mini",
	})

	stream, err := client.GenerateStream(context.Background(), ai.GenerateRequest{Prompt: "Explain"})
	require.NoError(t, err)
	defer stream.Close()

	d1, err := stream.Next(context.Background())
	require.NoError(t, err)
	assert.Equal(t, "Residual ", d1)

	d2, err := stream.Next(context.Background())
	require.NoError(t, err)
	assert.Equal(t, "connections.", d2)

	_, err = stream.Next(context.Background())
	assert.ErrorIs(t, err, io.EOF)
}

func TestOpenAICompatEmbed(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodPost, r.Method)
		assert.Equal(t, "/embeddings", r.URL.Path)

		w.Header().Set("Content-Type", "application/json")
		_, _ = fmt.Fprint(w, `{
			"data": [
				{"index": 0, "embedding": [0.1, 0.2]},
				{"index": 1, "embedding": [0.3, 0.4]}
			],
			"usage": {"total_tokens": 10}
		}`)
	}))
	defer server.Close()

	embedder := NewEmbedder(Config{
		BaseURL: server.URL,
		Model:   "text-embedding-3-small",
	})

	assert.Equal(t, "text-embedding-3-small", embedder.Model())

	vecs, err := embedder.Embed(context.Background(), []string{"a", "b"})
	require.NoError(t, err)
	require.Len(t, vecs, 2)
	assert.Equal(t, []float32{0.1, 0.2}, vecs[0])
	assert.Equal(t, []float32{0.3, 0.4}, vecs[1])
}
