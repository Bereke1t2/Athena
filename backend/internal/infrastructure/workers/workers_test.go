package workers_test

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"athena/backend/internal/infrastructure/workers"
)

func TestPeriodicWeeklyDigest(t *testing.T) {
	pj := workers.PeriodicWeeklyDigest(7 * 24 * time.Hour)
	require.NotNil(t, pj)

	args, opts := workers.PeriodicWeeklyDigestConstructor()
	require.NotNil(t, args)
	require.NotNil(t, opts)

	assert.Equal(t, workers.WeeklyDigestKind, args.Kind())
	assert.Equal(t, "notifications", opts.Queue)
}

func TestPeriodicSyncWindow(t *testing.T) {
	pj := workers.PeriodicSyncWindow("openalex", 6*time.Hour)
	require.NotNil(t, pj)

	args, opts := workers.PeriodicSyncWindowConstructor("openalex")
	require.NotNil(t, args)
	require.NotNil(t, opts)

	assert.Equal(t, workers.SyncProviderWindowKind, args.Kind())
	assert.Equal(t, "ingestion", opts.Queue)
	assert.Equal(t, workers.MaxJobAttempts, opts.MaxAttempts)

	syncArgs, ok := args.(workers.SyncProviderWindowArgs)
	require.True(t, ok)
	assert.Equal(t, "openalex", syncArgs.ProviderSlug)
	assert.Equal(t, 50, syncArgs.MaxPages)
	assert.True(t, syncArgs.To.After(syncArgs.From))
}

func TestJobKinds(t *testing.T) {
	assert.Equal(t, "weekly_digest", workers.WeeklyDigestArgs{}.Kind())
	assert.Equal(t, "sync_provider_window", workers.SyncProviderWindowArgs{}.Kind())
	assert.Equal(t, "notification_fanout", workers.NotificationFanoutArgs{}.Kind())
	assert.Equal(t, "rag_index_paper", workers.RagIndexArgs{}.Kind())
}
