package v1

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"

	appchat "athena/backend/internal/application/chat"
	domainai "athena/backend/internal/domain/ai"
)

type mockSessionStore struct {
	sessions map[uuid.UUID]domainai.Session
}

func (m *mockSessionStore) CreateSession(_ context.Context, in domainai.NewSessionInput) (domainai.Session, error) {
	s := domainai.Session{
		ID:              uuid.New(),
		SessionType:     in.SessionType,
		PaperID:         in.PaperID,
		CollectionID:    in.CollectionID,
		ComparePaperIDs: in.ComparePaperIDs,
		Title:           in.Title,
		CreatedAt:       time.Now().UTC(),
	}
	if m.sessions == nil {
		m.sessions = make(map[uuid.UUID]domainai.Session)
	}
	m.sessions[s.ID] = s
	return s, nil
}

func (m *mockSessionStore) GetSession(_ context.Context, id uuid.UUID) (domainai.Session, error) {
	if s, ok := m.sessions[id]; ok {
		return s, nil
	}
	return domainai.Session{}, domainai.ErrNotFound
}

func (m *mockSessionStore) AppendMessage(_ context.Context, msg domainai.Message) (domainai.Message, error) {
	return msg, nil
}

func (m *mockSessionStore) ListMessages(_ context.Context, _ uuid.UUID, _ int) ([]domainai.Message, error) {
	return nil, nil
}

func TestAIHandlers_CreateSession(t *testing.T) {
	store := &mockSessionStore{}
	chatSvc := appchat.NewService(nil, store, nil, nil, slog.New(slog.NewTextHandler(io.Discard, nil)))
	h := NewAIHandlers(nil, chatSvc, slog.New(slog.NewTextHandler(io.Discard, nil)))

	t.Run("single paper session", func(t *testing.T) {
		paperID := uuid.New()
		body, _ := json.Marshal(map[string]any{
			"paper_id": paperID.String(),
			"title":    "Chatting about Transformer",
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/chat/sessions", bytes.NewReader(body))
		w := httptest.NewRecorder()

		h.CreateSession(w, req)
		if w.Code != http.StatusCreated {
			t.Fatalf("expected 201, got %d: %s", w.Code, w.Body.String())
		}

		var resp sessionDTO
		if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
			t.Fatalf("failed to decode response: %v", err)
		}
		if resp.SessionType != "single_paper" {
			t.Errorf("expected session_type 'single_paper', got %q", resp.SessionType)
		}
		if resp.PaperID != paperID {
			t.Errorf("expected paper_id %s, got %s", paperID, resp.PaperID)
		}
	})

	t.Run("collection session", func(t *testing.T) {
		colID := uuid.New()
		body, _ := json.Marshal(map[string]any{
			"collection_id": colID.String(),
			"title":         "Ask My Collection: LLM Efficiency",
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/chat/sessions", bytes.NewReader(body))
		w := httptest.NewRecorder()

		h.CreateSession(w, req)
		if w.Code != http.StatusCreated {
			t.Fatalf("expected 201, got %d: %s", w.Code, w.Body.String())
		}

		var resp sessionDTO
		if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
			t.Fatalf("failed to decode response: %v", err)
		}
		if resp.SessionType != "collection" {
			t.Errorf("expected session_type 'collection', got %q", resp.SessionType)
		}
		if resp.CollectionID != colID {
			t.Errorf("expected collection_id %s, got %s", colID, resp.CollectionID)
		}
	})

	t.Run("comparison session", func(t *testing.T) {
		p1 := uuid.New()
		p2 := uuid.New()
		body, _ := json.Marshal(map[string]any{
			"compare_paper_ids": []string{p1.String(), p2.String()},
			"title":             "Compare Paper A and B",
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/chat/sessions", bytes.NewReader(body))
		w := httptest.NewRecorder()

		h.CreateSession(w, req)
		if w.Code != http.StatusCreated {
			t.Fatalf("expected 201, got %d: %s", w.Code, w.Body.String())
		}

		var resp sessionDTO
		if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
			t.Fatalf("failed to decode response: %v", err)
		}
		if resp.SessionType != "comparison" {
			t.Errorf("expected session_type 'comparison', got %q", resp.SessionType)
		}
		if len(resp.ComparePaperIDs) != 2 {
			t.Errorf("expected 2 compare_paper_ids, got %d", len(resp.ComparePaperIDs))
		}
	})

	t.Run("missing targets error", func(t *testing.T) {
		body, _ := json.Marshal(map[string]any{
			"title": "Invalid session",
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/chat/sessions", bytes.NewReader(body))
		w := httptest.NewRecorder()

		h.CreateSession(w, req)
		if w.Code != http.StatusBadRequest {
			t.Fatalf("expected 400, got %d: %s", w.Code, w.Body.String())
		}
	})
}
