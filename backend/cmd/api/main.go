// Command api starts Athena's HTTP API server: research endpoints, admin
// ingestion triggers, platform probes, and Prometheus metrics.
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

	"github.com/riverqueue/river"
	riverpgxv5 "github.com/riverqueue/river/riverdriver/riverpgxv5"

	v1 "athena/backend/internal/delivery/http/v1"
	"athena/backend/internal/infrastructure/database"
	"athena/backend/internal/infrastructure/workers"
	"athena/backend/internal/platform/config"
	httpserver "athena/backend/internal/platform/httpserver"
	"athena/backend/internal/platform/logger"
)

func main() {
	if err := run(); err != nil {
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.FromEnv()
	if err != nil {
		logger.New("error", "").Error("invalid configuration", "error", err)
		return err
	}
	log := logger.New(cfg.LogLevel, cfg.LogFormat)
	slog.SetDefault(log)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	pool, err := database.Connect(ctx, cfg.DatabaseURL, cfg.DBMaxConns)
	if err != nil {
		log.Error("database connect failed", "error", err)
		return err
	}
	defer pool.Close()

	store := database.NewPaperStore(pool, log)

	// River client in insert-only mode: no queues configured means it never
	// works jobs itself; workers run in cmd/worker.
	riverClient, err := river.NewClient(riverpgxv5.New(pool), &river.Config{
		Logger: log,
	})
	if err != nil {
		log.Error("river client init failed", "error", err)
		return err
	}

	research := v1.NewResearchHandlers(store, log)
	admin := v1.NewAdminHandlers(cfg.AdminToken, log)
	admin.Queue = workers.NewQueueAdmin(riverClient)

	srv := &http.Server{
		Addr: cfg.HTTPAddr,
		Handler: httpserver.New(httpserver.Deps{
			Research: research,
			Admin:    admin,
			Logger:   log,
			Ping: func() error {
				cctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
				defer cancel()
				return pool.Ping(cctx)
			},
		}),
		ReadHeaderTimeout: 10 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() { errCh <- srv.ListenAndServe() }()

	log.Info("athena api starting",
		"addr", cfg.HTTPAddr, "env", cfg.AppEnv)

	select {
	case err := <-errCh:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("server failed", "error", err)
			return err
		}
	case <-ctx.Done():
		log.Info("shutdown signal received")
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Error("graceful shutdown failed", "error", err)
	}
	pool.Close()
	log.Info("athena api stopped")
	return nil
}
