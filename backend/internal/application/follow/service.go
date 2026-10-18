// Package follow implements topic and author subscription use cases (Phase 5).
package follow

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"

	domainfollow "athena/backend/internal/domain/follow"
)

// Service coordinates user subscriptions with persistence and validation.
type Service struct {
	store domainfollow.Store
}

// NewService constructs a follow service.
func NewService(store domainfollow.Store) *Service {
	return &Service{store: store}
}

// FollowTopic subscribes a user to a topic by UUID.
func (s *Service) FollowTopic(ctx context.Context, userID, topicID uuid.UUID, notify bool) error {
	if userID == uuid.Nil || topicID == uuid.Nil {
		return fmt.Errorf("%w: user_id and topic_id are required", domainfollow.ErrInvalidInput)
	}
	return s.store.FollowTopic(ctx, userID, topicID, notify)
}

// UnfollowTopic removes a user's subscription to a topic.
func (s *Service) UnfollowTopic(ctx context.Context, userID, topicID uuid.UUID) error {
	if userID == uuid.Nil || topicID == uuid.Nil {
		return fmt.Errorf("%w: user_id and topic_id are required", domainfollow.ErrInvalidInput)
	}
	return s.store.UnfollowTopic(ctx, userID, topicID)
}

// FollowTopicBySlug subscribes a user to a topic by its taxonomy slug.
func (s *Service) FollowTopicBySlug(ctx context.Context, userID uuid.UUID, slug string, notify bool) (domainfollow.TopicFollow, error) {
	if userID == uuid.Nil {
		return domainfollow.TopicFollow{}, fmt.Errorf("%w: user_id is required", domainfollow.ErrInvalidInput)
	}
	clean := strings.TrimSpace(slug)
	if clean == "" {
		return domainfollow.TopicFollow{}, fmt.Errorf("%w: topic slug cannot be empty", domainfollow.ErrInvalidInput)
	}
	return s.store.FollowTopicBySlug(ctx, userID, clean, notify)
}

// UnfollowTopicBySlug removes a topic subscription by its taxonomy slug.
func (s *Service) UnfollowTopicBySlug(ctx context.Context, userID uuid.UUID, slug string) error {
	if userID == uuid.Nil {
		return fmt.Errorf("%w: user_id is required", domainfollow.ErrInvalidInput)
	}
	clean := strings.TrimSpace(slug)
	if clean == "" {
		return fmt.Errorf("%w: topic slug cannot be empty", domainfollow.ErrInvalidInput)
	}
	return s.store.UnfollowTopicBySlug(ctx, userID, clean)
}

// ListFollowedTopics returns all topic subscriptions for the user.
func (s *Service) ListFollowedTopics(ctx context.Context, userID uuid.UUID) ([]domainfollow.TopicFollow, error) {
	if userID == uuid.Nil {
		return nil, fmt.Errorf("%w: user_id is required", domainfollow.ErrInvalidInput)
	}
	return s.store.ListFollowedTopics(ctx, userID)
}

// FollowAuthor subscribes a user to an author by UUID.
func (s *Service) FollowAuthor(ctx context.Context, userID, authorID uuid.UUID) (domainfollow.AuthorFollow, error) {
	if userID == uuid.Nil || authorID == uuid.Nil {
		return domainfollow.AuthorFollow{}, fmt.Errorf("%w: user_id and author_id are required", domainfollow.ErrInvalidInput)
	}
	return s.store.FollowAuthor(ctx, userID, authorID)
}

// UnfollowAuthor removes an author subscription.
func (s *Service) UnfollowAuthor(ctx context.Context, userID, authorID uuid.UUID) error {
	if userID == uuid.Nil || authorID == uuid.Nil {
		return fmt.Errorf("%w: user_id and author_id are required", domainfollow.ErrInvalidInput)
	}
	return s.store.UnfollowAuthor(ctx, userID, authorID)
}

// ListFollowedAuthors returns all authors followed by the user.
func (s *Service) ListFollowedAuthors(ctx context.Context, userID uuid.UUID) ([]domainfollow.AuthorFollow, error) {
	if userID == uuid.Nil {
		return nil, fmt.Errorf("%w: user_id is required", domainfollow.ErrInvalidInput)
	}
	return s.store.ListFollowedAuthors(ctx, userID)
}
