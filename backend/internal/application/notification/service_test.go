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

type mockDeviceStore struct {
	devices map[uuid.UUID][]domainnotif.Device
}

func (m *mockDeviceStore) RegisterDevice(ctx context.Context, d domainnotif.Device) error {
	m.devices[d.UserID] = append(m.devices[d.UserID], d)
	return nil
}

func (m *mockDeviceStore) UnregisterDevice(ctx context.Context, userID uuid.UUID, token string) error {
	list := m.devices[userID]
	out := make([]domainnotif.Device, 0, len(list))
	for _, d := range list {
		if d.Token != token {
			out = append(out, d)
		}
	}
	m.devices[userID] = out
	return nil
}

func (m *mockDeviceStore) ListDevicesByUser(ctx context.Context, userID uuid.UUID) ([]domainnotif.Device, error) {
	return m.devices[userID], nil
}

func TestDeviceManagement(t *testing.T) {
	ctx := context.Background()
	store := newMockNotifStore()
	devStore := &mockDeviceStore{devices: make(map[uuid.UUID][]domainnotif.Device)}
	svc := appnotif.NewService(store).WithDevices(devStore, nil)
	userID := uuid.New()

	// 1. Invalid input validation
	if err := svc.RegisterDevice(ctx, uuid.Nil, "tok", "ios", "iPhone"); !errors.Is(err, domainnotif.ErrInvalidInput) {
		t.Fatalf("expected ErrInvalidInput for nil user_id, got %v", err)
	}
	if err := svc.RegisterDevice(ctx, userID, "", "ios", "iPhone"); !errors.Is(err, domainnotif.ErrInvalidInput) {
		t.Fatalf("expected ErrInvalidInput for empty token, got %v", err)
	}
	if err := svc.RegisterDevice(ctx, userID, "tok", "badplatform", "iPhone"); !errors.Is(err, domainnotif.ErrInvalidInput) {
		t.Fatalf("expected ErrInvalidInput for bad platform, got %v", err)
	}

	// 2. Register valid devices
	if err := svc.RegisterDevice(ctx, userID, "token-ios", "ios", "iPhone 16"); err != nil {
		t.Fatalf("register ios device failed: %v", err)
	}
	if err := svc.RegisterDevice(ctx, userID, "token-web", "web", "Chrome"); err != nil {
		t.Fatalf("register web device failed: %v", err)
	}

	// 3. List devices
	devices, err := svc.ListDevices(ctx, userID)
	if err != nil || len(devices) != 2 {
		t.Fatalf("expected 2 devices, got %d (err: %v)", len(devices), err)
	}

	// 4. Unregister device
	if err := svc.UnregisterDevice(ctx, userID, "token-ios"); err != nil {
		t.Fatalf("unregister device failed: %v", err)
	}
	devicesAfter, err := svc.ListDevices(ctx, userID)
	if err != nil || len(devicesAfter) != 1 {
		t.Fatalf("expected 1 device after unregister, got %d", len(devicesAfter))
	}
	if devicesAfter[0].Token != "token-web" {
		t.Errorf("expected token-web to remain, got %s", devicesAfter[0].Token)
	}
}

type mockPushSender struct {
	dispatched []domainnotif.Notification
	failOn     map[string]error
}

func (m *mockPushSender) SendPush(_ context.Context, d domainnotif.Device, n domainnotif.Notification) error {
	if m.failOn != nil && m.failOn[d.Token] != nil {
		return m.failOn[d.Token]
	}
	m.dispatched = append(m.dispatched, n)
	return nil
}

func TestNotificationService_PushDispatchAndAutoUnregister(t *testing.T) {
	ctx := context.Background()
	store := newMockNotifStore()
	devStore := &mockDeviceStore{devices: make(map[uuid.UUID][]domainnotif.Device)}
	pushSender := &mockPushSender{
		failOn: map[string]error{
			"stale-token": domainnotif.ErrDeviceUnregistered,
		},
	}
	svc := appnotif.NewService(store).WithDevices(devStore, pushSender)
	userID := uuid.New()

	// Register 2 devices: one valid, one stale
	_ = svc.RegisterDevice(ctx, userID, "valid-token", "android", "Pixel 9")
	_ = svc.RegisterDevice(ctx, userID, "stale-token", "ios", "iPhone 15")

	// Create notification triggers push dispatch
	notif, err := svc.Create(ctx, domainnotif.Notification{
		UserID: userID,
		Title:  "Breaking Paper",
		Body:   "New discovery in quantum teleportation.",
	})
	if err != nil {
		t.Fatalf("Create failed: %v", err)
	}
	if notif.ID == uuid.Nil {
		t.Fatal("expected assigned notification ID")
	}

	// Verify push was dispatched to the valid device
	if len(pushSender.dispatched) != 1 {
		t.Fatalf("expected 1 successful push dispatch, got %d", len(pushSender.dispatched))
	}

	// Verify stale device was automatically unregistered
	devices, err := svc.ListDevices(ctx, userID)
	if err != nil {
		t.Fatalf("ListDevices failed: %v", err)
	}
	if len(devices) != 1 {
		t.Fatalf("expected 1 remaining device, got %d", len(devices))
	}
	if devices[0].Token != "valid-token" {
		t.Errorf("expected valid-token to remain, got %s", devices[0].Token)
	}
}
