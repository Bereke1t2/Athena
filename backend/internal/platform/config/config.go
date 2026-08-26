// Package config provides typed environment-only configuration with
// fail-fast validation. Application settings use the ATHENA_ prefix;
// provider-specific variables keep their documented names.
package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	AppEnv          string
	HTTPAddr        string
	ShutdownTimeout time.Duration
	LogLevel        string
	LogFormat       string

	DatabaseURL string
	DBMaxConns  int32
	RedisAddr   string

	AdminToken        string
	WorkerConcurrency int
	IngestionEnabled  bool

	SemanticScholarAPIKey string
	OpenAlexMailto        string
	ArxivUserAgent        string

	// Base-URL overrides (tests / outage simulation); empty = official APIs.
	OpenAlexBaseURL string
	ArxivBaseURL    string
	S2BaseURL       string

	// MetricsAddr serves Prometheus /metrics from the worker process when set.
	MetricsAddr string

	OpenAlexMaxRPS   float64
	S2MaxRPS         float64
	ArxivMinInterval time.Duration

	// AI layer (ADR-0004). Empty LLMProvider disables the AI endpoints.
	// "stub" selects a deterministic no-network provider for dev/tests.
	LLMProvider           string // openai_compatible | stub
	LLMBaseURL            string
	LLMAPIKey             string
	LLMModel              string
	EmbeddingProviderName string // openai_compatible | none
	EmbeddingModel        string
	EmbeddingDim          int

	// Base-URL override for tests of the OpenAI-compatible adapter.
	LLMOverrideBaseURL string
}

// AIEnabled reports whether summary/chat endpoints should be wired.
func (c Config) AIEnabled() bool { return c.LLMProvider != "" }

func FromEnv() (Config, error) {
	cfg := Config{
		AppEnv:                getEnv("ATHENA_APP_ENV", "development"),
		HTTPAddr:              getEnv("ATHENA_HTTP_ADDR", ":8080"),
		LogLevel:              getEnv("ATHENA_LOG_LEVEL", "info"),
		LogFormat:             getEnv("ATHENA_LOG_FORMAT", ""),
		ShutdownTimeout:       getDuration("ATHENA_SHUTDOWN_TIMEOUT", 15*time.Second),
		DatabaseURL:           strings.TrimSpace(os.Getenv("ATHENA_DATABASE_URL")),
		DBMaxConns:            getInt32("ATHENA_DB_MAX_CONNS", 20),
		RedisAddr:             getEnv("ATHENA_REDIS_ADDR", "localhost:6379"),
		AdminToken:            strings.TrimSpace(os.Getenv("ATHENA_ADMIN_TOKEN")),
		WorkerConcurrency:     getInt("ATHENA_WORKER_CONCURRENCY", 4),
		IngestionEnabled:      getBool("ATHENA_INGESTION_ENABLED", true),
		SemanticScholarAPIKey: strings.TrimSpace(os.Getenv("SEMANTICSCHOLAR_API_KEY")),
		OpenAlexMailto:        strings.TrimSpace(os.Getenv("OPENALEX_MAILTO")),
		OpenAlexBaseURL:       strings.TrimSpace(os.Getenv("OPENALEX_BASE_URL")),
		ArxivBaseURL:          strings.TrimSpace(os.Getenv("ARXIV_BASE_URL")),
		S2BaseURL:             strings.TrimSpace(os.Getenv("SEMANTICSCHOLAR_BASE_URL")),
		MetricsAddr:           strings.TrimSpace(os.Getenv("ATHENA_METRICS_ADDR")),
		ArxivUserAgent: getEnv("ARXIV_USER_AGENT",
			fmt.Sprintf("athena/0.1 (mailto:%s)", firstNonEmpty(strings.TrimSpace(os.Getenv("OPENALEX_MAILTO")), "contact@athena.dev"))),
		OpenAlexMaxRPS:   getFloat("OPENALEX_MAX_RPS", 8),
		S2MaxRPS:         getFloat("SEMANTICSCHOLAR_MAX_RPS", 0.8),
		ArxivMinInterval: getDuration("ARXIV_MIN_INTERVAL", 3*time.Second),

		LLMProvider:           strings.TrimSpace(os.Getenv("LLM_PROVIDER")),
		LLMBaseURL:            strings.TrimSpace(os.Getenv("LLM_BASE_URL")),
		LLMAPIKey:             strings.TrimSpace(os.Getenv("LLM_API_KEY")),
		LLMModel:              strings.TrimSpace(os.Getenv("LLM_MODEL")),
		EmbeddingProviderName: strings.TrimSpace(os.Getenv("EMBEDDING_PROVIDER")),
		EmbeddingModel:        strings.TrimSpace(os.Getenv("EMBEDDING_MODEL")),
		EmbeddingDim:          getInt("EMBEDDING_DIM", 1536),
		LLMOverrideBaseURL:    strings.TrimSpace(os.Getenv("LLM_OVERRIDE_BASE_URL")),
	}
	if cfg.LogFormat == "" {
		if cfg.AppEnv == "production" {
			cfg.LogFormat = "json"
		} else {
			cfg.LogFormat = "text"
		}
	}

	var problems []string
	if cfg.DatabaseURL == "" {
		problems = append(problems, "ATHENA_DATABASE_URL is required")
	}
	switch cfg.AppEnv {
	case "development", "staging", "production":
	default:
		problems = append(problems, fmt.Sprintf("ATHENA_APP_ENV invalid %q (want development|staging|production)", cfg.AppEnv))
	}
	switch cfg.LogLevel {
	case "debug", "info", "warn", "error":
	default:
		problems = append(problems, fmt.Sprintf("ATHENA_LOG_LEVEL invalid %q", cfg.LogLevel))
	}
	switch cfg.LogFormat {
	case "text", "json":
	default:
		problems = append(problems, fmt.Sprintf("ATHENA_LOG_FORMAT invalid %q", cfg.LogFormat))
	}
	switch cfg.LLMProvider {
	case "", "openai_compatible", "stub":
	default:
		problems = append(problems, fmt.Sprintf("LLM_PROVIDER invalid %q (want openai_compatible|stub)", cfg.LLMProvider))
	}
	if cfg.LLMProvider != "" {
		if cfg.LLMModel == "" {
			cfg.LLMModel = "gpt-4o-mini"
		}
		switch cfg.EmbeddingProviderName {
		case "openai_compatible":
			if cfg.EmbeddingModel == "" {
				cfg.EmbeddingModel = "text-embedding-3-small"
			}
		case "", "none":
			cfg.EmbeddingProviderName = ""
		default:
			problems = append(problems, fmt.Sprintf("EMBEDDING_PROVIDER invalid %q (want openai_compatible|none)", cfg.EmbeddingProviderName))
		}
		if cfg.EmbeddingDim <= 0 || cfg.EmbeddingDim > 4096 {
			problems = append(problems, fmt.Sprintf("EMBEDDING_DIM invalid %d", cfg.EmbeddingDim))
		}
	}
	if problems != nil {
		return Config{}, fmt.Errorf("invalid configuration: %s", strings.Join(problems, "; "))
	}
	return cfg, nil
}

func getEnv(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}

func getDuration(key string, fallback time.Duration) time.Duration {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	d, err := time.ParseDuration(v)
	if err != nil || d <= 0 {
		return fallback
	}
	return d
}

func getInt(key string, fallback int) int {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return fallback
	}
	return n
}

func getInt32(key string, fallback int32) int32 {
	return int32(getInt(key, int(fallback)))
}

func getFloat(key string, fallback float64) float64 {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	f, err := strconv.ParseFloat(v, 64)
	if err != nil || f <= 0 {
		return fallback
	}
	return f
}

func getBool(key string, fallback bool) bool {
	v, ok := os.LookupEnv(key)
	if !ok || v == "" {
		return fallback
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		return fallback
	}
	return b
}
