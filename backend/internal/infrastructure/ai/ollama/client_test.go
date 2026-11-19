package ollama

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

func TestOllamaGenerateSuccess(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodPost, r.Method)
		assert.Equal(t, "/api/chat", r.URL.Path)

		w.Header().Set("Content-Type", "application/json")
		_, _ = fmt.Fprint(w, `{
			"model": "llama3.2",
			"created_at": "2026-11-19T12:00:00Z",
			"message": {
				"role": "assistant",
				"content": "Attention is all you need for transformer architectures."
			},
			"done": true,
			"prompt_eval_count": 35,
			"eval_count": 22
		}`)
	}))
	defer server.Close()

	client := NewClient(Config{
		BaseURL: server.URL,
		Model:   "llama3.2",
		Timeout: 5 * time.Second,
	})

	assert.Equal(t, "llama3.2", client.Model())

	resp, err := client.Generate(context.Background(), ai.GenerateRequest{
		System:      "Academic summarizer",
		Prompt:      "Explain self-attention",
		MaxTokens:   256,
		Temperature: 0.5,
	})
	require.NoError(t, err)
	assert.Equal(t, "Attention is all you need for transformer architectures.", resp.Text)
	assert.Equal(t, "llama3.2", resp.Model)
	assert.Equal(t, 35, resp.Usage.PromptTokens)
	assert.Equal(t, 22, resp.Usage.CompletionTokens)
	assert.Equal(t, 57, resp.Usage.TotalTokens)
}

func TestOllamaGenerateStream(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodPost, r.Method)
		assert.Equal(t, "/api/chat", r.URL.Path)

		w.Header().Set("Content-Type", "application/x-ndjson")
		w.WriteHeader(http.StatusOK)

		lines := []string{
			`{"model":"llama3.2","message":{"role":"assistant","content":"Neural "},"done":false}` + "\n",
			`{"model":"llama3.2","message":{"role":"assistant","content":"networks "},"done":false}` + "\n",
			`{"model":"llama3.2","message":{"role":"assistant","content":"learn."},"done":false}` + "\n",
			`{"model":"llama3.2","message":{"role":"assistant","content":""},"done":true,"prompt_eval_count":10,"eval_count":5}` + "\n",
		}
		for _, l := range lines {
			_, _ = fmt.Fprint(w, l)
		}
	}))
	defer server.Close()

	client := NewClient(Config{
		BaseURL: server.URL,
		Model:   "llama3.2",
	})

	stream, err := client.GenerateStream(context.Background(), ai.GenerateRequest{
		Prompt: "Explain learning",
	})
	require.NoError(t, err)
	defer stream.Close()

	d1, err := stream.Next(context.Background())
	require.NoError(t, err)
	assert.Equal(t, "Neural ", d1)

	d2, err := stream.Next(context.Background())
	require.NoError(t, err)
	assert.Equal(t, "networks ", d2)

	d3, err := stream.Next(context.Background())
	require.NoError(t, err)
	assert.Equal(t, "learn.", d3)

	_, err = stream.Next(context.Background())
	assert.ErrorIs(t, err, io.EOF)
}

func TestOllamaBatchEmbed(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodPost, r.Method)
		assert.Equal(t, "/api/embed", r.URL.Path)

		w.Header().Set("Content-Type", "application/json")
		_, _ = fmt.Fprint(w, `{
			"model": "nomic-embed-text",
			"embeddings": [
				[0.1, 0.2, 0.3],
				[0.4, 0.5, 0.6]
			]
		}`)
	}))
	defer server.Close()

	embedder := NewEmbedder(Config{
		BaseURL: server.URL,
		Model:   "nomic-embed-text",
	})

	assert.Equal(t, "nomic-embed-text", embedder.Model())

	vecs, err := embedder.Embed(context.Background(), []string{"hello", "world"})
	require.NoError(t, err)
	require.Len(t, vecs, 2)
	assert.Equal(t, []float32{0.1, 0.2, 0.3}, vecs[0])
	assert.Equal(t, []float32{0.4, 0.5, 0.6}, vecs[1])
}

func TestOllamaLegacyEmbedFallback(t *testing.T) {
	callCount := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/api/embed" {
			w.WriteHeader(http.StatusNotFound)
			_, _ = fmt.Fprint(w, `{"error": "not found"}`)
			return
		}
		if r.URL.Path == "/api/embeddings" {
			callCount++
			w.Header().Set("Content-Type", "application/json")
			_, _ = fmt.Fprintf(w, `{
				"embedding": [0.7, 0.8, %0.1f]
			}`, float64(callCount))
			return
		}
		w.WriteHeader(http.StatusBadRequest)
	}))
	defer server.Close()

	embedder := NewEmbedder(Config{
		BaseURL: server.URL,
		Model:   "nomic-embed-text",
	})

	vecs, err := embedder.Embed(context.Background(), []string{"sample 1", "sample 2"})
	require.NoError(t, err)
	require.Len(t, vecs, 2)
	assert.Equal(t, 2, callCount)
	assert.Equal(t, []float32{0.7, 0.8, 1.0}, vecs[0])
	assert.Equal(t, []float32{0.7, 0.8, 2.0}, vecs[1])
}

func TestOllamaErrorHandling(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = fmt.Fprint(w, `{"error": "model 'nonexistent' not found"}`)
	}))
	defer server.Close()

	client := NewClient(Config{
		BaseURL: server.URL,
		Model:   "nonexistent",
	})

	_, err := client.Generate(context.Background(), ai.GenerateRequest{Prompt: "test"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "ollama provider returned 500")
}
