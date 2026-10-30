// Package push implements push notification delivery adapters for Apple Push
// Notification service (APNs) and Firebase Cloud Messaging (FCM).
package push

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"time"

	domainnotif "athena/backend/internal/domain/notification"
)

// Config configures external push gateways.
type Config struct {
	Provider string // "noop", "logging", "mock", "fcm", "apns", "composite"

	// FCM settings
	FCMProjectID      string
	FCMServiceAccount string // Service account JSON payload or file path
	FCMBaseURL        string // Test URL override
	FCMTokenSource    TokenSource

	// APNs settings
	APNSKeyID      string
	APNSTeamID     string
	APNSTopic      string // Bundle identifier, e.g. "org.athena.research"
	APNSKeyPath    string
	APNSKeyBytes   []byte
	APNSProduction bool
	APNSBaseURL    string // Test URL override
	APNSTokenSource TokenSource
}

// TokenSource provides OAuth/JWT bearer tokens for push APIs.
type TokenSource interface {
	Token(ctx context.Context) (string, error)
}

// StaticToken implements TokenSource with a fixed bearer string.
type StaticToken string

func (s StaticToken) Token(_ context.Context) (string, error) {
	return string(s), nil
}

// New constructs a domainnotif.PushSender matching the supplied configuration.
func New(cfg Config, logger *slog.Logger) domainnotif.PushSender {
	if logger == nil {
		logger = slog.Default()
	}

	switch cfg.Provider {
	case "mock":
		return NewMockSender()
	case "logging":
		return &LoggingSender{Logger: logger}
	case "fcm":
		return NewFCMClient(cfg, logger)
	case "apns":
		return NewAPNSClient(cfg, logger)
	case "composite":
		return NewRouter(RouterConfig{
			FCM:      NewFCMClient(cfg, logger),
			APNS:     NewAPNSClient(cfg, logger),
			Fallback: &LoggingSender{Logger: logger},
			Logger:   logger,
		})
	default:
		// Default to NopSender in development / test when not explicitly configured.
		return &NopSender{}
	}
}

// NopSender silently discards push alerts.
type NopSender struct{}

func (n *NopSender) SendPush(_ context.Context, _ domainnotif.Device, _ domainnotif.Notification) error {
	return nil
}

// LoggingSender logs outbound pushes for development or diagnostics.
type LoggingSender struct {
	Logger *slog.Logger
}

func (l *LoggingSender) SendPush(_ context.Context, d domainnotif.Device, n domainnotif.Notification) error {
	if l.Logger != nil {
		l.Logger.Info("push alert dispatched",
			"user_id", d.UserID,
			"platform", d.Platform,
			"token", maskToken(d.Token),
			"type", n.Type,
			"title", n.Title,
		)
	}
	return nil
}

// MockSender records dispatched pushes in memory for testing.
type MockSender struct {
	mu        sync.Mutex
	Calls     []DispatchedPush
	FailWith  error
	UnregOn   map[string]bool
}

type DispatchedPush struct {
	Device       domainnotif.Device
	Notification domainnotif.Notification
	Timestamp    time.Time
}

func NewMockSender() *MockSender {
	return &MockSender{
		Calls:   make([]DispatchedPush, 0),
		UnregOn: make(map[string]bool),
	}
}

func (m *MockSender) SendPush(_ context.Context, d domainnotif.Device, n domainnotif.Notification) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.UnregOn != nil && m.UnregOn[d.Token] {
		return domainnotif.ErrDeviceUnregistered
	}
	if m.FailWith != nil {
		return m.FailWith
	}

	m.Calls = append(m.Calls, DispatchedPush{
		Device:       d,
		Notification: n,
		Timestamp:    time.Now(),
	})
	return nil
}

func (m *MockSender) Dispatched() []DispatchedPush {
	m.mu.Lock()
	defer m.mu.Unlock()
	res := make([]DispatchedPush, len(m.Calls))
	copy(res, m.Calls)
	return res
}

func (m *MockSender) Reset() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.Calls = m.Calls[:0]
	m.FailWith = nil
}

func maskToken(token string) string {
	if len(token) <= 8 {
		return "***"
	}
	return fmt.Sprintf("%s...%s", token[:4], token[len(token)-4:])
}
