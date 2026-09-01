package follow_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	appfollow "athena/backend/internal/application/follow"
	domainfollow "athena/backend/internal/domain/follow"
)

type mockFollowStore struct {
	topics  map[uuid.UUID][]domainfollow.TopicFollow
	authors map[uuid.UUID][]domainfollow.AuthorFollow
	err     error
}

func newMockFollowStore() *mockFollowStore {
	return &mockFollowStore{
		topics:  make(map[uuid.UUID][]domainfollow.TopicFollow),
		authors: make(map[uuid.UUID][]domainfollow.AuthorFollow),
	}
}

func (m *mockFollowStore) FollowTopic(ctx context.Context, userID, topicID uuid.UUID, notify bool) error {
	if m.err != nil {
		return m.err
	}
	list := m.topics[userID]
	for i, f := range list {
		if f.TopicID == topicID {
			list[i].Notify = notify
			m.topics[userID] = list
			return nil
		}
	}
	m.topics[userID] = append(list, domainfollow.TopicFollow{
		UserID:    userID,
		TopicID:   topicID,
		TopicSlug: "test-topic",
		TopicName: "Test Topic",
		Notify:    notify,
		CreatedAt: time.Now().UTC(),
	})
	return nil
}

func (m *mockFollowStore) UnfollowTopic(ctx context.Context, userID, topicID uuid.UUID) error {
	if m.err != nil {
		return m.err
	}
	list := m.topics[userID]
	out := make([]domainfollow.TopicFollow, 0, len(list))
	for _, f := range list {
		if f.TopicID != topicID {
			out = append(out, f)
		}
	}
	m.topics[userID] = out
	return nil
}

func (m *mockFollowStore) FollowTopicBySlug(ctx context.Context, userID uuid.UUID, slug string, notify bool) (domainfollow.TopicFollow, error) {
	if m.err != nil {
		return domainfollow.TopicFollow{}, m.err
	}
	if slug == "unknown" {
		return domainfollow.TopicFollow{}, domainfollow.ErrNotFound
	}
	tf := domainfollow.TopicFollow{
		UserID:    userID,
		TopicID:   uuid.New(),
		TopicSlug: slug,
		TopicName: "Title for " + slug,
		Notify:    notify,
		CreatedAt: time.Now().UTC(),
	}
	m.topics[userID] = append(m.topics[userID], tf)
	return tf, nil
}

func (m *mockFollowStore) UnfollowTopicBySlug(ctx context.Context, userID uuid.UUID, slug string) error {
	if m.err != nil {
		return m.err
	}
	list := m.topics[userID]
	out := make([]domainfollow.TopicFollow, 0, len(list))
	for _, f := range list {
		if f.TopicSlug != slug {
			out = append(out, f)
		}
	}
	m.topics[userID] = out
	return nil
}

func (m *mockFollowStore) ListFollowedTopics(ctx context.Context, userID uuid.UUID) ([]domainfollow.TopicFollow, error) {
	if m.err != nil {
		return nil, m.err
	}
	return m.topics[userID], nil
}

func (m *mockFollowStore) FollowAuthor(ctx context.Context, userID, authorID uuid.UUID) (domainfollow.AuthorFollow, error) {
	if m.err != nil {
		return domainfollow.AuthorFollow{}, m.err
	}
	if authorID == uuid.MustParse("00000000-0000-0000-0000-000000000099") {
		return domainfollow.AuthorFollow{}, domainfollow.ErrNotFound
	}
	af := domainfollow.AuthorFollow{
		UserID:     userID,
		AuthorID:   authorID,
		AuthorName: "Dr. Alice",
		CreatedAt:  time.Now().UTC(),
	}
	m.authors[userID] = append(m.authors[userID], af)
	return af, nil
}

func (m *mockFollowStore) UnfollowAuthor(ctx context.Context, userID, authorID uuid.UUID) error {
	if m.err != nil {
		return m.err
	}
	list := m.authors[userID]
	out := make([]domainfollow.AuthorFollow, 0, len(list))
	for _, f := range list {
		if f.AuthorID != authorID {
			out = append(out, f)
		}
	}
	m.authors[userID] = out
	return nil
}

func (m *mockFollowStore) ListFollowedAuthors(ctx context.Context, userID uuid.UUID) ([]domainfollow.AuthorFollow, error) {
	if m.err != nil {
		return nil, m.err
	}
	return m.authors[userID], nil
}

func (m *mockFollowStore) IsFollowingTopic(ctx context.Context, userID, topicID uuid.UUID) (bool, error) {
	for _, f := range m.topics[userID] {
		if f.TopicID == topicID {
			return true, nil
		}
	}
	return false, nil
}

func (m *mockFollowStore) IsFollowingAuthor(ctx context.Context, userID, authorID uuid.UUID) (bool, error) {
	for _, f := range m.authors[userID] {
		if f.AuthorID == authorID {
			return true, nil
		}
	}
	return false, nil
}

func TestFollowService_TopicOperations(t *testing.T) {
	ctx := context.Background()
	store := newMockFollowStore()
	svc := appfollow.NewService(store)
	userID := uuid.New()
	topicID := uuid.New()

	// Validation checks
	if err := svc.FollowTopic(ctx, uuid.Nil, topicID, true); !errors.Is(err, domainfollow.ErrInvalidInput) {
		t.Fatalf("expected ErrInvalidInput for nil user, got %v", err)
	}
	if err := svc.FollowTopic(ctx, userID, uuid.Nil, true); !errors.Is(err, domainfollow.ErrInvalidInput) {
		t.Fatalf("expected ErrInvalidInput for nil topic, got %v", err)
	}

	// Follow topic
	if err := svc.FollowTopic(ctx, userID, topicID, true); err != nil {
		t.Fatalf("FollowTopic failed: %v", err)
	}

	list, err := svc.ListFollowedTopics(ctx, userID)
	if err != nil || len(list) != 1 {
		t.Fatalf("expected 1 followed topic, got %d (err: %v)", len(list), err)
	}

	// Follow by slug
	tf, err := svc.FollowTopicBySlug(ctx, userID, "ai-safety", true)
	if err != nil {
		t.Fatalf("FollowTopicBySlug failed: %v", err)
	}
	if tf.TopicSlug != "ai-safety" {
		t.Fatalf("expected slug ai-safety, got %s", tf.TopicSlug)
	}

	// Unfollow topic
	if err := svc.UnfollowTopic(ctx, userID, topicID); err != nil {
		t.Fatalf("UnfollowTopic failed: %v", err)
	}

	// Unfollow by slug
	if err := svc.UnfollowTopicBySlug(ctx, userID, "ai-safety"); err != nil {
		t.Fatalf("UnfollowTopicBySlug failed: %v", err)
	}

	listAfter, err := svc.ListFollowedTopics(ctx, userID)
	if err != nil || len(listAfter) != 0 {
		t.Fatalf("expected 0 followed topics, got %d", len(listAfter))
	}
}

func TestFollowService_AuthorOperations(t *testing.T) {
	ctx := context.Background()
	store := newMockFollowStore()
	svc := appfollow.NewService(store)
	userID := uuid.New()
	authorID := uuid.New()

	// Validation checks
	if _, err := svc.FollowAuthor(ctx, uuid.Nil, authorID); !errors.Is(err, domainfollow.ErrInvalidInput) {
		t.Fatalf("expected ErrInvalidInput for nil user, got %v", err)
	}

	af, err := svc.FollowAuthor(ctx, userID, authorID)
	if err != nil {
		t.Fatalf("FollowAuthor failed: %v", err)
	}
	if af.AuthorID != authorID {
		t.Fatalf("expected author %s, got %s", authorID, af.AuthorID)
	}

	authors, err := svc.ListFollowedAuthors(ctx, userID)
	if err != nil || len(authors) != 1 {
		t.Fatalf("expected 1 followed author, got %d", len(authors))
	}

	if err := svc.UnfollowAuthor(ctx, userID, authorID); err != nil {
		t.Fatalf("UnfollowAuthor failed: %v", err)
	}

	authorsAfter, err := svc.ListFollowedAuthors(ctx, userID)
	if err != nil || len(authorsAfter) != 0 {
		t.Fatalf("expected 0 followed authors, got %d", len(authorsAfter))
	}
}
