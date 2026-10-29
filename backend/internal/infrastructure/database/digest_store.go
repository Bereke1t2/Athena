package database

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	domaindigest "athena/backend/internal/domain/digest"
)

// DigestStore implements domain/digest.DigestRepository on PostgreSQL.
type DigestStore struct {
	pool *pgxpool.Pool
}

// NewDigestStore builds a PostgreSQL-backed digest repository.
func NewDigestStore(pool *pgxpool.Pool) *DigestStore {
	return &DigestStore{pool: pool}
}

var _ domaindigest.DigestRepository = (*DigestStore)(nil)

// SaveDigest persists a personalized research briefing.
func (s *DigestStore) SaveDigest(ctx context.Context, d domaindigest.UserDigest) error {
	if d.UserID == uuid.Nil {
		return domaindigest.ErrInvalidUserID
	}
	if d.ID == uuid.Nil {
		d.ID = uuid.New()
	}
	if d.GeneratedAt.IsZero() {
		d.GeneratedAt = time.Now().UTC()
	}
	if d.Frequency == "" {
		d.Frequency = domaindigest.FrequencyWeekly
	}

	pulsesJSON, err := json.Marshal(d.Pulses)
	if err != nil {
		return fmt.Errorf("marshal pulses: %w", err)
	}
	sectionsJSON, err := json.Marshal(d.Sections)
	if err != nil {
		return fmt.Errorf("marshal sections: %w", err)
	}
	takeawaysJSON, err := json.Marshal(d.TopTakeaways)
	if err != nil {
		return fmt.Errorf("marshal top takeaways: %w", err)
	}

	_, err = s.pool.Exec(ctx, `
		INSERT INTO user_digests (id, user_id, frequency, pulses, sections, top_takeaways, generated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		d.ID, d.UserID, string(d.Frequency), pulsesJSON, sectionsJSON, takeawaysJSON, d.GeneratedAt)
	if err != nil {
		return fmt.Errorf("save digest: %w", err)
	}

	return nil
}

// GetLatestDigest retrieves the most recently generated briefing for a user.
func (s *DigestStore) GetLatestDigest(ctx context.Context, userID uuid.UUID) (domaindigest.UserDigest, error) {
	if userID == uuid.Nil {
		return domaindigest.UserDigest{}, domaindigest.ErrInvalidUserID
	}

	row := s.pool.QueryRow(ctx, `
		SELECT id, user_id, frequency, pulses, sections, top_takeaways, generated_at
		FROM user_digests
		WHERE user_id = $1
		ORDER BY generated_at DESC
		LIMIT 1`, userID)

	return scanDigest(row)
}

// ListDigests returns historical briefings for a user.
func (s *DigestStore) ListDigests(ctx context.Context, userID uuid.UUID, limit int) ([]domaindigest.UserDigest, error) {
	if userID == uuid.Nil {
		return nil, domaindigest.ErrInvalidUserID
	}
	if limit <= 0 || limit > 50 {
		limit = 10
	}

	rows, err := s.pool.Query(ctx, `
		SELECT id, user_id, frequency, pulses, sections, top_takeaways, generated_at
		FROM user_digests
		WHERE user_id = $1
		ORDER BY generated_at DESC
		LIMIT $2`, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("query digests: %w", err)
	}
	defer rows.Close()

	var digests []domaindigest.UserDigest
	for rows.Next() {
		d, err := scanDigest(rows)
		if err != nil {
			return nil, err
		}
		digests = append(digests, d)
	}

	return digests, rows.Err()
}

func scanDigest(s rowScanner) (domaindigest.UserDigest, error) {
	var (
		d             domaindigest.UserDigest
		freqStr       string
		pulsesRaw     []byte
		sectionsRaw   []byte
		takeawaysRaw  []byte
	)

	err := s.Scan(&d.ID, &d.UserID, &freqStr, &pulsesRaw, &sectionsRaw, &takeawaysRaw, &d.GeneratedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domaindigest.UserDigest{}, domaindigest.ErrDigestNotFound
		}
		return domaindigest.UserDigest{}, fmt.Errorf("scan digest: %w", err)
	}

	d.Frequency = domaindigest.Frequency(freqStr)

	if len(pulsesRaw) > 0 {
		if err := json.Unmarshal(pulsesRaw, &d.Pulses); err != nil {
			return domaindigest.UserDigest{}, fmt.Errorf("unmarshal pulses: %w", err)
		}
	}
	if len(sectionsRaw) > 0 {
		if err := json.Unmarshal(sectionsRaw, &d.Sections); err != nil {
			return domaindigest.UserDigest{}, fmt.Errorf("unmarshal sections: %w", err)
		}
	}
	if len(takeawaysRaw) > 0 {
		if err := json.Unmarshal(takeawaysRaw, &d.TopTakeaways); err != nil {
			return domaindigest.UserDigest{}, fmt.Errorf("unmarshal top takeaways: %w", err)
		}
	}

	return d, nil
}
