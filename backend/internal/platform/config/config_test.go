package config

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func clearEnv(t *testing.T) {
	t.Helper()
	keys := []string{
		"ATHENA_APP_ENV", "ATHENA_HTTP_ADDR", "ATHENA_LOG_LEVEL", "ATHENA_LOG_FORMAT",
		"ATHENA_SHUTDOWN_TIMEOUT", "ATHENA_DATABASE_URL", "ATHENA_DB_MAX_CONNS",
		"ATHENA_REDIS_ADDR", "ATHENA_ADMIN_TOKEN", "ATHENA_WORKER_CONCURRENCY",
		"ATHENA_INGESTION_ENABLED", "SEMANTICSCHOLAR_API_KEY", "OPENALEX_MAILTO",
		"ARXIV_USER_AGENT", "OPENALEX_MAX_RPS", "SEMANTICSCHOLAR_MAX_RPS",
		"ARXIV_MIN_INTERVAL", "LLM_PROVIDER", "LLM_BASE_URL", "LLM_API_KEY",
		"LLM_MODEL", "EMBEDDING_PROVIDER", "EMBEDDING_MODEL", "EMBEDDING_DIM",
	}
	for _, k := range keys {
		t.Setenv(k, "")
	}
}

func setEnv(t *testing.T, kv map[string]string) {
	t.Helper()
	clearEnv(t)
	for k, v := range kv {
		t.Setenv(k, v)
	}
}

func TestFromEnvDefaultsRequireDatabaseURL(t *testing.T) {
	setEnv(t, map[string]string{"ATHENA_DATABASE_URL": "postgres://localhost/test"})
	cfg, err := FromEnv()
	require.NoError(t, err)
	assert.Equal(t, ":8080", cfg.HTTPAddr)
	assert.Equal(t, "development", cfg.AppEnv)
	assert.Equal(t, "info", cfg.LogLevel)
	assert.Equal(t, "text", cfg.LogFormat)
	assert.Equal(t, int32(20), cfg.DBMaxConns)
	assert.True(t, cfg.IngestionEnabled)
}

func TestFromEnvProductionDefaultsToJSONLogs(t *testing.T) {
	setEnv(t, map[string]string{
		"ATHENA_DATABASE_URL": "postgres://localhost/test",
		"ATHENA_APP_ENV":      "production",
	})
	cfg, err := FromEnv()
	require.NoError(t, err)
	assert.Equal(t, "json", cfg.LogFormat)
}

func TestFromEnvCollectsValidationErrors(t *testing.T) {
	clearEnv(t)
	_, err := FromEnv()
	require.Error(t, err)
	assert.Contains(t, err.Error(), "ATHENA_DATABASE_URL")

	setEnv(t, map[string]string{
		"ATHENA_DATABASE_URL": "postgres://x",
		"ATHENA_APP_ENV":      "banana",
		"ATHENA_LOG_LEVEL":    "loud",
	})
	_, err = FromEnv()
	require.Error(t, err)
	assert.Contains(t, err.Error(), "ATHENA_APP_ENV")
	assert.Contains(t, err.Error(), "ATHENA_LOG_LEVEL")
}

func TestFromEnvDurationsAndNumbers(t *testing.T) {
	setEnv(t, map[string]string{
		"ATHENA_DATABASE_URL":     "postgres://x",
		"ATHENA_SHUTDOWN_TIMEOUT": "45s",
		"ATHENA_DB_MAX_CONNS":     "7",
		"OPENALEX_MAX_RPS":        "2.5",
		"ARXIV_MIN_INTERVAL":      "5s",
	})
	cfg, err := FromEnv()
	require.NoError(t, err)
	assert.Equal(t, 45*time.Second, cfg.ShutdownTimeout)
	assert.Equal(t, int32(7), cfg.DBMaxConns)
	assert.InDelta(t, 2.5, cfg.OpenAlexMaxRPS, 0.001)
	assert.Equal(t, 5*time.Second, cfg.ArxivMinInterval)
}
