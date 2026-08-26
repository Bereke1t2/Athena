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
	Research *v1.ResearchHandlers
	Admin    *v1.AdminHandlers
	Logger   *slog.Logger

	// Ping checks database connectivity for readiness probes.
	Ping func() error
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
		if deps.Ping == nil || deps.Ping() != nil {
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

	if deps.Admin != nil {
		mux.HandleFunc("POST /api/v1/admin/ingestion/jobs", deps.Admin.CreateIngestionJob)
		mux.HandleFunc("GET /api/v1/admin/ingestion/jobs", deps.Admin.ListIngestionJobs)
	}
}
