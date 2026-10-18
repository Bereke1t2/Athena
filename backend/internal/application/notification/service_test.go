package notification_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	appnotif "athena/backend/internal/application/notification"
	domainnotif "athena/backend/internal/domain/notification"
)

type mockNotifStore struct {
	items []domainnotif.Notification
}

func newMockNotifStore() *mockNotifStore {
	return &mockNotifStore{items: make([]domainnotif.Notification, 0)}
}

func (m *mockNotifStore) Create(ctx context.Context, n domainnotif.Notification) (domainnotif.Notification, error) {
	n.ID = uuid.New()
	n.CreatedAt = time.Now().UTC()
	m.items = append(m.items, n)
	return n, nil
}

func (m *mockNotifStore) List(ctx context.Context, userID uuid.UUID, unreadOnly bool, cursor string, limit int) ([]domainnotif.Notification, string, error) {
	out := make([]domainnotif.Notification, 0)
	for _, it := range m.items {
		if it.UserID == userID {
			if unreadOnly && it.ReadAt != nil {
				continue
			}
			out = append(out, it)
		}
	}
	return out, "", nil
}

func (m *mockNotifStore) MarkAsRead(ctx context.Context, userID, notificationID uuid.UUID) error {
	for i, it := range m.items {
		if it.UserID == userID && it.ID == notificationID {
			now := time.Now().UTC()
			m.items[i].ReadAt = &now
			return nil
		}
	}
	return domainnotif.ErrNotFound
}

func (m *mockNotifStore) MarkAllAsRead(ctx context.Context, userID uuid.UUID) error {
	now := time.Now().UTC()
	for i, it := range m.items {
		if it.UserID == userID && it.ReadAt == nil {
			m.items[i].ReadAt = &now
		}
	}
	return nil
}

func (m *mockNotifStore) UnreadCount(ctx context.Context, userID uuid.UUID) (int, error) {
	count := 0
	for _, it := range m.items {
		if it.UserID == userID && it.ReadAt == nil {
			count++
		}
	}
	return count, nil
}

func TestNotificationService(t *testing.T) {
	ctx := context.Background()
	store := newMockNotifStore()
	svc := appnotif.NewService(store)
	userID := uuid.New()

	// Validation
	if _, err := svc.Create(ctx, domainnotif.Notification{UserID: uuid.Nil}); !errors.Is(err, domainnotif.ErrInvalidInput) {
		t.Fatalf("expected ErrInvalidInput for nil user_id, got %v", err)
	}
	if _, err := svc.Create(ctx, domainnotif.Notification{UserID: userID, Title: ""}); !errors.Is(err, domainnotif.ErrInvalidInput) {
		t.Fatalf("expected ErrInvalidInput for empty title, got %v", err)
	}

	// Create
	n, err := svc.Create(ctx, domainnotif.Notification{
		UserID: userID,
		Title:  "Test notification",
		Body:   "Details here",
		Type:   domainnotif.TypeSystem,
	})
	if err != nil {
		t.Fatalf("Create failed: %v", err)
	}
	if n.ID == uuid.Nil {
		t.Fatal("expected assigned ID")
	}

	// Unread count
	count, err := svc.UnreadCount(ctx, userID)
	if err != nil || count != 1 {
		t.Fatalf("expected count 1, got %d, err: %v", count, err)
	}

	// List
	list, _, err := svc.List(ctx, userID, false, "", 20)
	if err != nil || len(list) != 1 {
		t.Fatalf("expected 1 item, got %d", len(list))
	}

	// Mark as read
	if err := svc.MarkAsRead(ctx, userID, n.ID); err != nil {
		t.Fatalf("MarkAsRead failed: %v", err)
	}

	countAfter, _ := svc.UnreadCount(ctx, userID)
	if countAfter != 0 {
		t.Fatalf("expected count 0 after mark read, got %d", countAfter)
	}

	// Fan out
	uids := []uuid.UUID{userID, uuid.New()}
	fanned, err := svc.FanOutTopicUpdate(ctx, uids, "nlp", "Natural Language Processing", "Attention is all you need", uuid.New())
	if err != nil || len(fanned) != 2 {
		t.Fatalf("FanOutTopicUpdate failed: %v", err)
	}

	// Mark all read
	if err := svc.MarkAllAsRead(ctx, userID); err != nil {
		t.Fatalf("MarkAllAsRead failed: %v", err)
	}
}
