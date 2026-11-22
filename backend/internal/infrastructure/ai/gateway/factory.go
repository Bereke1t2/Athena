// Package gateway provides a unified multi-model LLM and Embedding provider factory
// supporting Anthropic Claude, Google Gemini, local offline Ollama, OpenAI-compatible
// endpoints, and deterministic stubs (ADR-0004).
package gateway

import (
	"fmt"
	"strings"
	"time"

	"athena/backend/internal/domain/ai"
	"athena/backend/internal/infrastructure/ai/claude"
	"athena/backend/internal/infrastructure/ai/gemini"
	"athena/backend/internal/infrastructure/ai/ollama"
	"athena/backend/internal/infrastructure/ai/openaicompat"
	"athena/backend/internal/infrastructure/ai/stub"
)

// Config encapsulates provider settings for constructing LLM and Embedding instances.
type Config struct {
	Provider       string // claude | gemini | ollama | openai_compatible | stub
	BaseURL        string
	APIKey         string
	Model          string
	EmbeddingName  string // gemini | ollama | openai_compatible | stub | none
	EmbeddingModel string
	EmbeddingDim   int
	Timeout        time.Duration
}

// NewLLMProvider constructs the configured domain LLMProvider.
func NewLLMProvider(cfg Config) (ai.LLMProvider, error) {
	timeout := cfg.Timeout
	if timeout <= 0 {
		timeout = 90 * time.Second
	}

	provider := strings.ToLower(strings.TrimSpace(cfg.Provider))
	switch provider {
	case "stub":
		return stub.New(), nil

	case "claude", "anthropic":
		return claude.NewClient(claude.Config{
			BaseURL: cfg.BaseURL,
			APIKey:  cfg.APIKey,
			Model:   cfg.Model,
			Timeout: timeout,
		}), nil

	case "ollama":
		return ollama.NewClient(ollama.Config{
			BaseURL: cfg.BaseURL,
			Model:   cfg.Model,
			Timeout: timeout,
		}), nil

	case "gemini", "google":
		// If explicitly configured with OpenAI compatibility URL, use openaicompat
		if strings.Contains(cfg.BaseURL, "/openai/") || strings.HasSuffix(cfg.BaseURL, "/openai") {
			return openaicompat.NewClient(openaicompat.Config{
				BaseURL: cfg.BaseURL,
				APIKey:  cfg.APIKey,
				Model:   cfg.Model,
				Timeout: timeout,
			}), nil
		}
		return gemini.NewClient(gemini.Config{
			BaseURL: cfg.BaseURL,
			APIKey:  cfg.APIKey,
			Model:   cfg.Model,
			Timeout: timeout,
		}), nil

	case "openai_compatible", "openai":
		return openaicompat.NewClient(openaicompat.Config{
			BaseURL: cfg.BaseURL,
			APIKey:  cfg.APIKey,
			Model:   cfg.Model,
			Timeout: timeout,
		}), nil

	default:
		return nil, fmt.Errorf("unknown LLM provider %q (supported: claude, gemini, ollama, openai_compatible, stub)", cfg.Provider)
	}
}

// NewEmbeddingProvider constructs the configured domain EmbeddingProvider.
func NewEmbeddingProvider(cfg Config) (ai.EmbeddingProvider, error) {
	timeout := cfg.Timeout
	if timeout <= 0 {
		timeout = 90 * time.Second
	}
	dim := cfg.EmbeddingDim
	if dim <= 0 {
		dim = 768
	}

	embName := strings.ToLower(strings.TrimSpace(cfg.EmbeddingName))
	switch embName {
	case "ollama":
		return ollama.NewEmbedder(ollama.Config{
			BaseURL:    cfg.BaseURL,
			Model:      cfg.EmbeddingModel,
			Dimensions: dim,
			Timeout:    timeout,
		}), nil

	case "gemini", "google":
		if strings.Contains(cfg.BaseURL, "/openai/") || strings.HasSuffix(cfg.BaseURL, "/openai") {
			return openaicompat.NewEmbedder(openaicompat.Config{
				BaseURL:    cfg.BaseURL,
				APIKey:     cfg.APIKey,
				Model:      cfg.EmbeddingModel,
				Dimensions: dim,
				Timeout:    timeout,
			}), nil
		}
		return gemini.NewEmbedder(gemini.Config{
			BaseURL:    cfg.BaseURL,
			APIKey:     cfg.APIKey,
			Model:      cfg.EmbeddingModel,
			Dimensions: dim,
			Timeout:    timeout,
		}), nil

	case "openai_compatible", "openai":
		return openaicompat.NewEmbedder(openaicompat.Config{
			BaseURL:    cfg.BaseURL,
			APIKey:     cfg.APIKey,
			Model:      cfg.EmbeddingModel,
			Dimensions: dim,
			Timeout:    timeout,
		}), nil

	case "stub", "none", "":
		return stub.NewEmbedder(dim), nil

	default:
		return nil, fmt.Errorf("unknown embedding provider %q (supported: gemini, ollama, openai_compatible, stub, none)", cfg.EmbeddingName)
	}
}
