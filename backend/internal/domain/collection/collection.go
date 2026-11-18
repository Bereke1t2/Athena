package collection

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"

	"athena/backend/internal/domain/research"
)

// Domain sentinel errors.
var (
	ErrNotFound             = errors.New("collection: not found")
	ErrUnauthorized         = errors.New("collection: unauthorized")
	ErrDuplicateName        = errors.New("collection: name already exists")
	ErrInvalidInput         = errors.New("collection: invalid input")
	ErrPaperNotFound        = errors.New("collection: paper not found")
	ErrInvalidRole          = errors.New("collection: invalid collaborator role")
	ErrCollaboratorNotFound = errors.New("collection: collaborator not found")
)

// DefaultCollectionColor is used when no color hex is provided.
const DefaultCollectionColor = "#6366F1"

// Role defines access level for collection collaborators.
type Role string

const (
	RoleOwner  Role = "owner"
	RoleAdmin  Role = "admin"
	RoleEditor Role = "editor"
	RoleViewer Role = "viewer"
)

// CanManageMembers reports whether the role can invite or remove members.
func (r Role) CanManageMembers() bool {
	return r == RoleOwner || r == RoleAdmin
}

// CanEditPapers reports whether the role can add or remove papers.
func (r Role) CanEditPapers() bool {
	return r == RoleOwner || r == RoleAdmin || r == RoleEditor
}

// CanView reports whether the role has read access.
func (r Role) CanView() bool {
	return r == RoleOwner || r == RoleAdmin || r == RoleEditor || r == RoleViewer
}

// Collection represents a named research paper folder or reading list.
type Collection struct {
	ID          uuid.UUID `json:"id"`
	UserID      uuid.UUID `json:"user_id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Color       string    `json:"color"`
	IsPublic    bool      `json:"is_public"`
	PaperCount  int       `json:"paper_count"`
	UserRole    Role      `json:"user_role,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// Collaborator represents a user sharing access to a collection.
type Collaborator struct {
	CollectionID uuid.UUID `json:"collection_id"`
	UserID       uuid.UUID `json:"user_id"`
	Email        string    `json:"email,omitempty"`
	Role         Role      `json:"role"`
	InvitedBy    uuid.UUID `json:"invited_by,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
}

// AddCollaboratorInput defines parameters for adding a collaborator.
type AddCollaboratorInput struct {
	CollectionID uuid.UUID
	UserID       uuid.UUID
	Role         Role
	InvitedBy    uuid.UUID
}

func (a *AddCollaboratorInput) Validate() error {
	if a.CollectionID == uuid.Nil {
		return errors.New("collection id is required")
	}
	if a.UserID == uuid.Nil {
		return errors.New("user id is required")
	}
	switch a.Role {
	case RoleAdmin, RoleEditor, RoleViewer:
		return nil
	default:
		return errors.New("invalid role: must be admin, editor, or viewer")
	}
}

// CollectionPaper links a research paper to a collection with personal context.
type CollectionPaper struct {
	CollectionID uuid.UUID              `json:"collection_id"`
	PaperID      uuid.UUID              `json:"paper_id"`
	Paper        research.PaperSummary  `json:"paper"`
	Note         string                 `json:"note"`
	Position     int                    `json:"position"`
	AddedAt      time.Time              `json:"added_at"`
}

// PaperMembership captures whether a paper is part of a user's collection.
type PaperMembership struct {
	CollectionID   uuid.UUID `json:"collection_id"`
	CollectionName string    `json:"collection_name"`
	Color          string    `json:"color"`
	ContainsPaper  bool      `json:"contains_paper"`
	Note           string    `json:"note,omitempty"`
}

// CreateInput defines parameters required to create a new collection.
type CreateInput struct {
	UserID      uuid.UUID
	Name        string
	Description string
	Color       string
	IsPublic    bool
}

// Validate validates creation input constraints.
func (c *CreateInput) Validate() error {
	c.Name = strings.TrimSpace(c.Name)
	if c.Name == "" {
		return errors.New("collection name cannot be blank")
	}
	if len(c.Name) > 120 {
		return errors.New("collection name exceeds 120 characters")
	}
	if c.UserID == uuid.Nil {
		return errors.New("user_id is required")
	}
	c.Color = strings.TrimSpace(c.Color)
	if c.Color == "" {
		c.Color = DefaultCollectionColor
	}
	c.Description = strings.TrimSpace(c.Description)
	return nil
}

// UpdateInput defines mutable fields on a collection.
type UpdateInput struct {
	Name        *string
	Description *string
	Color       *string
	IsPublic    *bool
}

// Validate validates update input parameters.
func (u *UpdateInput) Validate() error {
	if u.Name != nil {
		trimmed := strings.TrimSpace(*u.Name)
		if trimmed == "" {
			return errors.New("collection name cannot be empty")
		}
		if len(trimmed) > 120 {
			return errors.New("collection name exceeds 120 characters")
		}
		*u.Name = trimmed
	}
	if u.Color != nil {
		trimmed := strings.TrimSpace(*u.Color)
		if trimmed == "" {
			trimmed = DefaultCollectionColor
		}
		*u.Color = trimmed
	}
	if u.Description != nil {
		*u.Description = strings.TrimSpace(*u.Description)
	}
	return nil
}

// Store persists collections and paper association records.
type Store interface {
	Create(ctx context.Context, c Collection) (Collection, error)
	GetByID(ctx context.Context, id uuid.UUID) (Collection, error)
	ListByUser(ctx context.Context, userID uuid.UUID) ([]Collection, error)
	Update(ctx context.Context, id uuid.UUID, input UpdateInput) (Collection, error)
	Delete(ctx context.Context, id uuid.UUID) error

	AddPaper(ctx context.Context, collectionID, paperID uuid.UUID, note string) error
	RemovePaper(ctx context.Context, collectionID, paperID uuid.UUID) error
	ListPapers(ctx context.Context, collectionID uuid.UUID) ([]CollectionPaper, error)
	GetPaperMemberships(ctx context.Context, userID, paperID uuid.UUID) ([]PaperMembership, error)

	AddCollaborator(ctx context.Context, c Collaborator) error
	RemoveCollaborator(ctx context.Context, collectionID, userID uuid.UUID) error
	ListCollaborators(ctx context.Context, collectionID uuid.UUID) ([]Collaborator, error)
	GetUserRole(ctx context.Context, collectionID, userID uuid.UUID) (Role, error)
}
