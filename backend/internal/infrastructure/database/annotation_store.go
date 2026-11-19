package database

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	domainannotation "athena/backend/internal/domain/annotation"
)

// AnnotationStore persists paper annotations in PostgreSQL.
type AnnotationStore struct {
	pool *pgxpool.Pool
}

// NewAnnotationStore creates an AnnotationStore.
func NewAnnotationStore(pool *pgxpool.Pool) *AnnotationStore {
	return &AnnotationStore{pool: pool}
}

// Create inserts a new annotation into paper_annotations.
func (s *AnnotationStore) Create(ctx context.Context, in domainannotation.CreateAnnotationInput) (domainannotation.Annotation, error) {
	if err := in.Validate(); err != nil {
		return domainannotation.Annotation{}, fmt.Errorf("%w: %s", domainannotation.ErrInvalidInput, err.Error())
	}

	id := uuid.New()
	var a domainannotation.Annotation
	row := s.pool.QueryRow(ctx, `
		INSERT INTO paper_annotations (
			id, user_id, paper_id, page_number, section_index, selected_text, note, color, created_at, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW())
		RETURNING id, user_id, paper_id, page_number, section_index, selected_text, note, color, created_at, updated_at`,
		id, in.UserID, in.PaperID, in.PageNumber, in.SectionIndex, in.SelectedText, in.Note, in.Color,
	)

	if err := row.Scan(
		&a.ID, &a.UserID, &a.PaperID, &a.PageNumber, &a.SectionIndex,
		&a.SelectedText, &a.Note, &a.Color, &a.CreatedAt, &a.UpdatedAt,
	); err != nil {
		return domainannotation.Annotation{}, fmt.Errorf("create annotation: %w", err)
	}

	return a, nil
}

// GetByID loads an annotation by ID.
func (s *AnnotationStore) GetByID(ctx context.Context, id uuid.UUID) (domainannotation.Annotation, error) {
	var a domainannotation.Annotation
	row := s.pool.QueryRow(ctx, `
		SELECT id, user_id, paper_id, page_number, section_index, selected_text, note, color, created_at, updated_at
		FROM paper_annotations
		WHERE id = $1`,
		id,
	)

	if err := row.Scan(
		&a.ID, &a.UserID, &a.PaperID, &a.PageNumber, &a.SectionIndex,
		&a.SelectedText, &a.Note, &a.Color, &a.CreatedAt, &a.UpdatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domainannotation.Annotation{}, domainannotation.ErrNotFound
		}
		return domainannotation.Annotation{}, fmt.Errorf("get annotation: %w", err)
	}

	return a, nil
}

// ListByPaperAndUser loads all annotations created by a user for a given paper.
func (s *AnnotationStore) ListByPaperAndUser(ctx context.Context, paperID, userID uuid.UUID) ([]domainannotation.Annotation, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, user_id, paper_id, page_number, section_index, selected_text, note, color, created_at, updated_at
		FROM paper_annotations
		WHERE paper_id = $1 AND user_id = $2
		ORDER BY page_number ASC, section_index ASC, created_at ASC`,
		paperID, userID,
	)
	if err != nil {
		return nil, fmt.Errorf("list annotations: %w", err)
	}
	defer rows.Close()

	var annotations []domainannotation.Annotation
	for rows.Next() {
		var a domainannotation.Annotation
		if err := rows.Scan(
			&a.ID, &a.UserID, &a.PaperID, &a.PageNumber, &a.SectionIndex,
			&a.SelectedText, &a.Note, &a.Color, &a.CreatedAt, &a.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan annotation: %w", err)
		}
		annotations = append(annotations, a)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate annotations: %w", err)
	}

	return annotations, nil
}

// Update updates an annotation's note and/or color.
func (s *AnnotationStore) Update(ctx context.Context, in domainannotation.UpdateAnnotationInput) (domainannotation.Annotation, error) {
	if err := in.Validate(); err != nil {
		return domainannotation.Annotation{}, fmt.Errorf("%w: %s", domainannotation.ErrInvalidInput, err.Error())
	}

	clauses := []string{"updated_at = NOW()"}
	args := []any{in.ID, in.UserID}

	if in.Note != nil {
		args = append(args, *in.Note)
		clauses = append(clauses, fmt.Sprintf("note = $%d", len(args)))
	}
	if in.Color != nil {
		args = append(args, *in.Color)
		clauses = append(clauses, fmt.Sprintf("color = $%d", len(args)))
	}

	query := fmt.Sprintf(`
		UPDATE paper_annotations
		SET %s
		WHERE id = $1 AND user_id = $2
		RETURNING id, user_id, paper_id, page_number, section_index, selected_text, note, color, created_at, updated_at`,
		strings.Join(clauses, ", "),
	)

	var a domainannotation.Annotation
	row := s.pool.QueryRow(ctx, query, args...)
	if err := row.Scan(
		&a.ID, &a.UserID, &a.PaperID, &a.PageNumber, &a.SectionIndex,
		&a.SelectedText, &a.Note, &a.Color, &a.CreatedAt, &a.UpdatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domainannotation.Annotation{}, domainannotation.ErrNotFound
		}
		return domainannotation.Annotation{}, fmt.Errorf("update annotation: %w", err)
	}

	return a, nil
}

// Delete removes an annotation for a user.
func (s *AnnotationStore) Delete(ctx context.Context, id, userID uuid.UUID) error {
	tag, err := s.pool.Exec(ctx, `
		DELETE FROM paper_annotations
		WHERE id = $1 AND user_id = $2`,
		id, userID,
	)
	if err != nil {
		return fmt.Errorf("delete annotation: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return domainannotation.ErrNotFound
	}
	return nil
}
