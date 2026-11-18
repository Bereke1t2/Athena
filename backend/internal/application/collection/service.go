package collection

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"

	domaincollection "athena/backend/internal/domain/collection"
	domainexport "athena/backend/internal/domain/export"
	"athena/backend/internal/domain/research"
)

// Exporter formats multiple papers into standard bibliographic formats.
type Exporter interface {
	ExportPapersBulk(ctx context.Context, paperIDs []uuid.UUID, format domainexport.Format) (string, string, error)
}

// Service coordinates research collections and reading lists use cases.
type Service struct {
	store    domaincollection.Store
	reader   research.PaperReader
	exporter Exporter
}

// NewService constructs a collection application service.
func NewService(store domaincollection.Store, reader research.PaperReader) *Service {
	return &Service{
		store:  store,
		reader: reader,
	}
}

// WithExporter configures a citation exporter.
func (s *Service) WithExporter(exporter Exporter) *Service {
	s.exporter = exporter
	return s
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

// getUserRole resolves the role for a user relative to a collection.
func (s *Service) getUserRole(ctx context.Context, collectionID, userID, ownerID uuid.UUID) (domaincollection.Role, error) {
	if userID != uuid.Nil && userID == ownerID {
		return domaincollection.RoleOwner, nil
	}
	if userID == uuid.Nil {
		return "", domaincollection.ErrUnauthorized
	}
	return s.store.GetUserRole(ctx, collectionID, userID)
}

// GetCollection returns a collection and its papers, verifying ownership, membership or public access.
func (s *Service) GetCollection(ctx context.Context, userID, collectionID uuid.UUID) (domaincollection.Collection, []domaincollection.CollectionPaper, error) {
	if collectionID == uuid.Nil {
		return domaincollection.Collection{}, nil, fmt.Errorf("%w: invalid collection id", domaincollection.ErrInvalidInput)
	}

	c, err := s.store.GetByID(ctx, collectionID)
	if err != nil {
		return domaincollection.Collection{}, nil, err
	}

	role, err := s.getUserRole(ctx, collectionID, userID, c.UserID)
	if err == nil {
		c.UserRole = role
	}

	if !c.IsPublic && !role.CanView() {
		return domaincollection.Collection{}, nil, domaincollection.ErrUnauthorized
	}

	papers, err := s.store.ListPapers(ctx, collectionID)
	if err != nil {
		return domaincollection.Collection{}, nil, err
	}

	return c, papers, nil
}

// ListCollections returns all collections owned by or shared with a user.
func (s *Service) ListCollections(ctx context.Context, userID uuid.UUID) ([]domaincollection.Collection, error) {
	if userID == uuid.Nil {
		return nil, fmt.Errorf("%w: user id required", domaincollection.ErrInvalidInput)
	}
	return s.store.ListByUser(ctx, userID)
}

// UpdateCollection mutates collection properties, asserting ownership or admin permissions.
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
	role, err := s.getUserRole(ctx, collectionID, userID, existing.UserID)
	if err != nil || !role.CanManageMembers() {
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

// AddPaper links a paper to a collection, asserting edit permissions.
func (s *Service) AddPaper(ctx context.Context, userID, collectionID, paperID uuid.UUID, note string) error {
	if collectionID == uuid.Nil || paperID == uuid.Nil {
		return fmt.Errorf("%w: collection and paper id required", domaincollection.ErrInvalidInput)
	}

	existing, err := s.store.GetByID(ctx, collectionID)
	if err != nil {
		return err
	}
	role, err := s.getUserRole(ctx, collectionID, userID, existing.UserID)
	if err != nil || !role.CanEditPapers() {
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

// RemovePaper unlinks a paper from a collection, asserting edit permissions.
func (s *Service) RemovePaper(ctx context.Context, userID, collectionID, paperID uuid.UUID) error {
	if collectionID == uuid.Nil || paperID == uuid.Nil {
		return fmt.Errorf("%w: collection and paper id required", domaincollection.ErrInvalidInput)
	}

	existing, err := s.store.GetByID(ctx, collectionID)
	if err != nil {
		return err
	}
	role, err := s.getUserRole(ctx, collectionID, userID, existing.UserID)
	if err != nil || !role.CanEditPapers() {
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

// ExportCollection formats all papers in a collection into the requested bibliography format.
func (s *Service) ExportCollection(ctx context.Context, userID, collectionID uuid.UUID, format domainexport.Format) (string, string, error) {
	if collectionID == uuid.Nil {
		return "", "", fmt.Errorf("%w: invalid collection id", domaincollection.ErrInvalidInput)
	}

	c, err := s.store.GetByID(ctx, collectionID)
	if err != nil {
		return "", "", err
	}

	if !c.IsPublic && c.UserID != userID {
		return "", "", domaincollection.ErrUnauthorized
	}

	if s.exporter == nil {
		return "", "", errors.New("exporter not configured")
	}

	papers, err := s.store.ListPapers(ctx, collectionID)
	if err != nil {
		return "", "", err
	}

	paperIDs := make([]uuid.UUID, len(papers))
	for i, p := range papers {
		paperIDs[i] = p.PaperID
	}

	return s.exporter.ExportPapersBulk(ctx, paperIDs, format)
}

// ListCollaborators returns the members who have collaborative access to the collection.
func (s *Service) ListCollaborators(ctx context.Context, userID, collectionID uuid.UUID) ([]domaincollection.Collaborator, error) {
	if collectionID == uuid.Nil {
		return nil, fmt.Errorf("%w: invalid collection id", domaincollection.ErrInvalidInput)
	}

	existing, err := s.store.GetByID(ctx, collectionID)
	if err != nil {
		return nil, err
	}

	role, err := s.getUserRole(ctx, collectionID, userID, existing.UserID)
	if !existing.IsPublic && (err != nil || !role.CanView()) {
		return nil, domaincollection.ErrUnauthorized
	}

	return s.store.ListCollaborators(ctx, collectionID)
}

// AddCollaborator adds or updates a collaborator role on the collection.
func (s *Service) AddCollaborator(ctx context.Context, actorID uuid.UUID, input domaincollection.AddCollaboratorInput) error {
	if err := input.Validate(); err != nil {
		return fmt.Errorf("%w: %s", domaincollection.ErrInvalidInput, err.Error())
	}

	existing, err := s.store.GetByID(ctx, input.CollectionID)
	if err != nil {
		return err
	}

	actorRole, err := s.getUserRole(ctx, input.CollectionID, actorID, existing.UserID)
	if err != nil || !actorRole.CanManageMembers() {
		return domaincollection.ErrUnauthorized
	}

	if input.UserID == existing.UserID {
		return fmt.Errorf("%w: cannot add collection owner as collaborator", domaincollection.ErrInvalidInput)
	}

	c := domaincollection.Collaborator{
		CollectionID: input.CollectionID,
		UserID:       input.UserID,
		Role:         input.Role,
		InvitedBy:    input.InvitedBy,
	}
	return s.store.AddCollaborator(ctx, c)
}

// RemoveCollaborator removes a collaborator from the collection.
func (s *Service) RemoveCollaborator(ctx context.Context, actorID, collectionID, targetUserID uuid.UUID) error {
	if collectionID == uuid.Nil || targetUserID == uuid.Nil {
		return fmt.Errorf("%w: collection and user id required", domaincollection.ErrInvalidInput)
	}

	existing, err := s.store.GetByID(ctx, collectionID)
	if err != nil {
		return err
	}

	if targetUserID == existing.UserID {
		return fmt.Errorf("%w: cannot remove collection owner", domaincollection.ErrInvalidInput)
	}

	actorRole, err := s.getUserRole(ctx, collectionID, actorID, existing.UserID)
	isSelfRemoval := actorID == targetUserID
	if !isSelfRemoval && (err != nil || !actorRole.CanManageMembers()) {
		return domaincollection.ErrUnauthorized
	}

	return s.store.RemoveCollaborator(ctx, collectionID, targetUserID)
}

