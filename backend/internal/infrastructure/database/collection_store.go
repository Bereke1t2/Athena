package database

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	domaincollection "athena/backend/internal/domain/collection"
	"athena/backend/internal/domain/research"
)

// CollectionStore implements domain/collection.Store backed by PostgreSQL.
type CollectionStore struct {
	pool *pgxpool.Pool
}

// NewCollectionStore constructs a new CollectionStore.
func NewCollectionStore(pool *pgxpool.Pool) *CollectionStore {
	return &CollectionStore{pool: pool}
}

// Create inserts a new collection record.
func (s *CollectionStore) Create(ctx context.Context, c domaincollection.Collection) (domaincollection.Collection, error) {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	if c.Color == "" {
		c.Color = domaincollection.DefaultCollectionColor
	}

	row := s.pool.QueryRow(ctx, `
		INSERT INTO collections (id, user_id, name, description, color, is_public, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
		RETURNING created_at, updated_at`,
		c.ID, c.UserID, c.Name, c.Description, c.Color, c.IsPublic,
	)

	if err := row.Scan(&c.CreatedAt, &c.UpdatedAt); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" { // unique_violation
			return domaincollection.Collection{}, domaincollection.ErrDuplicateName
		}
		return domaincollection.Collection{}, fmt.Errorf("create collection: %w", err)
	}

	c.PaperCount = 0
	return c, nil
}

// GetByID returns the collection and paper count by ID.
func (s *CollectionStore) GetByID(ctx context.Context, id uuid.UUID) (domaincollection.Collection, error) {
	var c domaincollection.Collection
	row := s.pool.QueryRow(ctx, `
		SELECT c.id, c.user_id, c.name, c.description, c.color, c.is_public,
		       COUNT(cp.paper_id)::int AS paper_count, c.created_at, c.updated_at
		FROM collections c
		LEFT JOIN collection_papers cp ON cp.collection_id = c.id
		WHERE c.id = $1
		GROUP BY c.id`, id)

	err := row.Scan(&c.ID, &c.UserID, &c.Name, &c.Description, &c.Color, &c.IsPublic,
		&c.PaperCount, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domaincollection.Collection{}, domaincollection.ErrNotFound
		}
		return domaincollection.Collection{}, fmt.Errorf("get collection by id: %w", err)
	}
	return c, nil
}

// ListByUser returns all collections owned by the user, newest first.
func (s *CollectionStore) ListByUser(ctx context.Context, userID uuid.UUID) ([]domaincollection.Collection, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT c.id, c.user_id, c.name, c.description, c.color, c.is_public,
		       COUNT(cp.paper_id)::int AS paper_count, c.created_at, c.updated_at
		FROM collections c
		LEFT JOIN collection_papers cp ON cp.collection_id = c.id
		WHERE c.user_id = $1
		GROUP BY c.id
		ORDER BY c.created_at DESC`, userID)
	if err != nil {
		return nil, fmt.Errorf("list collections by user: %w", err)
	}
	defer rows.Close()

	var out []domaincollection.Collection
	for rows.Next() {
		var c domaincollection.Collection
		if err := rows.Scan(&c.ID, &c.UserID, &c.Name, &c.Description, &c.Color, &c.IsPublic,
			&c.PaperCount, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if out == nil {
		out = []domaincollection.Collection{}
	}
	return out, nil
}

// Update modifies collection attributes.
func (s *CollectionStore) Update(ctx context.Context, id uuid.UUID, input domaincollection.UpdateInput) (domaincollection.Collection, error) {
	existing, err := s.GetByID(ctx, id)
	if err != nil {
		return domaincollection.Collection{}, err
	}

	name := existing.Name
	if input.Name != nil {
		name = *input.Name
	}
	desc := existing.Description
	if input.Description != nil {
		desc = *input.Description
	}
	color := existing.Color
	if input.Color != nil {
		color = *input.Color
	}
	isPublic := existing.IsPublic
	if input.IsPublic != nil {
		isPublic = *input.IsPublic
	}

	row := s.pool.QueryRow(ctx, `
		UPDATE collections
		SET name = $1, description = $2, color = $3, is_public = $4, updated_at = NOW()
		WHERE id = $5
		RETURNING updated_at`, name, desc, color, isPublic, id)

	var updatedAt time.Time
	if err := row.Scan(&updatedAt); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return domaincollection.Collection{}, domaincollection.ErrDuplicateName
		}
		return domaincollection.Collection{}, fmt.Errorf("update collection: %w", err)
	}

	existing.Name = name
	existing.Description = desc
	existing.Color = color
	existing.IsPublic = isPublic
	existing.UpdatedAt = updatedAt
	return existing, nil
}

// Delete removes a collection and cascades paper associations.
func (s *CollectionStore) Delete(ctx context.Context, id uuid.UUID) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM collections WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("delete collection: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return domaincollection.ErrNotFound
	}
	return nil
}

// AddPaper links a paper to a collection.
func (s *CollectionStore) AddPaper(ctx context.Context, collectionID, paperID uuid.UUID, note string) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO collection_papers (collection_id, paper_id, note, position, added_at)
		VALUES (
			$1, $2, $3,
			COALESCE((SELECT MAX(position)+1 FROM collection_papers WHERE collection_id = $1), 0),
			NOW()
		)
		ON CONFLICT (collection_id, paper_id) DO UPDATE SET
			note = CASE WHEN EXCLUDED.note <> '' THEN EXCLUDED.note ELSE collection_papers.note END`,
		collectionID, paperID, strings.TrimSpace(note),
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23503" { // foreign_key_violation
			if strings.Contains(pgErr.ConstraintName, "paper") {
				return domaincollection.ErrPaperNotFound
			}
			return domaincollection.ErrNotFound
		}
		return fmt.Errorf("add paper to collection: %w", err)
	}
	return nil
}

// RemovePaper unlinks a paper from a collection.
func (s *CollectionStore) RemovePaper(ctx context.Context, collectionID, paperID uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `
		DELETE FROM collection_papers
		WHERE collection_id = $1 AND paper_id = $2`, collectionID, paperID)
	if err != nil {
		return fmt.Errorf("remove paper from collection: %w", err)
	}
	return nil
}

// ListPapers returns all papers within the collection ordered by position.
func (s *CollectionStore) ListPapers(ctx context.Context, collectionID uuid.UUID) ([]domaincollection.CollectionPaper, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT cp.collection_id, cp.paper_id, cp.note, cp.position, cp.added_at,
		       p.id, p.title, p.abstract, p.publication_date, p.publication_year,
		       COALESCE(p.venue_name,''), p.publication_type::text, p.oa_status::text,
		       p.is_open_access, p.cited_by_count
		FROM collection_papers cp
		JOIN papers p ON p.id = cp.paper_id AND p.deleted_at IS NULL
		WHERE cp.collection_id = $1
		ORDER BY cp.position ASC, cp.added_at DESC`, collectionID)
	if err != nil {
		return nil, fmt.Errorf("list collection papers: %w", err)
	}
	defer rows.Close()

	var out []domaincollection.CollectionPaper
	for rows.Next() {
		var cp domaincollection.CollectionPaper
		var pubType, oaStatus string
		err := rows.Scan(
			&cp.CollectionID, &cp.PaperID, &cp.Note, &cp.Position, &cp.AddedAt,
			&cp.Paper.ID, &cp.Paper.Title, &cp.Paper.Abstract, &cp.Paper.PublishedOn, &cp.Paper.Year,
			&cp.Paper.VenueName, &pubType, &oaStatus, &cp.Paper.IsOpenAccess, &cp.Paper.CitedByCount,
		)
		if err != nil {
			return nil, err
		}
		cp.Paper.PublicationType = research.PublicationType(pubType)
		cp.Paper.OAStatus = research.OAStatus(oaStatus)
		out = append(out, cp)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if out == nil {
		out = []domaincollection.CollectionPaper{}
	}
	return out, nil
}

// GetPaperMemberships returns the membership status of a paper across all of a user's collections.
func (s *CollectionStore) GetPaperMemberships(ctx context.Context, userID, paperID uuid.UUID) ([]domaincollection.PaperMembership, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT c.id, c.name, c.color,
		       (cp.paper_id IS NOT NULL) AS contains_paper,
		       COALESCE(cp.note, '') AS note
		FROM collections c
		LEFT JOIN collection_papers cp ON cp.collection_id = c.id AND cp.paper_id = $2
		WHERE c.user_id = $1
		ORDER BY c.name ASC`, userID, paperID)
	if err != nil {
		return nil, fmt.Errorf("get paper memberships: %w", err)
	}
	defer rows.Close()

	var out []domaincollection.PaperMembership
	for rows.Next() {
		var m domaincollection.PaperMembership
		if err := rows.Scan(&m.CollectionID, &m.CollectionName, &m.Color, &m.ContainsPaper, &m.Note); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if out == nil {
		out = []domaincollection.PaperMembership{}
	}
	return out, nil
}
