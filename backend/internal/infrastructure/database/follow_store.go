package database

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	domainfollow "athena/backend/internal/domain/follow"
)

// FollowStore implements domain/follow.Store on Postgres.
type FollowStore struct {
	pool *pgxpool.Pool
}

// NewFollowStore constructs a follow store.
func NewFollowStore(pool *pgxpool.Pool) *FollowStore {
	return &FollowStore{pool: pool}
}

// FollowTopic adds or updates a user subscription to a topic.
func (s *FollowStore) FollowTopic(ctx context.Context, userID, topicID uuid.UUID, notify bool) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO user_topics (user_id, topic_id, notify, created_at)
		VALUES ($1, $2, $3, now())
		ON CONFLICT (user_id, topic_id) DO UPDATE SET notify = EXCLUDED.notify`,
		userID, topicID, notify)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23503" {
			return domainfollow.ErrNotFound
		}
		return fmt.Errorf("follow topic: %w", err)
	}
	return nil
}

// UnfollowTopic deletes the user topic subscription.
func (s *FollowStore) UnfollowTopic(ctx context.Context, userID, topicID uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `
		DELETE FROM user_topics WHERE user_id = $1 AND topic_id = $2`,
		userID, topicID)
	if err != nil {
		return fmt.Errorf("unfollow topic: %w", err)
	}
	return nil
}

// FollowTopicBySlug resolves topic by slug and subscribes the user.
func (s *FollowStore) FollowTopicBySlug(ctx context.Context, userID uuid.UUID, slug string, notify bool) (domainfollow.TopicFollow, error) {
	var out domainfollow.TopicFollow
	out.UserID = userID
	out.Notify = notify

	err := s.pool.QueryRow(ctx, `
		WITH target_topic AS (
			SELECT id, slug, name FROM topics WHERE slug = $1
		), inserted AS (
			INSERT INTO user_topics (user_id, topic_id, notify, created_at)
			SELECT $2, id, $3, now() FROM target_topic
			ON CONFLICT (user_id, topic_id) DO UPDATE SET notify = EXCLUDED.notify
			RETURNING topic_id, notify, created_at
		)
		SELECT t.id, t.slug, t.name, i.notify, i.created_at
		FROM inserted i
		JOIN topics t ON t.id = i.topic_id`,
		slug, userID, notify).Scan(&out.TopicID, &out.TopicSlug, &out.TopicName, &out.Notify, &out.CreatedAt)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return out, domainfollow.ErrNotFound
		}
		return out, fmt.Errorf("follow topic by slug: %w", err)
	}
	return out, nil
}

// UnfollowTopicBySlug resolves the topic by slug and removes the subscription.
func (s *FollowStore) UnfollowTopicBySlug(ctx context.Context, userID uuid.UUID, slug string) error {
	_, err := s.pool.Exec(ctx, `
		DELETE FROM user_topics ut
		USING topics t
		WHERE ut.topic_id = t.id AND ut.user_id = $1 AND t.slug = $2`,
		userID, slug)
	if err != nil {
		return fmt.Errorf("unfollow topic by slug: %w", err)
	}
	return nil
}

// ListFollowedTopics lists all topic subscriptions for the user ordered by creation date.
func (s *FollowStore) ListFollowedTopics(ctx context.Context, userID uuid.UUID) ([]domainfollow.TopicFollow, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT ut.user_id, ut.topic_id, t.slug, t.name, ut.notify, ut.created_at
		FROM user_topics ut
		JOIN topics t ON t.id = ut.topic_id
		WHERE ut.user_id = $1
		ORDER BY ut.created_at DESC`,
		userID)
	if err != nil {
		return nil, fmt.Errorf("list followed topics: %w", err)
	}
	defer rows.Close()

	out := make([]domainfollow.TopicFollow, 0)
	for rows.Next() {
		var f domainfollow.TopicFollow
		if err := rows.Scan(&f.UserID, &f.TopicID, &f.TopicSlug, &f.TopicName, &f.Notify, &f.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan followed topic: %w", err)
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// FollowAuthor adds an author follow for a user.
func (s *FollowStore) FollowAuthor(ctx context.Context, userID, authorID uuid.UUID) (domainfollow.AuthorFollow, error) {
	var out domainfollow.AuthorFollow
	out.UserID = userID
	out.AuthorID = authorID

	err := s.pool.QueryRow(ctx, `
		WITH target_author AS (
			SELECT id, canonical_name FROM authors WHERE id = $1
		), inserted AS (
			INSERT INTO user_authors (user_id, author_id, created_at)
			SELECT id, $2, now() FROM target_author
			ON CONFLICT (user_id, author_id) DO NOTHING
			RETURNING author_id, created_at
		)
		SELECT a.canonical_name, COALESCE(i.created_at, now())
		FROM authors a
		LEFT JOIN inserted i ON i.author_id = a.id
		WHERE a.id = $1`,
		authorID, userID).Scan(&out.AuthorName, &out.CreatedAt)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return out, domainfollow.ErrNotFound
		}
		return out, fmt.Errorf("follow author: %w", err)
	}
	return out, nil
}

// UnfollowAuthor deletes an author subscription.
func (s *FollowStore) UnfollowAuthor(ctx context.Context, userID, authorID uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `
		DELETE FROM user_authors WHERE user_id = $1 AND author_id = $2`,
		userID, authorID)
	if err != nil {
		return fmt.Errorf("unfollow author: %w", err)
	}
	return nil
}

// ListFollowedAuthors returns all authors followed by the user.
func (s *FollowStore) ListFollowedAuthors(ctx context.Context, userID uuid.UUID) ([]domainfollow.AuthorFollow, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT ua.user_id, ua.author_id, a.canonical_name, ua.created_at
		FROM user_authors ua
		JOIN authors a ON a.id = ua.author_id
		WHERE ua.user_id = $1
		ORDER BY ua.created_at DESC`,
		userID)
	if err != nil {
		return nil, fmt.Errorf("list followed authors: %w", err)
	}
	defer rows.Close()

	out := make([]domainfollow.AuthorFollow, 0)
	for rows.Next() {
		var f domainfollow.AuthorFollow
		if err := rows.Scan(&f.UserID, &f.AuthorID, &f.AuthorName, &f.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan followed author: %w", err)
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// IsFollowingTopic checks whether a user follows the given topic.
func (s *FollowStore) IsFollowingTopic(ctx context.Context, userID, topicID uuid.UUID) (bool, error) {
	var exists bool
	err := s.pool.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM user_topics WHERE user_id = $1 AND topic_id = $2)`,
		userID, topicID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("is following topic: %w", err)
	}
	return exists, nil
}

// IsFollowingAuthor checks whether a user follows the given author.
func (s *FollowStore) IsFollowingAuthor(ctx context.Context, userID, authorID uuid.UUID) (bool, error) {
	var exists bool
	err := s.pool.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM user_authors WHERE user_id = $1 AND author_id = $2)`,
		userID, authorID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("is following author: %w", err)
	}
	return exists, nil
}
