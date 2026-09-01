// Package follow defines the domain entities and store interfaces for user follows
// across topics and authors (Phase 5).
package follow

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
)

var (
	// ErrNotFound is returned when the target topic or author does not exist.
	ErrNotFound = errors.New("follow: entity not found")
	// ErrInvalidInput marks malformed IDs, slugs, or missing required fields.
	ErrInvalidInput = errors.New("follow: invalid input")
)

// TopicFollow represents a user's subscription to a research topic.
type TopicFollow struct {
	UserID    uuid.UUID
	TopicID   uuid.UUID
	TopicSlug string
	TopicName string
	Notify    bool
	CreatedAt time.Time
}

// AuthorFollow represents a user following a specific researcher.
type AuthorFollow struct {
	UserID     uuid.UUID
	AuthorID   uuid.UUID
	AuthorName string
	CreatedAt  time.Time
}

// Store defines persistence operations for user topic and author follows.
type Store interface {
	// FollowTopic adds or updates a topic follow for a user.
	FollowTopic(ctx context.Context, userID, topicID uuid.UUID, notify bool) error
	// UnfollowTopic removes a topic subscription.
	UnfollowTopic(ctx context.Context, userID, topicID uuid.UUID) error
	// FollowTopicBySlug resolves the topic slug and adds a follow.
	FollowTopicBySlug(ctx context.Context, userID uuid.UUID, slug string, notify bool) (TopicFollow, error)
	// UnfollowTopicBySlug resolves the topic slug and removes the follow.
	UnfollowTopicBySlug(ctx context.Context, userID uuid.UUID, slug string) error
	// ListFollowedTopics lists all topics followed by the user.
	ListFollowedTopics(ctx context.Context, userID uuid.UUID) ([]TopicFollow, error)
	// FollowAuthor adds an author follow for a user.
	FollowAuthor(ctx context.Context, userID, authorID uuid.UUID) (AuthorFollow, error)
	// UnfollowAuthor removes an author subscription.
	UnfollowAuthor(ctx context.Context, userID, authorID uuid.UUID) error
	// ListFollowedAuthors lists all authors followed by the user.
	ListFollowedAuthors(ctx context.Context, userID uuid.UUID) ([]AuthorFollow, error)
	// IsFollowingTopic returns true if the user follows the topic.
	IsFollowingTopic(ctx context.Context, userID, topicID uuid.UUID) (bool, error)
	// IsFollowingAuthor returns true if the user follows the author.
	IsFollowingAuthor(ctx context.Context, userID, authorID uuid.UUID) (bool, error)
}
