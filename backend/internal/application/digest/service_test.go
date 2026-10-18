package digest

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	domaindigest "athena/backend/internal/domain/digest"
	domainfollow "athena/backend/internal/domain/follow"
	"athena/backend/internal/domain/research"
)

type fakePaperReader struct {
	papers map[string][]research.PaperSummary
}

func (f *fakePaperReader) ListPapers(_ context.Context, q research.ListQuery) ([]research.PaperSummary, string, error) {
	if papers, ok := f.papers[q.TopicSlug]; ok {
		return papers, "", nil
	}
	return f.papers["default"], "", nil
}

type fakeFollowStore struct {
	topics map[uuid.UUID][]domainfollow.TopicFollow
}

func (f *fakeFollowStore) ListFollowedTopics(_ context.Context, userID uuid.UUID) ([]domainfollow.TopicFollow, error) {
	return f.topics[userID], nil
}

type fakeDigestRepo struct {
	digests map[uuid.UUID]domaindigest.UserDigest
}

func (f *fakeDigestRepo) SaveDigest(_ context.Context, d domaindigest.UserDigest) error {
	f.digests[d.UserID] = d
	return nil
}

func (f *fakeDigestRepo) GetLatestDigest(_ context.Context, userID uuid.UUID) (domaindigest.UserDigest, error) {
	d, ok := f.digests[userID]
	if !ok {
		return domaindigest.UserDigest{}, domaindigest.ErrDigestNotFound
	}
	return d, nil
}

func (f *fakeDigestRepo) ListDigests(_ context.Context, userID uuid.UUID, limit int) ([]domaindigest.UserDigest, error) {
	if d, ok := f.digests[userID]; ok {
		return []domaindigest.UserDigest{d}, nil
	}
	return nil, nil
}

func TestDigestService(t *testing.T) {
	userID := uuid.New()
	p1 := research.PaperSummary{
		ID:    uuid.New(),
		Title: "Scaling Laws for Neural Language Models",
		Year:  2020,
	}
	p2 := research.PaperSummary{
		ID:    uuid.New(),
		Title: "Deep Residual Learning for Image Recognition",
		Year:  2015,
	}

	papersReader := &fakePaperReader{
		papers: map[string][]research.PaperSummary{
			"nlp":     {p1},
			"vision":  {p2},
			"default": {p1, p2},
		},
	}

	followStore := &fakeFollowStore{
		topics: map[uuid.UUID][]domainfollow.TopicFollow{
			userID: {
				{UserID: userID, TopicSlug: "nlp", CreatedAt: time.Now()},
				{UserID: userID, TopicSlug: "vision", CreatedAt: time.Now()},
			},
		},
	}

	repo := &fakeDigestRepo{digests: make(map[uuid.UUID]domaindigest.UserDigest)}
	svc := NewService(papersReader, followStore, repo, nil)

	t.Run("generates digest with user topics", func(t *testing.T) {
		d, err := svc.GenerateDigest(context.Background(), userID, domaindigest.FrequencyWeekly)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if d.UserID != userID {
			t.Errorf("expected user ID %s, got %s", userID, d.UserID)
		}
		if len(d.Sections) != 2 {
			t.Errorf("expected 2 sections, got %d", len(d.Sections))
		}
		if len(d.Pulses) != 2 {
			t.Errorf("expected 2 pulses, got %d", len(d.Pulses))
		}
		if len(d.TopTakeaways) == 0 {
			t.Errorf("expected non-empty takeaways")
		}
	})

	t.Run("fallback when user follows no topics", func(t *testing.T) {
		unfollowedUser := uuid.New()
		d, err := svc.GenerateDigest(context.Background(), unfollowedUser, domaindigest.FrequencyDaily)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if len(d.Sections) != 1 {
			t.Errorf("expected 1 fallback trending section, got %d", len(d.Sections))
		}
		if d.Sections[0].Title != "Trending Across Athena" {
			t.Errorf("unexpected fallback section title: %s", d.Sections[0].Title)
		}
	})

	t.Run("rejects nil user ID", func(t *testing.T) {
		_, err := svc.GenerateDigest(context.Background(), uuid.Nil, domaindigest.FrequencyWeekly)
		if err != domaindigest.ErrInvalidUserID {
			t.Errorf("expected ErrInvalidUserID, got %v", err)
		}
	})

	t.Run("get latest returns cached or generates fresh", func(t *testing.T) {
		freshUser := uuid.New()
		d, err := svc.GetLatestDigest(context.Background(), freshUser)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if d.UserID != freshUser {
			t.Errorf("expected user ID %s, got %s", freshUser, d.UserID)
		}

		// Subsequent call hits repo cache
		cached, err := svc.GetLatestDigest(context.Background(), freshUser)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if cached.ID != d.ID {
			t.Errorf("expected same digest ID %s, got %s", d.ID, cached.ID)
		}
	})
}
