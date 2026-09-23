package workers

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"

	domainnotif "athena/backend/internal/domain/notification"
	"athena/backend/internal/infrastructure/database"
)

const NotificationFanoutKind = "notification_fanout"

type NotificationFanoutArgs struct {
	PaperID string `json:"paper_id"`
}

func (NotificationFanoutArgs) Kind() string { return NotificationFanoutKind }

type NotificationFanoutWorker struct {
	river.WorkerDefaults[NotificationFanoutArgs]

	Pool   *pgxpool.Pool
	Logger *slog.Logger
}

func (w *NotificationFanoutWorker) Work(ctx context.Context, job *river.Job[NotificationFanoutArgs]) error {
	paperID, err := uuid.Parse(job.Args.PaperID)
	if err != nil {
		return fmt.Errorf("bad paper id: %w", err)
	}

	notifStore := database.NewNotificationStore(w.Pool)

	// 1. Fanout for followed topics
	rows, err := w.Pool.Query(ctx, `
		SELECT ut.user_id, t.name, p.title
		FROM paper_topics pt
		JOIN topics t ON t.id = pt.topic_id
		JOIN user_topics ut ON ut.topic_id = t.id AND ut.notify = true
		JOIN papers p ON p.id = pt.paper_id
		WHERE pt.paper_id = $1`, paperID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var userID uuid.UUID
			var topicName, paperTitle string
			if err := rows.Scan(&userID, &topicName, &paperTitle); err == nil {
				_, _ = notifStore.Create(ctx, domainnotif.Notification{
					UserID: userID,
					Type:   domainnotif.TypeNewPapersTopic,
					Title:  fmt.Sprintf("New paper in %s", topicName),
					Body:   paperTitle,
					Data: map[string]any{
						"paper_id":   paperID.String(),
						"topic_name": topicName,
					},
				})
			}
		}
	}

	// 2. Fanout for followed authors
	authorRows, err := w.Pool.Query(ctx, `
		SELECT ua.user_id, a.display_name, p.title
		FROM paper_authors pa
		JOIN authors a ON a.id = pa.author_id
		JOIN user_authors ua ON ua.author_id = a.id
		JOIN papers p ON p.id = pa.paper_id
		WHERE pa.paper_id = $1`, paperID)
	if err == nil {
		defer authorRows.Close()
		for authorRows.Next() {
			var userID uuid.UUID
			var authorName, paperTitle string
			if err := authorRows.Scan(&userID, &authorName, &paperTitle); err == nil {
				_, _ = notifStore.Create(ctx, domainnotif.Notification{
					UserID: userID,
					Type:   domainnotif.TypeNewPapersAuthor,
					Title:  fmt.Sprintf("New paper by %s", authorName),
					Body:   paperTitle,
					Data: map[string]any{
						"paper_id":    paperID.String(),
						"author_name": authorName,
					},
				})
			}
		}
	}

	return nil
}

// AddNotifications registers the notification fan-out worker.
func AddNotifications(riverWorkers *river.Workers, pool *pgxpool.Pool, logger *slog.Logger) {
	if pool == nil {
		return
	}
	river.AddWorker(riverWorkers, &NotificationFanoutWorker{Pool: pool, Logger: logger})
}
