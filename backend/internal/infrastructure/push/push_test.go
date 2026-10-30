package push_test

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	domainnotif "athena/backend/internal/domain/notification"
	"athena/backend/internal/infrastructure/push"
)

func TestNopAndLoggingSender(t *testing.T) {
	ctx := context.Background()
	dev := domainnotif.Device{
		ID:       uuid.New(),
		UserID:   uuid.New(),
		Token:    "sample-device-token-123456",
		Platform: domainnotif.PlatformAndroid,
	}
	notif := domainnotif.Notification{
		ID:        uuid.New(),
		UserID:    dev.UserID,
		Type:      domainnotif.TypeNewPapersTopic,
		Title:     "New AI Breakthrough",
		Body:      "Deep learning scaling laws verified.",
		CreatedAt: time.Now(),
	}

	nop := &push.NopSender{}
	require.NoError(t, nop.SendPush(ctx, dev, notif))

	logging := &push.LoggingSender{}
	require.NoError(t, logging.SendPush(ctx, dev, notif))
}

func TestMockSender(t *testing.T) {
	ctx := context.Background()
	mock := push.NewMockSender()
	dev := domainnotif.Device{
		ID:       uuid.New(),
		UserID:   uuid.New(),
		Token:    "tok-1",
		Platform: domainnotif.PlatformIOS,
	}
	notif := domainnotif.Notification{
		ID:     uuid.New(),
		UserID: dev.UserID,
		Title:  "Test Notif",
	}

	require.NoError(t, mock.SendPush(ctx, dev, notif))
	dispatched := mock.Dispatched()
	require.Len(t, dispatched, 1)
	assert.Equal(t, "tok-1", dispatched[0].Device.Token)
	assert.Equal(t, "Test Notif", dispatched[0].Notification.Title)

	// Test unregister flag
	mock.UnregOn["tok-dead"] = true
	deadDev := domainnotif.Device{Token: "tok-dead"}
	err := mock.SendPush(ctx, deadDev, notif)
	assert.ErrorIs(t, err, domainnotif.ErrDeviceUnregistered)

	// Test reset
	mock.Reset()
	assert.Empty(t, mock.Dispatched())
}

func TestFCMClient_Success(t *testing.T) {
	var capturedReq map[string]any
	var authHeader string

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader = r.Header.Get("Authorization")
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &capturedReq)
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"name":"projects/test-proj/messages/msg-123"}`))
	}))
	defer srv.Close()

	client := push.NewFCMClient(push.Config{
		FCMBaseURL:     srv.URL,
		FCMTokenSource: push.StaticToken("mock-bearer-token"),
	}, nil)

	dev := domainnotif.Device{
		UserID:   uuid.New(),
		Token:    "fcm-device-token",
		Platform: domainnotif.PlatformAndroid,
	}
	notif := domainnotif.Notification{
		ID:    uuid.New(),
		Type:  domainnotif.TypeNewPapersTopic,
		Title: "Quantum Computing Paper",
		Body:  "Entanglement fidelity exceeded 99%.",
		Data: map[string]any{
			"paper_id": "019abc-123",
		},
	}

	err := client.SendPush(context.Background(), dev, notif)
	require.NoError(t, err)

	assert.Equal(t, "Bearer mock-bearer-token", authHeader)
	msg, ok := capturedReq["message"].(map[string]any)
	require.True(t, ok)
	assert.Equal(t, "fcm-device-token", msg["token"])

	notifPayload, ok := msg["notification"].(map[string]any)
	require.True(t, ok)
	assert.Equal(t, "Quantum Computing Paper", notifPayload["title"])
	assert.Equal(t, "Entanglement fidelity exceeded 99%.", notifPayload["body"])

	dataPayload, ok := msg["data"].(map[string]any)
	require.True(t, ok)
	assert.Equal(t, "019abc-123", dataPayload["paper_id"])
	assert.Equal(t, "new_papers_topic", dataPayload["type"])
}

func TestFCMClient_UnregisteredError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(`{
			"error": {
				"code": 404,
				"message": "Requested entity was not found.",
				"status": "UNREGISTERED"
			}
		}`))
	}))
	defer srv.Close()

	client := push.NewFCMClient(push.Config{
		FCMBaseURL: srv.URL,
	}, nil)

	dev := domainnotif.Device{Token: "stale-token", Platform: domainnotif.PlatformAndroid}
	notif := domainnotif.Notification{Title: "Alert"}

	err := client.SendPush(context.Background(), dev, notif)
	assert.ErrorIs(t, err, domainnotif.ErrDeviceUnregistered)
}

func TestAPNSClient_Success(t *testing.T) {
	var capturedURL string
	var topicHeader, priorityHeader, pushTypeHeader, authHeader string
	var capturedPayload map[string]any

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		capturedURL = r.URL.Path
		topicHeader = r.Header.Get("apns-topic")
		priorityHeader = r.Header.Get("apns-priority")
		pushTypeHeader = r.Header.Get("apns-push-type")
		authHeader = r.Header.Get("authorization")

		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &capturedPayload)
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	client := push.NewAPNSClient(push.Config{
		APNSBaseURL:     srv.URL,
		APNSTopic:       "org.athena.research",
		APNSTokenSource: push.StaticToken("apns-jwt-token"),
	}, nil)

	dev := domainnotif.Device{
		Token:    "apns-device-hex-token",
		Platform: domainnotif.PlatformIOS,
	}
	notif := domainnotif.Notification{
		ID:    uuid.New(),
		Type:  domainnotif.TypeDigest,
		Title: "Weekly Intelligence Brief",
		Body:  "5 new breakthroughs in your topics.",
	}

	err := client.SendPush(context.Background(), dev, notif)
	require.NoError(t, err)

	assert.Equal(t, "/3/device/apns-device-hex-token", capturedURL)
	assert.Equal(t, "org.athena.research", topicHeader)
	assert.Equal(t, "10", priorityHeader)
	assert.Equal(t, "alert", pushTypeHeader)
	assert.Equal(t, "bearer apns-jwt-token", authHeader)

	aps, ok := capturedPayload["aps"].(map[string]any)
	require.True(t, ok)
	alert, ok := aps["alert"].(map[string]any)
	require.True(t, ok)
	assert.Equal(t, "Weekly Intelligence Brief", alert["title"])
}

func TestAPNSClient_UnregisteredError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusGone) // 410 Gone
		_, _ = w.Write([]byte(`{"reason":"Unregistered","timestamp":1700000000}`))
	}))
	defer srv.Close()

	client := push.NewAPNSClient(push.Config{
		APNSBaseURL: srv.URL,
	}, nil)

	dev := domainnotif.Device{Token: "bad-token", Platform: domainnotif.PlatformIOS}
	notif := domainnotif.Notification{Title: "Alert"}

	err := client.SendPush(context.Background(), dev, notif)
	assert.ErrorIs(t, err, domainnotif.ErrDeviceUnregistered)
}

func TestRouter_Routing(t *testing.T) {
	mockFCM := push.NewMockSender()
	mockAPNS := push.NewMockSender()
	mockFallback := push.NewMockSender()

	router := push.NewRouter(push.RouterConfig{
		FCM:      mockFCM,
		APNS:     mockAPNS,
		Fallback: mockFallback,
	})

	ctx := context.Background()

	// 1. Android -> FCM
	devAndroid := domainnotif.Device{Token: "tok-android", Platform: domainnotif.PlatformAndroid}
	require.NoError(t, router.SendPush(ctx, devAndroid, domainnotif.Notification{Title: "Android Alert"}))
	assert.Len(t, mockFCM.Dispatched(), 1)
	assert.Empty(t, mockAPNS.Dispatched())

	// 2. iOS -> APNS
	devIOS := domainnotif.Device{Token: "tok-ios", Platform: domainnotif.PlatformIOS}
	require.NoError(t, router.SendPush(ctx, devIOS, domainnotif.Notification{Title: "iOS Alert"}))
	assert.Len(t, mockAPNS.Dispatched(), 1)

	// 3. Fallback when APNS is nil
	routerNoAPNS := push.NewRouter(push.RouterConfig{
		FCM:      nil,
		APNS:     nil,
		Fallback: mockFallback,
	})
	require.NoError(t, routerNoAPNS.SendPush(ctx, devIOS, domainnotif.Notification{Title: "Fallback Alert"}))
	assert.Len(t, mockFallback.Dispatched(), 1)
}
