package v1

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	appfollow "athena/backend/internal/application/follow"
	domainfollow "athena/backend/internal/domain/follow"
	domainuser "athena/backend/internal/domain/user"
)

type fakeFollowStore struct {
	topics  map[uuid.UUID][]domainfollow.TopicFollow
	authors map[uuid.UUID][]domainfollow.AuthorFollow
}

func newFakeFollowDeliveryStore() *fakeFollowStore {
	return &fakeFollowStore{
		topics:  make(map[uuid.UUID][]domainfollow.TopicFollow),
		authors: make(map[uuid.UUID][]domainfollow.AuthorFollow),
	}
}

func (f *fakeFollowStore) FollowTopic(ctx context.Context, userID, topicID uuid.UUID, notify bool) error {
	f.topics[userID] = append(f.topics[userID], domainfollow.TopicFollow{
		UserID:    userID,
		TopicID:   topicID,
		TopicSlug: "ai-safety",
		TopicName: "AI Safety",
		Notify:    notify,
		CreatedAt: time.Now().UTC(),
	})
	return nil
}

func (f *fakeFollowStore) UnfollowTopic(ctx context.Context, userID, topicID uuid.UUID) error {
	return nil
}

func (f *fakeFollowStore) FollowTopicBySlug(ctx context.Context, userID uuid.UUID, slug string, notify bool) (domainfollow.TopicFollow, error) {
	if slug == "invalid-not-found" {
		return domainfollow.TopicFollow{}, domainfollow.ErrNotFound
	}
	tf := domainfollow.TopicFollow{
		UserID:    userID,
		TopicID:   uuid.New(),
		TopicSlug: slug,
		TopicName: "Topic " + slug,
		Notify:    notify,
		CreatedAt: time.Now().UTC(),
	}
	f.topics[userID] = append(f.topics[userID], tf)
	return tf, nil
}

func (f *fakeFollowStore) UnfollowTopicBySlug(ctx context.Context, userID uuid.UUID, slug string) error {
	return nil
}

func (f *fakeFollowStore) ListFollowedTopics(ctx context.Context, userID uuid.UUID) ([]domainfollow.TopicFollow, error) {
	return f.topics[userID], nil
}

func (f *fakeFollowStore) FollowAuthor(ctx context.Context, userID, authorID uuid.UUID) (domainfollow.AuthorFollow, error) {
	if authorID == uuid.MustParse("00000000-0000-0000-0000-000000000099") {
		return domainfollow.AuthorFollow{}, domainfollow.ErrNotFound
	}
	af := domainfollow.AuthorFollow{
		UserID:     userID,
		AuthorID:   authorID,
		AuthorName: "Prof. Smith",
		CreatedAt:  time.Now().UTC(),
	}
	f.authors[userID] = append(f.authors[userID], af)
	return af, nil
}

func (f *fakeFollowStore) UnfollowAuthor(ctx context.Context, userID, authorID uuid.UUID) error {
	return nil
}

func (f *fakeFollowStore) ListFollowedAuthors(ctx context.Context, userID uuid.UUID) ([]domainfollow.AuthorFollow, error) {
	return f.authors[userID], nil
}

func (f *fakeFollowStore) IsFollowingTopic(ctx context.Context, userID, topicID uuid.UUID) (bool, error) {
	return true, nil
}

func (f *fakeFollowStore) IsFollowingAuthor(ctx context.Context, userID, authorID uuid.UUID) (bool, error) {
	return true, nil
}

func followTestHandler() (*FollowsHandlers, *fakeFollowStore) {
	store := newFakeFollowDeliveryStore()
	return NewFollowsHandlers(appfollow.NewService(store), testLogger()), store
}

func TestFollowsRequireAuth(t *testing.T) {
	h, _ := followTestHandler()

	w := httptest.NewRecorder()
	h.FollowTopic(w, httptest.NewRequest(http.MethodPost, "/api/v1/me/follows/topics", strings.NewReader("{}")))
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("anonymous follow topic: %d", w.Code)
	}

	w = httptest.NewRecorder()
	h.ListFollowedTopics(w, httptest.NewRequest(http.MethodGet, "/api/v1/me/follows/topics", nil))
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("anonymous list topics: %d", w.Code)
	}

	w = httptest.NewRecorder()
	h.FollowAuthor(w, httptest.NewRequest(http.MethodPost, "/api/v1/me/follows/authors", strings.NewReader("{}")))
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("anonymous follow author: %d", w.Code)
	}
}

func TestFollowsTopicFlow(t *testing.T) {
	h, _ := followTestHandler()
	userCtx := context.WithValue(context.Background(), userKey{},
		domainuser.User{ID: uuid.New()})

	// Follow topic
	r := httptest.NewRequest(http.MethodPost, "/api/v1/me/follows/topics",
		strings.NewReader(`{"topic_slug":"deep-learning"}`)).WithContext(userCtx)
	w := httptest.NewRecorder()
	h.FollowTopic(w, r)
	if w.Code != http.StatusOK {
		t.Fatalf("follow topic status: %d: %s", w.Code, w.Body.String())
	}
	var res followTopicResponseDTO
	if err := json.Unmarshal(w.Body.Bytes(), &res); err != nil {
		t.Fatal(err)
	}
	if res.TopicSlug != "deep-learning" {
		t.Fatalf("expected slug deep-learning, got %s", res.TopicSlug)
	}

	// List topics
	r2 := httptest.NewRequest(http.MethodGet, "/api/v1/me/follows/topics", nil).WithContext(userCtx)
	w2 := httptest.NewRecorder()
	h.ListFollowedTopics(w2, r2)
	if w2.Code != http.StatusOK {
		t.Fatalf("list followed topics status: %d: %s", w2.Code, w2.Body.String())
	}

	// Unfollow topic
	r3 := httptest.NewRequest(http.MethodDelete, "/api/v1/me/follows/topics/deep-learning", nil).WithContext(userCtx)
	r3.SetPathValue("slug", "deep-learning")
	w3 := httptest.NewRecorder()
	h.UnfollowTopic(w3, r3)
	if w3.Code != http.StatusNoContent {
		t.Fatalf("unfollow status: %d", w3.Code)
	}
}

func TestFollowsAuthorFlow(t *testing.T) {
	h, _ := followTestHandler()
	userCtx := context.WithValue(context.Background(), userKey{},
		domainuser.User{ID: uuid.New()})
	authorID := uuid.New()

	// Follow author
	r := httptest.NewRequest(http.MethodPost, "/api/v1/me/follows/authors",
		strings.NewReader(`{"author_id":"`+authorID.String()+`"}`)).WithContext(userCtx)
	w := httptest.NewRecorder()
	h.FollowAuthor(w, r)
	if w.Code != http.StatusOK {
		t.Fatalf("follow author status: %d: %s", w.Code, w.Body.String())
	}

	// List authors
	r2 := httptest.NewRequest(http.MethodGet, "/api/v1/me/follows/authors", nil).WithContext(userCtx)
	w2 := httptest.NewRecorder()
	h.ListFollowedAuthors(w2, r2)
	if w2.Code != http.StatusOK {
		t.Fatalf("list followed authors: %d: %s", w2.Code, w2.Body.String())
	}

	// Unfollow author
	r3 := httptest.NewRequest(http.MethodDelete, "/api/v1/me/follows/authors/"+authorID.String(), nil).WithContext(userCtx)
	r3.SetPathValue("authorId", authorID.String())
	w3 := httptest.NewRecorder()
	h.UnfollowAuthor(w3, r3)
	if w3.Code != http.StatusNoContent {
		t.Fatalf("unfollow author status: %d", w3.Code)
	}
}
