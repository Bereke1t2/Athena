package push

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	domainnotif "athena/backend/internal/domain/notification"
)

// FCMClient sends push messages using the Firebase Cloud Messaging HTTP v1 API.
type FCMClient struct {
	ProjectID   string
	BaseURL     string
	TokenSource TokenSource
	HTTPClient  *http.Client
	Logger      *slog.Logger
}

// NewFCMClient constructs a new FCMClient.
func NewFCMClient(cfg Config, logger *slog.Logger) *FCMClient {
	baseURL := cfg.FCMBaseURL
	if baseURL == "" && cfg.FCMProjectID != "" {
		baseURL = fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", cfg.FCMProjectID)
	}

	return &FCMClient{
		ProjectID:   cfg.FCMProjectID,
		BaseURL:     baseURL,
		TokenSource: cfg.FCMTokenSource,
		HTTPClient:  &http.Client{Timeout: 10 * time.Second},
		Logger:      logger,
	}
}

type fcmMessageEnvelope struct {
	Message fcmMessage `json:"message"`
}

type fcmMessage struct {
	Token        string                 `json:"token"`
	Notification *fcmNotification       `json:"notification,omitempty"`
	Data         map[string]string      `json:"data,omitempty"`
	Android      *fcmAndroidConfig      `json:"android,omitempty"`
	APNS         *fcmAPNSConfig         `json:"apns,omitempty"`
}

type fcmNotification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type fcmAndroidConfig struct {
	Priority     string                `json:"priority,omitempty"`
	Notification *fcmAndroidNotifConfig `json:"notification,omitempty"`
}

type fcmAndroidNotifConfig struct {
	Sound       string `json:"sound,omitempty"`
	ClickAction string `json:"click_action,omitempty"`
}

type fcmAPNSConfig struct {
	Payload map[string]any `json:"payload,omitempty"`
}

type fcmErrorResponse struct {
	Error struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Status  string `json:"status"`
		Details []struct {
			ErrorCode string `json:"errorCode"`
		} `json:"details"`
	} `json:"error"`
}

// SendPush sends a notification to a single device token via FCM HTTP v1.
func (c *FCMClient) SendPush(ctx context.Context, d domainnotif.Device, n domainnotif.Notification) error {
	if c.BaseURL == "" {
		if c.Logger != nil {
			c.Logger.Debug("fcm push skipped: no base URL or project ID configured", "user_id", d.UserID)
		}
		return nil
	}

	// Prepare data string map
	dataMap := make(map[string]string)
	dataMap["notification_id"] = n.ID.String()
	dataMap["type"] = string(n.Type)
	dataMap["click_action"] = "FLUTTER_NOTIFICATION_CLICK"
	for k, v := range n.Data {
		dataMap[k] = fmt.Sprintf("%v", v)
	}

	envelope := fcmMessageEnvelope{
		Message: fcmMessage{
			Token: d.Token,
			Notification: &fcmNotification{
				Title: n.Title,
				Body:  n.Body,
			},
			Data: dataMap,
			Android: &fcmAndroidConfig{
				Priority: "HIGH",
				Notification: &fcmAndroidNotifConfig{
					Sound:       "default",
					ClickAction: "FLUTTER_NOTIFICATION_CLICK",
				},
			},
			APNS: &fcmAPNSConfig{
				Payload: map[string]any{
					"aps": map[string]any{
						"sound": "default",
						"badge": 1,
					},
				},
			},
		},
	}

	bodyBytes, err := json.Marshal(envelope)
	if err != nil {
		return fmt.Errorf("marshal fcm payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.BaseURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return fmt.Errorf("create fcm request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	if c.TokenSource != nil {
		bearer, err := c.TokenSource.Token(ctx)
		if err != nil {
			return fmt.Errorf("acquire fcm auth token: %w", err)
		}
		if bearer != "" {
			req.Header.Set("Authorization", "Bearer "+bearer)
		}
	}

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return fmt.Errorf("execute fcm request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return nil
	}

	respBody, _ := io.ReadAll(resp.Body)
	var errResp fcmErrorResponse
	_ = json.Unmarshal(respBody, &errResp)

	// Check for unregistered / invalid token response
	if resp.StatusCode == http.StatusNotFound ||
		errResp.Error.Status == "NOT_FOUND" ||
		errResp.Error.Status == "UNREGISTERED" ||
		strings.Contains(errResp.Error.Message, "Requested entity was not found") ||
		strings.Contains(errResp.Error.Message, "UNREGISTERED") {
		return domainnotif.ErrDeviceUnregistered
	}

	for _, d := range errResp.Error.Details {
		if d.ErrorCode == "UNREGISTERED" {
			return domainnotif.ErrDeviceUnregistered
		}
	}

	return fmt.Errorf("fcm api error (status %d): %s", resp.StatusCode, string(respBody))
}
