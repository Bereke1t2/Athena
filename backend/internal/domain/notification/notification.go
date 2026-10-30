// Package notification defines domain entities and persistence ports for user notifications.
package notification

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
)

var (
	// ErrNotFound is returned when a notification cannot be found.
	ErrNotFound = errors.New("notification: not found")
	// ErrInvalidInput marks malformed IDs or payloads.
	ErrInvalidInput = errors.New("notification: invalid input")
	// ErrDeviceUnregistered indicates the remote APNs/FCM service reported the token as expired or invalid.
	ErrDeviceUnregistered = errors.New("notification: device token unregistered")
)

// Type enumerates the categories of notifications.
type Type string

const (
	TypeNewPapersTopic  Type = "new_papers_topic"
	TypeNewPapersAuthor Type = "new_papers_author"
	TypeDigest          Type = "digest"
	TypeSystem          Type = "system"
)

// Notification represents an alert or in-app notice for a user.
type Notification struct {
	ID           uuid.UUID
	UserID       uuid.UUID
	Type         Type
	Title        string
	Body         string
	Data         map[string]any
	ReadAt       *time.Time
	DeliveredVia []string
	CreatedAt    time.Time
}

// IsRead returns true if the notification has been marked as read.
func (n Notification) IsRead() bool {
	return n.ReadAt != nil
}

// Store persists and queries notifications.
type Store interface {
	// Create persists a new notification record.
	Create(ctx context.Context, n Notification) (Notification, error)
	// List returns a page of notifications for a user, newest first.
	List(ctx context.Context, userID uuid.UUID, unreadOnly bool, cursor string, limit int) ([]Notification, string, error)
	// MarkAsRead marks a specific notification as read.
	MarkAsRead(ctx context.Context, userID, notificationID uuid.UUID) error
	// MarkAllAsRead marks all unread notifications for a user as read.
	MarkAllAsRead(ctx context.Context, userID uuid.UUID) error
	// UnreadCount returns the number of unread notifications for a user.
	UnreadCount(ctx context.Context, userID uuid.UUID) (int, error)
}

// Platform indicates client OS or environment for push routing.
type Platform string

const (
	PlatformIOS     Platform = "ios"
	PlatformAndroid Platform = "android"
	PlatformWeb     Platform = "web"
)

// Device represents a registered push notification destination.
type Device struct {
	ID         uuid.UUID
	UserID     uuid.UUID
	Token      string
	Platform   Platform
	DeviceName string
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

// DeviceStore persists and manages user device tokens.
type DeviceStore interface {
	RegisterDevice(ctx context.Context, d Device) error
	UnregisterDevice(ctx context.Context, userID uuid.UUID, token string) error
	ListDevicesByUser(ctx context.Context, userID uuid.UUID) ([]Device, error)
}

// PushSender abstracts pushing alerts to external APNs/FCM gateways.
type PushSender interface {
	SendPush(ctx context.Context, d Device, n Notification) error
}
