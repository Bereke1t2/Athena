package annotation

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	domainannotation "athena/backend/internal/domain/annotation"
)

// Store abstracts persistence for paper annotations.
type Store interface {
	Create(ctx context.Context, in domainannotation.CreateAnnotationInput) (domainannotation.Annotation, error)
	GetByID(ctx context.Context, id uuid.UUID) (domainannotation.Annotation, error)
	ListByPaperAndUser(ctx context.Context, paperID, userID uuid.UUID) ([]domainannotation.Annotation, error)
	ListByUser(ctx context.Context, filter domainannotation.ListUserAnnotationsFilter) ([]domainannotation.UserAnnotation, error)
	Update(ctx context.Context, in domainannotation.UpdateAnnotationInput) (domainannotation.Annotation, error)
	Delete(ctx context.Context, id, userID uuid.UUID) error
}

// Service implements application logic for reader highlights and margin notes.
type Service struct {
	store Store
}

// NewService creates a new annotation application service.
func NewService(store Store) *Service {
	return &Service{store: store}
}

// ListAnnotations returns all annotations for a given paper and user.
// If userID is uuid.Nil (e.g. guest mode), it gracefully returns an empty list.
func (s *Service) ListAnnotations(ctx context.Context, paperID, userID uuid.UUID) ([]domainannotation.Annotation, error) {
	if paperID == uuid.Nil {
		return nil, fmt.Errorf("%w: paper_id is required", domainannotation.ErrInvalidInput)
	}
	if userID == uuid.Nil {
		return []domainannotation.Annotation{}, nil
	}
	return s.store.ListByPaperAndUser(ctx, paperID, userID)
}

// ListUserAnnotations returns all annotations created by the user across papers, with optional color and text filtering.
func (s *Service) ListUserAnnotations(ctx context.Context, filter domainannotation.ListUserAnnotationsFilter) ([]domainannotation.UserAnnotation, error) {
	if filter.UserID == uuid.Nil {
		return []domainannotation.UserAnnotation{}, nil
	}
	if filter.Limit <= 0 {
		filter.Limit = 50
	}
	if filter.Limit > 100 {
		filter.Limit = 100
	}
	return s.store.ListByUser(ctx, filter)
}

// CreateAnnotation creates a new reader highlight or margin note.
func (s *Service) CreateAnnotation(ctx context.Context, in domainannotation.CreateAnnotationInput) (domainannotation.Annotation, error) {
	if err := in.Validate(); err != nil {
		return domainannotation.Annotation{}, fmt.Errorf("%w: %s", domainannotation.ErrInvalidInput, err.Error())
	}
	return s.store.Create(ctx, in)
}

// UpdateAnnotation updates an existing annotation's note or color.
func (s *Service) UpdateAnnotation(ctx context.Context, in domainannotation.UpdateAnnotationInput) (domainannotation.Annotation, error) {
	if err := in.Validate(); err != nil {
		return domainannotation.Annotation{}, fmt.Errorf("%w: %s", domainannotation.ErrInvalidInput, err.Error())
	}
	return s.store.Update(ctx, in)
}

// DeleteAnnotation removes an annotation for a user.
func (s *Service) DeleteAnnotation(ctx context.Context, id, userID uuid.UUID) error {
	if id == uuid.Nil {
		return fmt.Errorf("%w: id is required", domainannotation.ErrInvalidInput)
	}
	if userID == uuid.Nil {
		return domainannotation.ErrUnauthorized
	}
	return s.store.Delete(ctx, id, userID)
}
