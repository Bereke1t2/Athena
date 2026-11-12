package collection

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"

	domaincollection "athena/backend/internal/domain/collection"
	"athena/backend/internal/domain/research"
)

// Service coordinates research collections and reading lists use cases.
type Service struct {
	store  domaincollection.Store
	reader research.PaperReader
}

// NewService constructs a collection application service.
func NewService(store domaincollection.Store, reader research.PaperReader) *Service {
	return &Service{
		store:  store,
		reader: reader,
	}
}

// CreateCollection creates a new collection for a user.
func (s *Service) CreateCollection(ctx context.Context, input domaincollection.CreateInput) (domaincollection.Collection, error) {
	if err := input.Validate(); err != nil {
		return domaincollection.Collection{}, fmt.Errorf("%w: %s", domaincollection.ErrInvalidInput, err.Error())
	}

	c := domaincollection.Collection{
		ID:          uuid.New(),
		UserID:      input.UserID,
		Name:        input.Name,
		Description: input.Description,
		Color:       input.Color,
		IsPublic:    input.IsPublic,
	}

	created, err := s.store.Create(ctx, c)
	if err != nil {
		return domaincollection.Collection{}, err
	}
	return created, nil
}

// GetCollection returns a collection and its papers, verifying ownership or public access.
func (s *Service) GetCollection(ctx context.Context, userID, collectionID uuid.UUID) (domaincollection.Collection, []domaincollection.CollectionPaper, error) {
	if collectionID == uuid.Nil {
		return domaincollection.Collection{}, nil, fmt.Errorf("%w: invalid collection id", domaincollection.ErrInvalidInput)
	}

	c, err := s.store.GetByID(ctx, collectionID)
	if err != nil {
		return domaincollection.Collection{}, nil, err
	}

	if !c.IsPublic && c.UserID != userID {
		return domaincollection.Collection{}, nil, domaincollection.ErrUnauthorized
	}

	papers, err := s.store.ListPapers(ctx, collectionID)
	if err != nil {
		return domaincollection.Collection{}, nil, err
	}

	return c, papers, nil
}

// ListCollections returns all collections owned by a user.
func (s *Service) ListCollections(ctx context.Context, userID uuid.UUID) ([]domaincollection.Collection, error) {
	if userID == uuid.Nil {
		return nil, fmt.Errorf("%w: user id required", domaincollection.ErrInvalidInput)
	}
	return s.store.ListByUser(ctx, userID)
}

// UpdateCollection mutates collection properties, asserting ownership.
func (s *Service) UpdateCollection(ctx context.Context, userID, collectionID uuid.UUID, input domaincollection.UpdateInput) (domaincollection.Collection, error) {
	if collectionID == uuid.Nil {
		return domaincollection.Collection{}, fmt.Errorf("%w: invalid collection id", domaincollection.ErrInvalidInput)
	}
	if err := input.Validate(); err != nil {
		return domaincollection.Collection{}, fmt.Errorf("%w: %s", domaincollection.ErrInvalidInput, err.Error())
	}

	existing, err := s.store.GetByID(ctx, collectionID)
	if err != nil {
		return domaincollection.Collection{}, err
	}
	if existing.UserID != userID {
		return domaincollection.Collection{}, domaincollection.ErrUnauthorized
	}

	return s.store.Update(ctx, collectionID, input)
}

// DeleteCollection deletes a collection, asserting ownership.
func (s *Service) DeleteCollection(ctx context.Context, userID, collectionID uuid.UUID) error {
	if collectionID == uuid.Nil {
		return fmt.Errorf("%w: invalid collection id", domaincollection.ErrInvalidInput)
	}

	existing, err := s.store.GetByID(ctx, collectionID)
	if err != nil {
		return err
	}
	if existing.UserID != userID {
		return domaincollection.ErrUnauthorized
	}

	return s.store.Delete(ctx, collectionID)
}

// AddPaper links a paper to a user's collection.
func (s *Service) AddPaper(ctx context.Context, userID, collectionID, paperID uuid.UUID, note string) error {
	if collectionID == uuid.Nil || paperID == uuid.Nil {
		return fmt.Errorf("%w: collection and paper id required", domaincollection.ErrInvalidInput)
	}

	existing, err := s.store.GetByID(ctx, collectionID)
	if err != nil {
		return err
	}
	if existing.UserID != userID {
		return domaincollection.ErrUnauthorized
	}

	if s.reader != nil {
		if _, err := s.reader.GetDetailByID(ctx, paperID); err != nil {
			if errors.Is(err, research.ErrNotFound) {
				return domaincollection.ErrPaperNotFound
			}
			return err
		}
	}

	return s.store.AddPaper(ctx, collectionID, paperID, note)
}

// RemovePaper unlinks a paper from a user's collection.
func (s *Service) RemovePaper(ctx context.Context, userID, collectionID, paperID uuid.UUID) error {
	if collectionID == uuid.Nil || paperID == uuid.Nil {
		return fmt.Errorf("%w: collection and paper id required", domaincollection.ErrInvalidInput)
	}

	existing, err := s.store.GetByID(ctx, collectionID)
	if err != nil {
		return err
	}
	if existing.UserID != userID {
		return domaincollection.ErrUnauthorized
	}

	return s.store.RemovePaper(ctx, collectionID, paperID)
}

// GetPaperMemberships returns the user's collections with membership flags for a paper.
func (s *Service) GetPaperMemberships(ctx context.Context, userID, paperID uuid.UUID) ([]domaincollection.PaperMembership, error) {
	if userID == uuid.Nil || paperID == uuid.Nil {
		return nil, fmt.Errorf("%w: user and paper id required", domaincollection.ErrInvalidInput)
	}
	return s.store.GetPaperMemberships(ctx, userID, paperID)
}
