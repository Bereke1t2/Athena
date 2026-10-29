// Package notification implements notification delivery and management use cases.
package notification

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"

	domainnotification "athena/backend/internal/domain/notification"
)

// Service coordinates user notifications.
type Service struct {
	store   domainnotification.Store
	devices domainnotification.DeviceStore
	push    domainnotification.PushSender
}

// NewService constructs a notification service.
func NewService(store domainnotification.Store) *Service {
	return &Service{store: store}
}

// WithDevices wires device token persistence and push delivery to the service.
func (s *Service) WithDevices(devices domainnotification.DeviceStore, push domainnotification.PushSender) *Service {
	s.devices = devices
	s.push = push
	return s
}

// Create inserts a new notification with validation and attempts push notification delivery.
func (s *Service) Create(ctx context.Context, n domainnotification.Notification) (domainnotification.Notification, error) {
	if n.UserID == uuid.Nil {
		return domainnotification.Notification{}, fmt.Errorf("%w: user_id is required", domainnotification.ErrInvalidInput)
	}
	if strings.TrimSpace(n.Title) == "" {
		return domainnotification.Notification{}, fmt.Errorf("%w: title is required", domainnotification.ErrInvalidInput)
	}
	if n.Type == "" {
		n.Type = domainnotification.TypeSystem
	}
	if n.DeliveredVia == nil {
		n.DeliveredVia = []string{"in_app"}
	}
	if n.Data == nil {
		n.Data = make(map[string]any)
	}
	created, err := s.store.Create(ctx, n)
	if err != nil {
		return created, err
	}

	if s.push != nil && s.devices != nil {
		if devices, err := s.devices.ListDevicesByUser(ctx, created.UserID); err == nil {
			for _, d := range devices {
				_ = s.push.SendPush(ctx, d, created)
			}
		}
	}

	return created, nil
}

// List returns a page of notifications for the user.
func (s *Service) List(ctx context.Context, userID uuid.UUID, unreadOnly bool, cursor string, limit int) ([]domainnotification.Notification, string, error) {
	if userID == uuid.Nil {
		return nil, "", fmt.Errorf("%w: user_id is required", domainnotification.ErrInvalidInput)
	}
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	return s.store.List(ctx, userID, unreadOnly, cursor, limit)
}

// MarkAsRead marks a notification as read.
func (s *Service) MarkAsRead(ctx context.Context, userID, notificationID uuid.UUID) error {
	if userID == uuid.Nil || notificationID == uuid.Nil {
		return fmt.Errorf("%w: user_id and notification_id are required", domainnotification.ErrInvalidInput)
	}
	return s.store.MarkAsRead(ctx, userID, notificationID)
}

// MarkAllAsRead marks all unread notifications for a user as read.
func (s *Service) MarkAllAsRead(ctx context.Context, userID uuid.UUID) error {
	if userID == uuid.Nil {
		return fmt.Errorf("%w: user_id is required", domainnotification.ErrInvalidInput)
	}
	return s.store.MarkAllAsRead(ctx, userID)
}

// UnreadCount returns the number of unread notifications for a user.
func (s *Service) UnreadCount(ctx context.Context, userID uuid.UUID) (int, error) {
	if userID == uuid.Nil {
		return 0, fmt.Errorf("%w: user_id is required", domainnotification.ErrInvalidInput)
	}
	return s.store.UnreadCount(ctx, userID)
}

// FanOutTopicUpdate delivers new paper notifications to all subscribers of a topic.
func (s *Service) FanOutTopicUpdate(ctx context.Context, userIDs []uuid.UUID, topicSlug, topicName, paperTitle string, paperID uuid.UUID) ([]domainnotification.Notification, error) {
	if len(userIDs) == 0 {
		return nil, nil
	}
	out := make([]domainnotification.Notification, 0, len(userIDs))
	for _, uid := range userIDs {
		n, err := s.Create(ctx, domainnotification.Notification{
			UserID: uid,
			Type:   domainnotification.TypeNewPapersTopic,
			Title:  fmt.Sprintf("New paper in %s", topicName),
			Body:   paperTitle,
			Data: map[string]any{
				"topic_slug": topicSlug,
				"paper_id":   paperID.String(),
			},
			DeliveredVia: []string{"in_app"},
		})
		if err != nil {
			return out, err
		}
		out = append(out, n)
	}
	return out, nil
}

// RegisterDevice registers a push token for a user.
func (s *Service) RegisterDevice(ctx context.Context, userID uuid.UUID, token, platform, deviceName string) error {
	if userID == uuid.Nil {
		return fmt.Errorf("%w: user_id is required", domainnotification.ErrInvalidInput)
	}
	token = strings.TrimSpace(token)
	if token == "" {
		return fmt.Errorf("%w: token is required", domainnotification.ErrInvalidInput)
	}
	platform = strings.ToLower(strings.TrimSpace(platform))
	switch domainnotification.Platform(platform) {
	case domainnotification.PlatformIOS, domainnotification.PlatformAndroid, domainnotification.PlatformWeb:
	default:
		return fmt.Errorf("%w: invalid platform %q (must be ios, android, or web)", domainnotification.ErrInvalidInput, platform)
	}
	if s.devices == nil {
		return nil
	}
	return s.devices.RegisterDevice(ctx, domainnotification.Device{
		UserID:     userID,
		Token:      token,
		Platform:   domainnotification.Platform(platform),
		DeviceName: strings.TrimSpace(deviceName),
	})
}

// UnregisterDevice removes a push token for a user.
func (s *Service) UnregisterDevice(ctx context.Context, userID uuid.UUID, token string) error {
	if userID == uuid.Nil {
		return fmt.Errorf("%w: user_id is required", domainnotification.ErrInvalidInput)
	}
	token = strings.TrimSpace(token)
	if token == "" {
		return fmt.Errorf("%w: token is required", domainnotification.ErrInvalidInput)
	}
	if s.devices == nil {
		return nil
	}
	return s.devices.UnregisterDevice(ctx, userID, token)
}

// ListDevices returns all devices registered to a user.
func (s *Service) ListDevices(ctx context.Context, userID uuid.UUID) ([]domainnotification.Device, error) {
	if userID == uuid.Nil {
		return nil, fmt.Errorf("%w: user_id is required", domainnotification.ErrInvalidInput)
	}
	if s.devices == nil {
		return nil, nil
	}
	return s.devices.ListDevicesByUser(ctx, userID)
}
