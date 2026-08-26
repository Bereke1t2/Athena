// Command worker runs Athena's background job processors (River queue on
// PostgreSQL): provider sync windows today; enrichment, embedding, and
// reindexing jobs in later phases.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/riverqueue/river"
	riverpgxv5 "github.com/riverqueue/river/riverdriver/riverpgxv5"

	"athena/backend/internal/application/ingestion"
	"athena/backend/internal/infrastructure/database"
	arxivadapter "athena/backend/internal/infrastructure/providers/arxiv"
	openalexadapter "athena/backend/internal/infrastructure/providers/openalex"
	s2adapter "athena/backend/internal/infrastructure/providers/semanticscholar"
	"athena/backend/internal/infrastructure/workers"
	"athena/backend/internal/platform/config"
	"athena/backend/internal/platform/logger"
)

func main() {
	cfg, err := config.FromEnv()
	if err != nil {
		slog.Error("configuration invalid", "error", err)
		os.Exit(1)
	}
	log := logger.New(cfg.LogLevel, cfg.LogFormat)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	pool, err := database.Connect(ctx, cfg.DatabaseURL, cfg.DBMaxConns)
	if err != nil {
		log.Error("database connect failed", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	// Optional Prometheus endpoint so provider breaker/retry metrics are
	// observable where they actually fire (worker process).
	if cfg.MetricsAddr != "" {
		mux := http.NewServeMux()
		mux.Handle("/metrics", promhttp.Handler())
		go func() {
			srv := &http.Server{Addr: cfg.MetricsAddr, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
			log.Info("metrics server listening", "addr", cfg.MetricsAddr)
			if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
				log.Warn("metrics server failed", "error", err)
			}
		}()
	}

	store := database.NewPaperStore(pool, log)
	service := ingestion.NewService(buildProviders(&cfg), store, database.NewRunLedger(pool), log)

	riverWorkers := river.NewWorkers()
	workers.AddAll(riverWorkers, service, log)

	clientOpts := &river.Config{
		Queues: map[string]river.QueueConfig{
			"ingestion": {MaxWorkers: cfg.WorkerConcurrency},
		},
		Workers: riverWorkers,
		// Backfill attempts legitimately run for many minutes (River's
		// default is 1m, which cancels the job context mid-page).
		JobTimeout: 15 * time.Minute,
	}
	if cfg.IngestionEnabled {
		clientOpts.PeriodicJobs = []*river.PeriodicJob{
			workers.PeriodicSyncWindow(openalexadapter.Slug, 6*time.Hour),
			workers.PeriodicSyncWindow(arxivadapter.Slug, 6*time.Hour),
		}
	}

	client, err := river.NewClient(riverpgxv5.New(pool), clientOpts)
	if err != nil {
		log.Error("river client creation failed", "error", err)
		os.Exit(1)
	}

	if !cfg.IngestionEnabled {
		log.Info("athena worker idle (ATHENA_INGESTION_ENABLED=false)",
			"concurrency", cfg.WorkerConcurrency)
	} else if err := client.Start(ctx); err != nil {
		log.Error("river client start failed", "error", err)
		os.Exit(1)
	} else {
		log.Info("athena worker started",
			"concurrency", cfg.WorkerConcurrency,
			"providers", service.ProviderSlugs())
	}

	<-ctx.Done()
	log.Info("shutdown signal received; draining jobs")
	drainCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	if err := client.Stop(drainCtx); err != nil {
		log.Warn("drain interrupted", "error", err)
	}
	log.Info("athena worker stopped")
}

func buildProviders(cfg *config.Config) ingestion.Providers {
	providers := ingestion.Providers{
		openalexadapter.Slug: openalexadapter.New(openalexadapter.Options{
			Mailto:  cfg.OpenAlexMailto,
			MaxRPS:  cfg.OpenAlexMaxRPS,
			BaseURL: cfg.OpenAlexBaseURL,
		}),
		arxivadapter.Slug: arxivadapter.New(arxivadapter.Options{
			UserAgent:   cfg.ArxivUserAgent,
			MinInterval: cfg.ArxivMinInterval,
			BaseURL:     cfg.ArxivBaseURL,
		}),
		s2adapter.Slug: s2adapter.New(s2adapter.Options{
			APIKey:  cfg.SemanticScholarAPIKey,
			MaxRPS:  cfg.S2MaxRPS,
			BaseURL: cfg.S2BaseURL,
		}),
	}
	return providers
}
