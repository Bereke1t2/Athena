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

// ListByUser loads all annotations created by a user across papers with optional color and keyword filtering.
func (s *AnnotationStore) ListByUser(ctx context.Context, filter domainannotation.ListUserAnnotationsFilter) ([]domainannotation.UserAnnotation, error) {
	limit := filter.Limit
	if limit <= 0 {
		limit = 50
	}

	whereClauses := []string{"a.user_id = $1"}
	args := []any{filter.UserID}

	if filter.Color != "" {
		args = append(args, filter.Color)
		whereClauses = append(whereClauses, fmt.Sprintf("a.color = $%d", len(args)))
	}

	if filter.Query != "" {
		args = append(args, "%"+filter.Query+"%")
		pos := len(args)
		whereClauses = append(whereClauses, fmt.Sprintf("(a.selected_text ILIKE $%d OR a.note ILIKE $%d OR p.title ILIKE $%d)", pos, pos, pos))
	}

	args = append(args, limit)
	limitPos := len(args)

	query := fmt.Sprintf(`
		SELECT a.id, a.user_id, a.paper_id, a.page_number, a.section_index,
			a.selected_text, a.note, a.color, a.created_at, a.updated_at,
			COALESCE(p.title, '') AS paper_title,
			COALESCE(p.publication_year, 0) AS paper_year,
			COALESCE(p.venue_name, '') AS paper_venue,
			COALESCE(p.doi::text, '') AS paper_doi
		FROM paper_annotations a
		JOIN papers p ON p.id = a.paper_id
		WHERE %s
		ORDER BY a.created_at DESC
		LIMIT $%d`,
		strings.Join(whereClauses, " AND "),
		limitPos,
	)

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list user annotations: %w", err)
	}
	defer rows.Close()

	var results []domainannotation.UserAnnotation
	for rows.Next() {
		var ua domainannotation.UserAnnotation
		if err := rows.Scan(
			&ua.ID, &ua.UserID, &ua.PaperID, &ua.PageNumber, &ua.SectionIndex,
			&ua.SelectedText, &ua.Note, &ua.Color, &ua.CreatedAt, &ua.UpdatedAt,
			&ua.PaperTitle, &ua.PaperYear, &ua.PaperVenue, &ua.PaperDOI,
		); err != nil {
			return nil, fmt.Errorf("scan user annotation: %w", err)
		}
		results = append(results, ua)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate user annotations: %w", err)
	}

	return results, nil
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
