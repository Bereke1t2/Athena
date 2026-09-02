package database

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	domainnotification "athena/backend/internal/domain/notification"
	"athena/backend/internal/domain/research"
)

// NotificationStore implements domain/notification.Store on Postgres.
type NotificationStore struct {
	pool *pgxpool.Pool
}

// NewNotificationStore constructs a notification store.
func NewNotificationStore(pool *pgxpool.Pool) *NotificationStore {
	return &NotificationStore{pool: pool}
}

// Create inserts a new notification record.
func (s *NotificationStore) Create(ctx context.Context, n domainnotification.Notification) (domainnotification.Notification, error) {
	if n.ID == uuid.Nil {
		n.ID = uuid.New()
	}
	if n.CreatedAt.IsZero() {
		n.CreatedAt = time.Now().UTC()
	}
	dataBytes, err := json.Marshal(n.Data)
	if err != nil {
		return n, fmt.Errorf("marshal notification data: %w", err)
	}

	_, err = s.pool.Exec(ctx, `
		INSERT INTO notifications (id, user_id, type, title, body, data, delivered_via, created_at)
		VALUES ($1, $2, $3::notification_type, $4, $5, $6, $7, $8)`,
		n.ID, n.UserID, string(n.Type), n.Title, n.Body, dataBytes, n.DeliveredVia, n.CreatedAt)
	if err != nil {
		return n, fmt.Errorf("create notification: %w", err)
	}
	return n, nil
}

type notifCursor struct {
	V       int       `json:"v"`
	Created time.Time `json:"t"`
	ID      uuid.UUID `json:"id"`
}

func encodeNotifCursor(c notifCursor) string {
	raw, _ := json.Marshal(c)
	return base64.RawURLEncoding.EncodeToString(raw)
}

func decodeNotifCursor(tok string) (notifCursor, error) {
	var c notifCursor
	raw, err := base64.RawURLEncoding.DecodeString(tok)
	if err != nil || json.Unmarshal(raw, &c) != nil || c.V != 1 {
		return c, fmt.Errorf("%w: malformed cursor", research.ErrInvalidInput)
	}
	return c, nil
}

// List returns a page of notifications, newest first.
func (s *NotificationStore) List(ctx context.Context, userID uuid.UUID, unreadOnly bool, cursor string, limit int) ([]domainnotification.Notification, string, error) {
	limit = min(max(limit, 1), 100)

	where := "user_id = $1"
	args := []any{userID}
	if unreadOnly {
		where += " AND read_at IS NULL"
	}
	if cursor != "" {
		c, err := decodeNotifCursor(cursor)
		if err != nil {
			return nil, "", err
		}
		where += fmt.Sprintf(" AND (created_at, id) < ($%d, $%d)", len(args)+1, len(args)+2)
		args = append(args, c.Created, c.ID)
	}
	limitArg := fmt.Sprintf("$%d", len(args)+1)

	rows, err := s.pool.Query(ctx, `
		SELECT id, user_id, type::text, title, COALESCE(body, ''), data, read_at, delivered_via, created_at
		FROM notifications
		WHERE `+where+`
		ORDER BY created_at DESC, id DESC
		LIMIT `+limitArg, append(args, limit+1)...)
	if err != nil {
		return nil, "", fmt.Errorf("list notifications: %w", err)
	}
	defer rows.Close()

	out := make([]domainnotification.Notification, 0, limit)
	var lastCreated time.Time
	var lastID uuid.UUID

	for rows.Next() {
		var n domainnotification.Notification
		var nType string
		var rawData []byte
		if err := rows.Scan(&n.ID, &n.UserID, &nType, &n.Title, &n.Body, &rawData, &n.ReadAt, &n.DeliveredVia, &n.CreatedAt); err != nil {
			return nil, "", fmt.Errorf("scan notification: %w", err)
		}
		n.Type = domainnotification.Type(nType)
		if len(rawData) > 0 {
			_ = json.Unmarshal(rawData, &n.Data)
		}
		out = append(out, n)
		lastCreated, lastID = n.CreatedAt, n.ID
	}
	if err := rows.Err(); err != nil {
		return nil, "", err
	}

	if len(out) > limit {
		out = out[:limit]
		next := encodeNotifCursor(notifCursor{V: 1, Created: lastCreated, ID: lastID})
		return out, next, nil
	}
	return out, "", nil
}

// MarkAsRead marks a notification as read.
func (s *NotificationStore) MarkAsRead(ctx context.Context, userID, notificationID uuid.UUID) error {
	ct, err := s.pool.Exec(ctx, `
		UPDATE notifications SET read_at = now()
		WHERE id = $1 AND user_id = $2 AND read_at IS NULL`,
		notificationID, userID)
	if err != nil {
		return fmt.Errorf("mark notification as read: %w", err)
	}
	if ct.RowsAffected() == 0 {
		var exists bool
		_ = s.pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM notifications WHERE id = $1 AND user_id = $2)", notificationID, userID).Scan(&exists)
		if !exists {
			return domainnotification.ErrNotFound
		}
	}
	return nil
}

// MarkAllAsRead marks all unread notifications for a user as read.
func (s *NotificationStore) MarkAllAsRead(ctx context.Context, userID uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE notifications SET read_at = now()
		WHERE user_id = $1 AND read_at IS NULL`,
		userID)
	if err != nil {
		return fmt.Errorf("mark all notifications as read: %w", err)
	}
	return nil
}

// UnreadCount returns the count of unread notifications.
func (s *NotificationStore) UnreadCount(ctx context.Context, userID uuid.UUID) (int, error) {
	var count int
	err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM notifications
		WHERE user_id = $1 AND read_at IS NULL`,
		userID).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("unread count: %w", err)
	}
	return count, nil
}
