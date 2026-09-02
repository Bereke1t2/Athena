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

	"github.com/jackc/pgx/v5"
	"github.com/riverqueue/river"
	riverpgxv5 "github.com/riverqueue/river/riverdriver/riverpgxv5"

	appauth "athena/backend/internal/application/auth"
	appbookmark "athena/backend/internal/application/bookmark"
	appexport "athena/backend/internal/application/export"
	appdigest "athena/backend/internal/application/digest"
	appfeed "athena/backend/internal/application/feed"
	appfollow "athena/backend/internal/application/follow"
	appnotif "athena/backend/internal/application/notification"
	appsearch "athena/backend/internal/application/search"
	v1 "athena/backend/internal/delivery/http/v1"
	"athena/backend/internal/infrastructure/cache"
	"athena/backend/internal/infrastructure/database"
	"athena/backend/internal/infrastructure/providers/arxiv"
	"athena/backend/internal/infrastructure/providers/crossref"
	"athena/backend/internal/infrastructure/providers/openalex"
	"athena/backend/internal/infrastructure/providers/semanticscholar"
	"athena/backend/internal/infrastructure/workers"

	appai "athena/backend/internal/application/ai"
	appchat "athena/backend/internal/application/chat"
	discover "athena/backend/internal/application/discover"
	domainai "athena/backend/internal/domain/ai"
	"athena/backend/internal/infrastructure/ai/openaicompat"
	stubai "athena/backend/internal/infrastructure/ai/stub"
	authinfra "athena/backend/internal/infrastructure/auth"
	"athena/backend/internal/infrastructure/textextract"
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
	if cfg.AIEnabled() {
		admin.RagQueue = ragQueueAdapter{client: riverClient}
	}

	// Phase 2 discovery: FTS engine + optional Redis response cache.
	engine := database.NewPgSearcher(pool)
	var searchCache *cache.Cache
	if cfg.RedisAddr != "" {
		searchCache = cache.New(cfg.RedisAddr)
	}
	searchSvc := appsearch.NewService(engine, searchCache)

	// Live federated search across every configured research provider.
	liveProviders := []discover.ProviderSearcher{
		arxiv.New(arxiv.Options{UserAgent: cfg.ArxivUserAgent}),
		semanticscholar.New(semanticscholar.Options{APIKey: cfg.SemanticScholarAPIKey}),
		openalex.New(openalex.Options{Mailto: cfg.OpenAlexMailto}),
		crossref.New(crossref.Options{Mailto: cfg.OpenAlexMailto}),
	}
	discoverSvc := discover.NewService(liveProviders, store, searchCache, log)

	feedSvc := appfeed.NewService(store) // PaperStore satisfies feed.Source
	topics := v1.NewTopicsHandlers(database.NewTopicReader(pool), research, log)

	// Phase 5 auth: password accounts with opaque bearer sessions. The user
	// store implements both the account and session ports.
	userStore := database.NewUserStore(pool)
	authSvc := appauth.NewService(userStore, userStore, authinfra.NewHasher())
	authHandlers := v1.NewAuthHandlers(authSvc, log)

	// Phase 5 bookmarks: server-side saved papers (auth-guarded routes).
	bookmarkHandlers := v1.NewBookmarksHandlers(
		appbookmark.NewService(database.NewBookmarkStore(pool)), log)

	// Phase 5 follows: topics and authors subscriptions.
	followStore := database.NewFollowStore(pool)
	followHandlers := v1.NewFollowsHandlers(
		appfollow.NewService(followStore), log)

	// Phase 5 notifications: user in-app alerts and updates.
	notifHandlers := v1.NewNotificationsHandlers(
		appnotif.NewService(database.NewNotificationStore(pool)), log)

	// Phase 4 AI layer: only wired when an LLM provider is configured.
	var aiHandlers *v1.AIHandlers
	if cfg.AIEnabled() {
		aiStore := database.NewAIStore(pool)
		paperStore := database.NewPaperStore(pool, log)

		var llm domainai.LLMProvider
		switch cfg.LLMProvider {
		case "stub":
			llm = stubai.New()
		default:
			base := cfg.LLMBaseURL
			if cfg.LLMOverrideBaseURL != "" {
				base = cfg.LLMOverrideBaseURL
			}
			llm = openaicompat.NewClient(openaicompat.Config{
				BaseURL: base, APIKey: cfg.LLMAPIKey, Model: cfg.LLMModel,
				Timeout: 90 * time.Second,
			})
		}

		var embedder domainai.EmbeddingProvider
		if cfg.EmbeddingProviderName == "openai_compatible" {
			embedder = openaicompat.NewEmbedder(openaicompat.Config{
				BaseURL: cfg.LLMBaseURL, APIKey: cfg.LLMAPIKey,
				Model: cfg.EmbeddingModel,
			})
		} else {
			embedder = stubai.NewEmbedder(cfg.EmbeddingDim)
		}

		extractor := textextract.New()
		rag := appai.NewRAGService(paperStore, aiStore, extractor, embedder,
			appai.HTTPFetcher{}, log)
		retrieval := appai.NewRetrievalService(embedder, aiStore)
		retrieval.Logger = log
		summarySvc := appai.NewSummaryService(llm, aiStore, paperStore, aiStore, log)
		summarySvc.Indexer = rag
		chatSvc := appchat.NewService(llm, aiStore, retrieval, paperStore, log)
		chatSvc.Indexer = rag

		aiHandlers = v1.NewAIHandlers(summarySvc, chatSvc, log)
		aiHandlers.Comparison = appai.NewComparisonService(llm, paperStore, aiStore, log)
		if cfg.LLMProvider != "stub" && cfg.LLMAPIKey == "" {
			log.Warn("LLM_API_KEY is empty; AI requests are sent unauthenticated and will likely fail")
		}
		log.Info("ai layer enabled", "llm", cfg.LLMProvider, "model", cfg.LLMModel,
			"embeddings", embedder.Model())
	} else {
		log.Info("ai layer disabled (set LLM_PROVIDER to enable)")
	}

	exportHandlers := v1.NewExportHandlers(appexport.NewService(store), log)
	digestHandlers := v1.NewDigestHandlers(appdigest.NewService(store, followStore, nil, log), log)

	srv := &http.Server{
		Addr: cfg.HTTPAddr,
		Handler: httpserver.New(httpserver.Deps{
			Research: research,
			Search:   v1.NewSearchHandlersWithLive(searchSvc, discoverSvc, log), Feed: v1.NewFeedHandlers(feedSvc, log),
			Topics:    topics,
			Admin:         admin,
			AI:            aiHandlers,
			Auth:          authHandlers,
			Bookmarks:     bookmarkHandlers,
			Follows:       followHandlers,
			Notifications: notifHandlers,
			Export:        exportHandlers,
			Digest:        digestHandlers,
			Logger:        log,
			Ping: func() error {
				cctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
				defer cancel()
				return pool.Ping(cctx)
			},
			RedisPing: func() error {
				if searchCache == nil {
					return nil
				}
				cctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
				defer cancel()
				return searchCache.Ping(cctx)
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

// ragQueueAdapter adapts the River client to the admin RAG-index queue port.
type ragQueueAdapter struct {
	client *river.Client[pgx.Tx]
}

func (a ragQueueAdapter) EnqueueRagIndex(ctx context.Context, paperIDs []string) ([]string, error) {
	return workers.EnqueueRagIndex(ctx, a.client, paperIDs)
}
