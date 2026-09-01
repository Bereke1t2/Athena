package v1

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"

	appnotif "athena/backend/internal/application/notification"
	domainnotif "athena/backend/internal/domain/notification"
	domainuser "athena/backend/internal/domain/user"
)

type fakeNotifDeliveryStore struct {
	items map[uuid.UUID][]domainnotif.Notification
}

func newFakeNotifDeliveryStore() *fakeNotifDeliveryStore {
	return &fakeNotifDeliveryStore{items: make(map[uuid.UUID][]domainnotif.Notification)}
}

func (f *fakeNotifDeliveryStore) Create(ctx context.Context, n domainnotif.Notification) (domainnotif.Notification, error) {
	n.ID = uuid.New()
	n.CreatedAt = time.Now().UTC()
	f.items[n.UserID] = append(f.items[n.UserID], n)
	return n, nil
}

func (f *fakeNotifDeliveryStore) List(ctx context.Context, userID uuid.UUID, unreadOnly bool, cursor string, limit int) ([]domainnotif.Notification, string, error) {
	return f.items[userID], "", nil
}

func (f *fakeNotifDeliveryStore) MarkAsRead(ctx context.Context, userID, notificationID uuid.UUID) error {
	list := f.items[userID]
	for i, it := range list {
		if it.ID == notificationID {
			now := time.Now().UTC()
			list[i].ReadAt = &now
			return nil
		}
	}
	return domainnotif.ErrNotFound
}

func (f *fakeNotifDeliveryStore) MarkAllAsRead(ctx context.Context, userID uuid.UUID) error {
	now := time.Now().UTC()
	for i := range f.items[userID] {
		f.items[userID][i].ReadAt = &now
	}
	return nil
}

func (f *fakeNotifDeliveryStore) UnreadCount(ctx context.Context, userID uuid.UUID) (int, error) {
	c := 0
	for _, it := range f.items[userID] {
		if it.ReadAt == nil {
			c++
		}
	}
	return c, nil
}

func notifTestHandler() (*NotificationsHandlers, *fakeNotifDeliveryStore) {
	store := newFakeNotifDeliveryStore()
	return NewNotificationsHandlers(appnotif.NewService(store), testLogger()), store
}

func TestNotificationsRequireAuth(t *testing.T) {
	h, _ := notifTestHandler()

	w := httptest.NewRecorder()
	h.List(w, httptest.NewRequest(http.MethodGet, "/api/v1/me/notifications", nil))
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("anonymous list: %d", w.Code)
	}

	w = httptest.NewRecorder()
	h.UnreadCount(w, httptest.NewRequest(http.MethodGet, "/api/v1/me/notifications/unread-count", nil))
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("anonymous unread count: %d", w.Code)
	}
}

func TestNotificationsFlow(t *testing.T) {
	h, store := notifTestHandler()
	userID := uuid.New()
	userCtx := context.WithValue(context.Background(), userKey{}, domainuser.User{ID: userID})

	// Seed notification
	n, _ := store.Create(context.Background(), domainnotif.Notification{
		UserID: userID,
		Type:   domainnotif.TypeNewPapersTopic,
		Title:  "Fresh research",
		Body:   "New transformer architecture",
	})

	// Check unread count
	r1 := httptest.NewRequest(http.MethodGet, "/api/v1/me/notifications/unread-count", nil).WithContext(userCtx)
	w1 := httptest.NewRecorder()
	h.UnreadCount(w1, r1)
	if w1.Code != http.StatusOK {
		t.Fatalf("unread count code: %d", w1.Code)
	}
	var countResp unreadCountResponseDTO
	if err := json.Unmarshal(w1.Body.Bytes(), &countResp); err != nil || countResp.Count != 1 {
		t.Fatalf("expected count 1, got %d", countResp.Count)
	}

	// List notifications
	r2 := httptest.NewRequest(http.MethodGet, "/api/v1/me/notifications", nil).WithContext(userCtx)
	w2 := httptest.NewRecorder()
	h.List(w2, r2)
	if w2.Code != http.StatusOK {
		t.Fatalf("list code: %d", w2.Code)
	}
	var listResp notificationListResponseDTO
	if err := json.Unmarshal(w2.Body.Bytes(), &listResp); err != nil || len(listResp.Items) != 1 {
		t.Fatalf("expected 1 item, got %d", len(listResp.Items))
	}

	// Mark as read
	r3 := httptest.NewRequest(http.MethodPost, "/api/v1/me/notifications/"+n.ID.String()+"/read", nil).WithContext(userCtx)
	r3.SetPathValue("id", n.ID.String())
	w3 := httptest.NewRecorder()
	h.MarkRead(w3, r3)
	if w3.Code != http.StatusNoContent {
		t.Fatalf("mark read code: %d", w3.Code)
	}

	// Mark all read
	r4 := httptest.NewRequest(http.MethodPost, "/api/v1/me/notifications/read-all", nil).WithContext(userCtx)
	w4 := httptest.NewRecorder()
	h.MarkAllRead(w4, r4)
	if w4.Code != http.StatusNoContent {
		t.Fatalf("mark all read code: %d", w4.Code)
	}
}
