package workers

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"

	appdigest "athena/backend/internal/application/digest"
	domaindigest "athena/backend/internal/domain/digest"
	domainnotif "athena/backend/internal/domain/notification"
	domainuser "athena/backend/internal/domain/user"
	"athena/backend/internal/infrastructure/database"
	"athena/backend/internal/infrastructure/mail"
)

// WeeklyDigestKind is the River job type for periodic digest generation.
const WeeklyDigestKind = "weekly_digest"

type WeeklyDigestArgs struct {
	UserID string `json:"user_id,omitempty"` // optional single-user run; empty runs batch
}

func (WeeklyDigestArgs) Kind() string { return WeeklyDigestKind }

type WeeklyDigestWorker struct {
	river.WorkerDefaults[WeeklyDigestArgs]

	DigestService *appdigest.Service
	UserStore     domainuser.Store
	Mailer        mail.Sender
	AppBaseURL    string
	Pool          *pgxpool.Pool
	Logger        *slog.Logger
}

func (w *WeeklyDigestWorker) Work(ctx context.Context, job *river.Job[WeeklyDigestArgs]) error {
	notifStore := database.NewNotificationStore(w.Pool)

	if job.Args.UserID != "" {
		userID, err := uuid.Parse(job.Args.UserID)
		if err != nil {
			return fmt.Errorf("bad user id: %w", err)
		}
		return w.processUser(ctx, userID, notifStore)
	}

	// Batch: Process active users with followed topics or bookmarks
	rows, err := w.Pool.Query(ctx, `
		SELECT DISTINCT id FROM users
		WHERE deleted_at IS NULL
		LIMIT 200`)
	if err != nil {
		return fmt.Errorf("query users for digest: %w", err)
	}
	defer rows.Close()

	var userIDs []uuid.UUID
	for rows.Next() {
		var uid uuid.UUID
		if err := rows.Scan(&uid); err == nil {
			userIDs = append(userIDs, uid)
		}
	}
	if err := rows.Err(); err != nil {
		return err
	}

	for _, uid := range userIDs {
		if err := w.processUser(ctx, uid, notifStore); err != nil {
			w.Logger.Warn("digest generation failed for user", "user_id", uid, "error", err)
		}
	}

	return nil
}

func (w *WeeklyDigestWorker) processUser(ctx context.Context, userID uuid.UUID, notifStore *database.NotificationStore) error {
	if w.DigestService == nil {
		return nil
	}

	digest, err := w.DigestService.GenerateDigest(ctx, userID, domaindigest.FrequencyWeekly)
	if err != nil {
		return err
	}

	paperCount := 0
	for _, sec := range digest.Sections {
		paperCount += len(sec.Papers)
	}

	if paperCount == 0 {
		return nil
	}

	_, err = notifStore.Create(ctx, domainnotif.Notification{
		UserID: userID,
		Type:   domainnotif.TypeDigest,
		Title:  "Your Weekly Research Briefing",
		Body:   fmt.Sprintf("%d high-impact discoveries curated across your scientific interests.", paperCount),
		Data: map[string]any{
			"digest_id":   digest.ID.String(),
			"paper_count": paperCount,
		},
	})
	if err != nil {
		return err
	}

	if w.Mailer != nil && w.UserStore != nil {
		u, uerr := w.UserStore.ByID(ctx, userID)
		if uerr == nil && strings.TrimSpace(u.Email) != "" {
			subj, textBody, htmlBody, rerr := mail.RenderDigestEmail(u, digest, w.AppBaseURL)
			if rerr == nil {
				if merr := w.Mailer.Send(ctx, mail.Message{
					To:       u.Email,
					Subject:  subj,
					TextBody: textBody,
					HTMLBody: htmlBody,
				}); merr != nil {
					w.Logger.Warn("failed to send weekly digest email", "user_id", userID, "email", u.Email, "error", merr)
				} else {
					w.Logger.Info("sent weekly digest email", "user_id", userID, "email", u.Email)
				}
			}
		}
	}

	return nil
}

// AddDigest registers the weekly digest worker with River.
func AddDigest(riverWorkers *river.Workers, digestSvc *appdigest.Service, pool *pgxpool.Pool, logger *slog.Logger) {
	AddDigestWithMailer(riverWorkers, digestSvc, pool, nil, nil, "", logger)
}

// AddDigestWithMailer registers the weekly digest worker with River including email dispatch.
func AddDigestWithMailer(riverWorkers *river.Workers, digestSvc *appdigest.Service, pool *pgxpool.Pool, userStore domainuser.Store, mailer mail.Sender, appBaseURL string, logger *slog.Logger) {
	if pool == nil || digestSvc == nil {
		return
	}
	river.AddWorker(riverWorkers, &WeeklyDigestWorker{
		DigestService: digestSvc,
		Pool:          pool,
		UserStore:     userStore,
		Mailer:        mailer,
		AppBaseURL:    appBaseURL,
		Logger:        logger,
	})
}

// PeriodicWeeklyDigestConstructor returns the job arguments and insert options for weekly digests.
func PeriodicWeeklyDigestConstructor() (river.JobArgs, *river.InsertOpts) {
	return WeeklyDigestArgs{}, &river.InsertOpts{
		Queue: "notifications",
	}
}

// PeriodicWeeklyDigest schedules automated weekly research digest generation.
func PeriodicWeeklyDigest(every time.Duration) *river.PeriodicJob {
	return river.NewPeriodicJob(
		river.PeriodicInterval(every),
		func() (river.JobArgs, *river.InsertOpts) {
			return PeriodicWeeklyDigestConstructor()
		},
		&river.PeriodicJobOpts{RunOnStart: false},
	)
}
