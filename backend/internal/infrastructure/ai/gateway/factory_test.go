package gateway

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNewLLMProvider(t *testing.T) {
	tests := []struct {
		name        string
		cfg         Config
		expectModel string
		expectErr   bool
	}{
		{
			name:        "stub provider",
			cfg:         Config{Provider: "stub"},
			expectModel: "stub-1",
		},
		{
			name: "claude provider",
			cfg: Config{
				Provider: "claude",
				Model:    "claude-3-5-sonnet-20241022",
				APIKey:   "sk-ant-test",
			},
			expectModel: "claude-3-5-sonnet-20241022",
		},
		{
			name: "ollama provider",
			cfg: Config{
				Provider: "ollama",
				BaseURL:  "http://localhost:11434",
				Model:    "llama3.2",
			},
			expectModel: "llama3.2",
		},
		{
			name: "gemini provider native",
			cfg: Config{
				Provider: "gemini",
				Model:    "gemini-1.5-flash",
				APIKey:   "gemini-test-key",
			},
			expectModel: "gemini-1.5-flash",
		},
		{
			name: "gemini provider openai-compat mode",
			cfg: Config{
				Provider: "gemini",
				BaseURL:  "https://generativelanguage.googleapis.com/v1beta/openai/",
				Model:    "gemini-3.5-flash-lite",
			},
			expectModel: "gemini-3.5-flash-lite",
		},
		{
			name: "openai compatible provider",
			cfg: Config{
				Provider: "openai_compatible",
				BaseURL:  "https://api.openai.com/v1",
				Model:    "gpt-4o-mini",
			},
			expectModel: "gpt-4o-mini",
		},
		{
			name:      "unknown provider error",
			cfg:       Config{Provider: "unknown_llm"},
			expectErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p, err := NewLLMProvider(tt.cfg)
			if tt.expectErr {
				require.Error(t, err)
				assert.Nil(t, p)
			} else {
				require.NoError(t, err)
				require.NotNil(t, p)
				assert.Equal(t, tt.expectModel, p.Model())
			}
		})
	}
}

func TestNewEmbeddingProvider(t *testing.T) {
	tests := []struct {
		name        string
		cfg         Config
		expectModel string
		expectErr   bool
	}{
		{
			name:        "stub / none embedding",
			cfg:         Config{EmbeddingName: "none", EmbeddingDim: 768},
			expectModel: "stub-embed-768",
		},
		{
			name: "gemini native embedding",
			cfg: Config{
				EmbeddingName:  "gemini",
				EmbeddingModel: "text-embedding-004",
				APIKey:         "key",
			},
			expectModel: "text-embedding-004",
		},
		{
			name: "gemini openai-compat embedding",
			cfg: Config{
				BaseURL:        "https://generativelanguage.googleapis.com/v1beta/openai/",
				EmbeddingName:  "gemini",
				EmbeddingModel: "gemini-embedding-001",
			},
			expectModel: "gemini-embedding-001",
		},
		{
			name: "ollama embedding",
			cfg: Config{
				EmbeddingName:  "ollama",
				EmbeddingModel: "nomic-embed-text",
				EmbeddingDim:   768,
			},
			expectModel: "nomic-embed-text",
		},
		{
			name: "openai compatible embedding",
			cfg: Config{
				EmbeddingName:  "openai_compatible",
				EmbeddingModel: "text-embedding-3-small",
				EmbeddingDim:   768,
			},
			expectModel: "text-embedding-3-small",
		},
		{
			name:      "unknown embedding error",
			cfg:       Config{EmbeddingName: "unsupported_embedding"},
			expectErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p, err := NewEmbeddingProvider(tt.cfg)
			if tt.expectErr {
				require.Error(t, err)
				assert.Nil(t, p)
			} else {
				require.NoError(t, err)
				require.NotNil(t, p)
				assert.Equal(t, tt.expectModel, p.Model())
			}
		})
	}
}

func TestFactoryCustomTimeout(t *testing.T) {
	p, err := NewLLMProvider(Config{
		Provider: "claude",
		Timeout:  10 * time.Second,
	})
	require.NoError(t, err)
	assert.Equal(t, "claude-3-5-sonnet-20241022", p.Model())
}
