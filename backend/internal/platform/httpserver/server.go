// Package httpserver assembles the production HTTP server: route wiring,
// platform endpoints (/healthz, /readyz, /metrics), and the standard
// middleware chain.
package httpserver

import (
	"log/slog"
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"

	v1 "athena/backend/internal/delivery/http/v1"
)

// Deps carries everything the server needs from the composition root.
type Deps struct {
	Research  *v1.ResearchHandlers
	Search    *v1.SearchHandlers
	Feed      *v1.FeedHandlers
	Topics    *v1.TopicsHandlers
	Admin     *v1.AdminHandlers
	AI        *v1.AIHandlers
	Auth      *v1.AuthHandlers
	Bookmarks     *v1.BookmarksHandlers
	Follows       *v1.FollowsHandlers
	Notifications *v1.NotificationsHandlers
	Logger        *slog.Logger

	// Ping checks database connectivity for readiness probes.
	Ping func() error

	// RedisPing optionally verifies the cache backend (readyz).
	RedisPing func() error
}

// New builds the fully-wired http.Handler.
func New(deps Deps) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})

	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, _ *http.Request) {
		if deps.Ping == nil || deps.Ping() != nil ||
			(deps.RedisPing != nil && deps.RedisPing() != nil) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte(`{"status":"unavailable"}`))
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ready"}`))
	})

	mux.Handle("GET /metrics", promhttp.Handler())

	registerAPI(mux, deps)

	var handler http.Handler = mux
	if deps.Auth != nil {
		handler = v1.WithAuth(deps.Auth.Svc, deps.Logger, handler)
	}

	log := deps.Logger
	if log == nil {
		log = slog.Default()
	}
	return v1.WithRequestID(v1.WithLogging(log, v1.Recover(log, handler)))
}

func registerAPI(mux *http.ServeMux, deps Deps) {
	if deps.Research != nil {
		mux.HandleFunc("GET /api/v1/research/papers", deps.Research.List)
		mux.HandleFunc("GET /api/v1/research/papers/{id}", deps.Research.Get)
		mux.HandleFunc("GET /api/v1/research/papers/{id}/citations", deps.Research.Citations)
		mux.HandleFunc("GET /api/v1/research/papers/{id}/related", deps.Research.Related)
	}
	if deps.AI != nil {
		if deps.AI.Summary != nil {
			mux.HandleFunc("POST /api/v1/research/papers/{id}/summary", deps.AI.SummaryPost)
			mux.HandleFunc("GET /api/v1/research/papers/{id}/reader", deps.AI.ReaderGet)
		}
		if deps.AI.Chat != nil {
			mux.HandleFunc("POST /api/v1/chat/sessions", deps.AI.CreateSession)
			mux.HandleFunc("GET /api/v1/chat/sessions/{id}/messages", deps.AI.ListMessages)
			mux.HandleFunc("POST /api/v1/chat/sessions/{id}/messages", deps.AI.Ask)
		}
	}

	if deps.Search != nil {
		mux.HandleFunc("GET /api/v1/search", deps.Search.Get)
		mux.HandleFunc("GET /api/v1/search/live", deps.Search.GetLive)
	}
	if deps.Feed != nil {
		mux.HandleFunc("GET /api/v1/feed", deps.Feed.Get)
	}
	if deps.Topics != nil && deps.Research != nil {
		mux.HandleFunc("GET /api/v1/topics", deps.Topics.List)
		mux.HandleFunc("GET /api/v1/topics/{slug}", deps.Topics.Get)
		mux.HandleFunc("GET /api/v1/topics/{slug}/research", deps.Topics.ListResearch)
	}

	if deps.Auth != nil {
		mux.HandleFunc("POST /api/v1/auth/register", deps.Auth.Register)
		mux.HandleFunc("POST /api/v1/auth/login", deps.Auth.Login)
		mux.HandleFunc("POST /api/v1/auth/logout", deps.Auth.Logout)
		mux.HandleFunc("GET /api/v1/me", deps.Auth.Me)
	}

	if deps.Auth != nil && deps.Bookmarks != nil {
		mux.Handle("POST /api/v1/me/bookmarks", v1.RequireAuth(deps.Bookmarks.Add))
		mux.Handle("GET /api/v1/me/bookmarks", v1.RequireAuth(deps.Bookmarks.List))
		mux.Handle("DELETE /api/v1/me/bookmarks/{paperId}", v1.RequireAuth(deps.Bookmarks.Remove))
	}

	if deps.Auth != nil && deps.Follows != nil {
		mux.Handle("POST /api/v1/me/follows/topics", v1.RequireAuth(deps.Follows.FollowTopic))
		mux.Handle("DELETE /api/v1/me/follows/topics/{slug}", v1.RequireAuth(deps.Follows.UnfollowTopic))
		mux.Handle("GET /api/v1/me/follows/topics", v1.RequireAuth(deps.Follows.ListFollowedTopics))
		mux.Handle("POST /api/v1/me/follows/authors", v1.RequireAuth(deps.Follows.FollowAuthor))
		mux.Handle("DELETE /api/v1/me/follows/authors/{authorId}", v1.RequireAuth(deps.Follows.UnfollowAuthor))
		mux.Handle("GET /api/v1/me/follows/authors", v1.RequireAuth(deps.Follows.ListFollowedAuthors))
	}

	if deps.Auth != nil && deps.Notifications != nil {
		mux.Handle("GET /api/v1/me/notifications", v1.RequireAuth(deps.Notifications.List))
		mux.Handle("POST /api/v1/me/notifications/{id}/read", v1.RequireAuth(deps.Notifications.MarkRead))
		mux.Handle("POST /api/v1/me/notifications/read-all", v1.RequireAuth(deps.Notifications.MarkAllRead))
		mux.Handle("GET /api/v1/me/notifications/unread-count", v1.RequireAuth(deps.Notifications.UnreadCount))
	}

	if deps.Admin != nil {
		mux.HandleFunc("POST /api/v1/admin/ingestion/jobs", deps.Admin.CreateIngestionJob)
		mux.HandleFunc("GET /api/v1/admin/ingestion/jobs", deps.Admin.ListIngestionJobs)
		mux.HandleFunc("POST /api/v1/admin/rag/index", deps.Admin.CreateRagIndexJobs)
	}
}
