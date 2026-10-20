package recommendation_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	apprec "athena/backend/internal/application/recommendation"
	domainfollow "athena/backend/internal/domain/follow"
	"athena/backend/internal/domain/research"
)

type mockFollowStore struct {
	topics []domainfollow.TopicFollow
}

func (m *mockFollowStore) FollowTopic(ctx context.Context, userID, topicID uuid.UUID, notify bool) error {
	return nil
}
func (m *mockFollowStore) UnfollowTopic(ctx context.Context, userID, topicID uuid.UUID) error {
	return nil
}
func (m *mockFollowStore) FollowTopicBySlug(ctx context.Context, userID uuid.UUID, slug string, notify bool) (domainfollow.TopicFollow, error) {
	return domainfollow.TopicFollow{UserID: userID, TopicSlug: slug}, nil
}
func (m *mockFollowStore) UnfollowTopicBySlug(ctx context.Context, userID uuid.UUID, slug string) error {
	return nil
}
func (m *mockFollowStore) ListFollowedTopics(ctx context.Context, userID uuid.UUID) ([]domainfollow.TopicFollow, error) {
	return m.topics, nil
}
func (m *mockFollowStore) IsFollowingTopic(ctx context.Context, userID, topicID uuid.UUID) (bool, error) {
	return false, nil
}
func (m *mockFollowStore) FollowAuthor(ctx context.Context, userID, authorID uuid.UUID) (domainfollow.AuthorFollow, error) {
	return domainfollow.AuthorFollow{UserID: userID, AuthorID: authorID}, nil
}
func (m *mockFollowStore) UnfollowAuthor(ctx context.Context, userID, authorID uuid.UUID) error {
	return nil
}
func (m *mockFollowStore) ListFollowedAuthors(ctx context.Context, userID uuid.UUID) ([]domainfollow.AuthorFollow, error) {
	return nil, nil
}
func (m *mockFollowStore) IsFollowingAuthor(ctx context.Context, userID, authorID uuid.UUID) (bool, error) {
	return false, nil
}

func TestBuildAffinityProfile_ExplicitAndFollowed(t *testing.T) {
	uid := uuid.New()
	mockStore := &mockFollowStore{
		topics: []domainfollow.TopicFollow{
			{UserID: uid, TopicSlug: "ai", TopicName: "AI", Notify: true, CreatedAt: time.Now()},
		},
	}

	svc := apprec.NewService(mockStore)
	profile, err := svc.BuildAffinityProfile(context.Background(), uid, []string{"quantum", ""})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if profile.TopicWeights["quantum"] != 1.0 {
		t.Errorf("expected weight 1.0 for explicit topic, got %v", profile.TopicWeights["quantum"])
	}
	if profile.TopicWeights["ai"] != 1.5 {
		t.Errorf("expected weight 1.5 for followed topic, got %v", profile.TopicWeights["ai"])
	}
	if _, exists := profile.TopicWeights[""]; exists {
		t.Errorf("empty topic slug should not be present in weights")
	}
}

func TestRecommendPapers_RankingAndLimit(t *testing.T) {
	uid := uuid.New()
	svc := apprec.NewService(nil)

	p1 := research.PaperSummary{
		ID:           uuid.New(),
		Title:        "Quantum Algorithms for Optimization",
		CitedByCount: 50,
	}
	p2 := research.PaperSummary{
		ID:           uuid.New(),
		Title:        "Unrelated Botanical Study",
		CitedByCount: 1,
	}

	results := svc.RecommendPapers(context.Background(), uid, []research.PaperSummary{p2, p1}, []string{"quantum"}, 1)
	if len(results) != 1 {
		t.Fatalf("expected 1 result due to limit, got %d", len(results))
	}
	if results[0].Paper.ID != p1.ID {
		t.Errorf("expected p1 to be recommended, got %v", results[0].Paper.Title)
	}
}
