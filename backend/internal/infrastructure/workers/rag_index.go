package workers

import (
	"context"
	"fmt"
	"log/slog"
	"strconv"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/riverqueue/river"

	appai "athena/backend/internal/application/ai"
)

// RagIndexKind is the River job type name for full-text RAG indexing.
const RagIndexKind = "rag_index_paper"

// RagIndexArgs carries one paper to extract/chunk/embed. Args hold
// parameters only — never payloads.
type RagIndexArgs struct {
	PaperID string `json:"paper_id"`
}

func (RagIndexArgs) Kind() string { return RagIndexKind }

// RagIndexWorker indexes one paper's open-access full text into RAG chunks.
type RagIndexWorker struct {
	river.WorkerDefaults[RagIndexArgs]

	Service *appai.RAGService
	Logger  *slog.Logger
}

func (w *RagIndexWorker) Work(ctx context.Context, job *river.Job[RagIndexArgs]) error {
	id, err := uuid.Parse(job.Args.PaperID)
	if err != nil {
		return fmt.Errorf("bad paper id %q: %w", job.Args.PaperID, err)
	}
	n, err := w.Service.IngestPaper(ctx, id)
	if err != nil {
		return fmt.Errorf("rag index paper %s: %w", id, err)
	}
	w.Logger.Info("rag index done", "paper_id", id, "chunks", n)
	return nil
}

// AddAI registers the Phase 4 job workers. Service may be nil when the AI
// layer is disabled; the worker is simply not registered then.
func AddAI(riverWorkers *river.Workers, rag *appai.RAGService, logger *slog.Logger) {
	if rag == nil {
		return
	}
	river.AddWorker(riverWorkers, &RagIndexWorker{Service: rag, Logger: logger})
}

// EnqueueRagIndex inserts one rag_index_paper job per paper id onto the ai
// queue (admin-triggered bulk indexing).
func EnqueueRagIndex(ctx context.Context, client *river.Client[pgx.Tx], paperIDs []string) ([]string, error) {
	if len(paperIDs) == 0 || len(paperIDs) > 100 {
		return nil, fmt.Errorf("paper_ids must contain 1..100 ids")
	}
	jobIDs := make([]string, 0, len(paperIDs))
	for _, raw := range paperIDs {
		id, err := uuid.Parse(strings.TrimSpace(raw))
		if err != nil {
			return jobIDs, fmt.Errorf("bad paper id %q: %w", raw, err)
		}
		res, err := client.Insert(ctx, RagIndexArgs{PaperID: id.String()}, &river.InsertOpts{
			Queue:       "ai",
			MaxAttempts: 3,
		})
		if err != nil {
			return jobIDs, fmt.Errorf("insert rag index job: %w", err)
		}
		jobIDs = append(jobIDs, strconv.FormatInt(res.Job.ID, 10))
	}
	return jobIDs, nil
}
