package v1

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"

	appdigest "athena/backend/internal/application/digest"
	domaindigest "athena/backend/internal/domain/digest"
	domainfollow "athena/backend/internal/domain/follow"
	"athena/backend/internal/domain/research"
	domainuser "athena/backend/internal/domain/user"
)

type fakeDigestPaperReader struct {
	papers []research.PaperSummary
}

func (f *fakeDigestPaperReader) ListPapers(_ context.Context, _ research.ListQuery) ([]research.PaperSummary, string, error) {
	return f.papers, "", nil
}

type fakeDigestFollowReader struct {
	topics []domainfollow.TopicFollow
}

func (f *fakeDigestFollowReader) ListFollowedTopics(_ context.Context, _ uuid.UUID) ([]domainfollow.TopicFollow, error) {
	return f.topics, nil
}

func TestDigestHandlers(t *testing.T) {
	userID := uuid.New()
	paperReader := &fakeDigestPaperReader{
		papers: []research.PaperSummary{
			{
				ID:    uuid.New(),
				Title: "Deep Learning in Scientific Discovery",
				Year:  2025,
			},
		},
	}
	followReader := &fakeDigestFollowReader{
		topics: []domainfollow.TopicFollow{
			{UserID: userID, TopicSlug: "ai"},
		},
	}

	svc := appdigest.NewService(paperReader, followReader, nil, discardLogger())
	h := NewDigestHandlers(svc, discardLogger())

	userCtx := context.WithValue(context.Background(), userKey{},
		domainuser.User{ID: userID, Email: "researcher@example.com"})

	t.Run("latest requires auth", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/research/digest/latest", nil)
		rec := httptest.NewRecorder()
		h.Latest(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Fatalf("expected 401, got %d", rec.Code)
		}
	})

	t.Run("latest returns digest for authenticated user", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/research/digest/latest", nil).WithContext(userCtx)
		rec := httptest.NewRecorder()
		h.Latest(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
		}
		var d domaindigest.UserDigest
		if err := json.Unmarshal(rec.Body.Bytes(), &d); err != nil {
			t.Fatalf("failed to decode digest response: %v", err)
		}
		if d.UserID != userID {
			t.Errorf("expected user ID %s, got %s", userID, d.UserID)
		}
		if len(d.Sections) == 0 {
			t.Errorf("expected at least 1 section in digest")
		}
	})

	t.Run("generate creates new digest with frequency", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{"frequency": "daily"})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/research/digest/generate", bytes.NewReader(body)).WithContext(userCtx)
		rec := httptest.NewRecorder()
		h.Generate(rec, req)

		if rec.Code != http.StatusCreated {
			t.Fatalf("expected 201, got %d: %s", rec.Code, rec.Body.String())
		}
		var d domaindigest.UserDigest
		if err := json.Unmarshal(rec.Body.Bytes(), &d); err != nil {
			t.Fatalf("failed to decode digest response: %v", err)
		}
		if d.Frequency != domaindigest.FrequencyDaily {
			t.Errorf("expected daily frequency, got %s", d.Frequency)
		}
	})

	t.Run("service unavailable when svc is nil", func(t *testing.T) {
		nilHandlers := NewDigestHandlers(nil, discardLogger())
		req := httptest.NewRequest(http.MethodGet, "/api/v1/research/digest/latest", nil).WithContext(userCtx)
		rec := httptest.NewRecorder()
		nilHandlers.Latest(rec, req)

		if rec.Code != http.StatusServiceUnavailable {
			t.Fatalf("expected 503, got %d", rec.Code)
		}
	})
}
