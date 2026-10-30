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

// APNSClient sends push messages using the Apple Push Notification service.
type APNSClient struct {
	BaseURL     string
	Topic       string
	TokenSource TokenSource
	HTTPClient  *http.Client
	Logger      *slog.Logger
}

// NewAPNSClient constructs a new APNSClient.
func NewAPNSClient(cfg Config, logger *slog.Logger) *APNSClient {
	baseURL := cfg.APNSBaseURL
	if baseURL == "" {
		if cfg.APNSProduction {
			baseURL = "https://api.push.apple.com"
		} else {
			baseURL = "https://api.sandbox.push.apple.com"
		}
	}
	baseURL = strings.TrimSuffix(baseURL, "/")

	topic := cfg.APNSTopic
	if topic == "" {
		topic = "org.athena.research"
	}

	return &APNSClient{
		BaseURL:     baseURL,
		Topic:       topic,
		TokenSource: cfg.APNSTokenSource,
		HTTPClient:  &http.Client{Timeout: 10 * time.Second},
		Logger:      logger,
	}
}

type apnsPayload struct {
	Aps  apnsApsFields          `json:"aps"`
	Data map[string]any         `json:"data,omitempty"`
}

type apnsApsFields struct {
	Alert apnsAlert `json:"alert"`
	Sound string    `json:"sound"`
	Badge int       `json:"badge,omitempty"`
}

type apnsAlert struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type apnsErrorResponse struct {
	Reason    string `json:"reason"`
	Timestamp int64  `json:"timestamp,omitempty"`
}

// SendPush sends a notification to an iOS device token via APNs HTTP/2.
func (c *APNSClient) SendPush(ctx context.Context, d domainnotif.Device, n domainnotif.Notification) error {
	if c.BaseURL == "" {
		if c.Logger != nil {
			c.Logger.Debug("apns push skipped: no base URL configured", "user_id", d.UserID)
		}
		return nil
	}

	url := fmt.Sprintf("%s/3/device/%s", c.BaseURL, d.Token)

	customData := make(map[string]any)
	customData["notification_id"] = n.ID.String()
	customData["type"] = string(n.Type)
	for k, v := range n.Data {
		customData[k] = v
	}

	payload := apnsPayload{
		Aps: apnsApsFields{
			Alert: apnsAlert{
				Title: n.Title,
				Body:  n.Body,
			},
			Sound: "default",
			Badge: 1,
		},
		Data: customData,
	}

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal apns payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
	if err != nil {
		return fmt.Errorf("create apns request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("apns-topic", c.Topic)
	req.Header.Set("apns-push-type", "alert")
	req.Header.Set("apns-priority", "10")

	if c.TokenSource != nil {
		token, err := c.TokenSource.Token(ctx)
		if err != nil {
			return fmt.Errorf("acquire apns auth token: %w", err)
		}
		if token != "" {
			req.Header.Set("authorization", "bearer "+token)
		}
	}

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return fmt.Errorf("execute apns request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		return nil
	}

	respBody, _ := io.ReadAll(resp.Body)
	var errResp apnsErrorResponse
	_ = json.Unmarshal(respBody, &errResp)

	if resp.StatusCode == http.StatusGone || // 410 Unregistered
		errResp.Reason == "Unregistered" ||
		errResp.Reason == "BadDeviceToken" ||
		errResp.Reason == "DeviceTokenNotForTopic" {
		return domainnotif.ErrDeviceUnregistered
	}

	return fmt.Errorf("apns api error (status %d): %s (reason: %s)", resp.StatusCode, string(respBody), errResp.Reason)
}
