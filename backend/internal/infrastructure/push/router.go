package push

import (
	"context"
	"log/slog"

	domainnotif "athena/backend/internal/domain/notification"
)

// RouterConfig holds destinations for multi-platform push dispatch.
type RouterConfig struct {
	FCM      domainnotif.PushSender
	APNS     domainnotif.PushSender
	Fallback domainnotif.PushSender
	Logger   *slog.Logger
}

// Router routes notifications to platform-specific push gateways.
type Router struct {
	fcm      domainnotif.PushSender
	apns     domainnotif.PushSender
	fallback domainnotif.PushSender
	logger   *slog.Logger
}

// NewRouter constructs a multi-platform push Router.
func NewRouter(cfg RouterConfig) *Router {
	fb := cfg.Fallback
	if fb == nil {
		fb = &NopSender{}
	}
	return &Router{
		fcm:      cfg.FCM,
		apns:     cfg.APNS,
		fallback: fb,
		logger:   cfg.Logger,
	}
}

// SendPush routes the push to the appropriate gateway matching the device's platform.
func (r *Router) SendPush(ctx context.Context, d domainnotif.Device, n domainnotif.Notification) error {
	switch d.Platform {
	case domainnotif.PlatformIOS:
		if r.apns != nil {
			return r.apns.SendPush(ctx, d, n)
		}
		// Many projects route iOS through FCM if APNs certs are attached to Firebase
		if r.fcm != nil {
			return r.fcm.SendPush(ctx, d, n)
		}
		return r.fallback.SendPush(ctx, d, n)

	case domainnotif.PlatformAndroid, domainnotif.PlatformWeb:
		if r.fcm != nil {
			return r.fcm.SendPush(ctx, d, n)
		}
		return r.fallback.SendPush(ctx, d, n)

	default:
		if r.fcm != nil {
			return r.fcm.SendPush(ctx, d, n)
		}
		return r.fallback.SendPush(ctx, d, n)
	}
}
