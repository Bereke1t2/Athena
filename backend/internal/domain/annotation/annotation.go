package annotation

import (
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
)

var (
	ErrNotFound     = errors.New("annotation not found")
	ErrUnauthorized = errors.New("unauthorized to access annotation")
	ErrInvalidInput = errors.New("invalid annotation input")
)

const (
	ColorYellow  = "yellow"
	ColorCoral   = "coral"
	ColorEmerald = "emerald"
	ColorCyan    = "cyan"
	ColorPurple  = "purple"
)

var validColors = map[string]bool{
	ColorYellow:  true,
	ColorCoral:   true,
	ColorEmerald: true,
	ColorCyan:    true,
	ColorPurple:  true,
}

func IsValidColor(c string) bool {
	return validColors[strings.ToLower(strings.TrimSpace(c))]
}

// Annotation represents a persistent reader highlight or margin note on a paper.
type Annotation struct {
	ID           uuid.UUID `json:"id"`
	UserID       uuid.UUID `json:"user_id"`
	PaperID      uuid.UUID `json:"paper_id"`
	PageNumber   int       `json:"page_number"`
	SectionIndex int       `json:"section_index"`
	SelectedText string    `json:"selected_text"`
	Note         string    `json:"note"`
	Color        string    `json:"color"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// UserAnnotation extends Annotation with joined paper metadata for multi-paper overview.
type UserAnnotation struct {
	Annotation
	PaperTitle string `json:"paper_title"`
	PaperYear  int    `json:"paper_year"`
	PaperVenue string `json:"paper_venue,omitempty"`
	PaperDOI   string `json:"paper_doi,omitempty"`
}

// ListUserAnnotationsFilter provides search and filtering parameters for a user's annotations.
type ListUserAnnotationsFilter struct {
	UserID uuid.UUID
	Color  string
	Query  string
	Limit  int
}

// CreateAnnotationInput parameters for creating an annotation.
type CreateAnnotationInput struct {
	UserID       uuid.UUID
	PaperID      uuid.UUID
	PageNumber   int
	SectionIndex int
	SelectedText string
	Note         string
	Color        string
}

func (in *CreateAnnotationInput) Validate() error {
	if in.UserID == uuid.Nil {
		return errors.New("user_id is required")
	}
	if in.PaperID == uuid.Nil {
		return errors.New("paper_id is required")
	}
	in.SelectedText = strings.TrimSpace(in.SelectedText)
	if in.SelectedText == "" {
		return errors.New("selected_text is required")
	}
	if in.PageNumber < 1 {
		in.PageNumber = 1
	}
	if in.SectionIndex < 0 {
		in.SectionIndex = 0
	}
	in.Color = strings.ToLower(strings.TrimSpace(in.Color))
	if in.Color == "" {
		in.Color = ColorYellow
	}
	if !IsValidColor(in.Color) {
		return errors.New("invalid color: must be yellow, coral, emerald, cyan, or purple")
	}
	in.Note = strings.TrimSpace(in.Note)
	return nil
}

// UpdateAnnotationInput parameters for modifying an annotation's note or color.
type UpdateAnnotationInput struct {
	ID     uuid.UUID
	UserID uuid.UUID
	Note   *string
	Color  *string
}

func (in *UpdateAnnotationInput) Validate() error {
	if in.ID == uuid.Nil {
		return errors.New("id is required")
	}
	if in.UserID == uuid.Nil {
		return errors.New("user_id is required")
	}
	if in.Note == nil && in.Color == nil {
		return errors.New("no fields to update")
	}
	if in.Color != nil {
		c := strings.ToLower(strings.TrimSpace(*in.Color))
		if !IsValidColor(c) {
			return errors.New("invalid color: must be yellow, coral, emerald, cyan, or purple")
		}
		in.Color = &c
	}
	if in.Note != nil {
		trimmed := strings.TrimSpace(*in.Note)
		in.Note = &trimmed
	}
	return nil
}
