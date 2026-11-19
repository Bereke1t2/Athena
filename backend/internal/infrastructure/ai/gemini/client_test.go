package gemini

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

func TestGeminiGenerateSuccess(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodPost, r.Method)
		assert.Equal(t, "/models/gemini-1.5-flash:generateContent", r.URL.Path)
		assert.Equal(t, "gemini-api-key", r.Header.Get("x-goog-api-key"))
		assert.Equal(t, "application/json", r.Header.Get("Content-Type"))

		w.Header().Set("Content-Type", "application/json")
		_, _ = fmt.Fprint(w, `{
			"candidates": [
				{
					"content": {
						"parts": [{"text": "Quantum computing utilizes qubits for superposition."}],
						"role": "model"
					},
					"finishReason": "STOP"
				}
			],
			"usageMetadata": {
				"promptTokenCount": 50,
				"candidatesTokenCount": 25,
				"totalTokenCount": 75
			}
		}`)
	}))
	defer server.Close()

	client := NewClient(Config{
		BaseURL: server.URL,
		APIKey:  "gemini-api-key",
		Model:   "gemini-1.5-flash",
		Timeout: 5 * time.Second,
	})

	assert.Equal(t, "gemini-1.5-flash", client.Model())

	resp, err := client.Generate(context.Background(), ai.GenerateRequest{
		System:      "Physics expert",
		Prompt:      "Explain quantum superposition",
		MaxTokens:   300,
		Temperature: 0.3,
	})
	require.NoError(t, err)
	assert.Equal(t, "Quantum computing utilizes qubits for superposition.", resp.Text)
	assert.Equal(t, "gemini-1.5-flash", resp.Model)
	assert.Equal(t, 50, resp.Usage.PromptTokens)
	assert.Equal(t, 25, resp.Usage.CompletionTokens)
	assert.Equal(t, 75, resp.Usage.TotalTokens)
}

func TestGeminiGenerateStream(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodPost, r.Method)
		assert.Equal(t, "/models/gemini-1.5-flash:streamGenerateContent", r.URL.Path)
		assert.Equal(t, "alt=sse", r.URL.RawQuery)

		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)

		events := []string{
			`data: {"candidates": [{"content": {"parts": [{"text": "Qubits "}]}}]}` + "\n\n",
			`data: {"candidates": [{"content": {"parts": [{"text": "enable parallelism."}]}}], "usageMetadata": {"promptTokenCount": 10, "candidatesTokenCount": 5, "totalTokenCount": 15}}` + "\n\n",
		}
		for _, ev := range events {
			_, _ = fmt.Fprint(w, ev)
		}
	}))
	defer server.Close()

	client := NewClient(Config{
		BaseURL: server.URL,
		APIKey:  "key",
		Model:   "gemini-1.5-flash",
	})

	stream, err := client.GenerateStream(context.Background(), ai.GenerateRequest{
		Prompt: "What do qubits do?",
	})
	require.NoError(t, err)
	defer stream.Close()

	d1, err := stream.Next(context.Background())
	require.NoError(t, err)
	assert.Equal(t, "Qubits ", d1)

	d2, err := stream.Next(context.Background())
	require.NoError(t, err)
	assert.Equal(t, "enable parallelism.", d2)

	_, err = stream.Next(context.Background())
	assert.ErrorIs(t, err, io.EOF)
}

func TestGeminiBatchEmbed(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodPost, r.Method)
		assert.Equal(t, "/models/text-embedding-004:batchEmbedContents", r.URL.Path)
		assert.Equal(t, "embed-key", r.Header.Get("x-goog-api-key"))

		w.Header().Set("Content-Type", "application/json")
		_, _ = fmt.Fprint(w, `{
			"embeddings": [
				{"values": [0.01, 0.02, 0.03]},
				{"values": [0.04, 0.05, 0.06]}
			]
		}`)
	}))
	defer server.Close()

	embedder := NewEmbedder(Config{
		BaseURL: server.URL,
		APIKey:  "embed-key",
		Model:   "text-embedding-004",
	})

	assert.Equal(t, "text-embedding-004", embedder.Model())

	vecs, err := embedder.Embed(context.Background(), []string{"text a", "text b"})
	require.NoError(t, err)
	require.Len(t, vecs, 2)
	assert.Equal(t, []float32{0.01, 0.02, 0.03}, vecs[0])
	assert.Equal(t, []float32{0.04, 0.05, 0.06}, vecs[1])
}

func TestGeminiErrorResponse(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
		_, _ = fmt.Fprint(w, `{"error": {"code": 403, "message": "API key not valid", "status": "PERMISSION_DENIED"}}`)
	}))
	defer server.Close()

	client := NewClient(Config{
		BaseURL: server.URL,
		APIKey:  "bad-key",
	})

	_, err := client.Generate(context.Background(), ai.GenerateRequest{Prompt: "test"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "gemini provider returned 403")
}
