package collection_test

import (
	"strings"
	"testing"

	"github.com/google/uuid"

	domaincollection "athena/backend/internal/domain/collection"
)

func TestCreateInput_Validate(t *testing.T) {
	validUserID := uuid.New()

	tests := []struct {
		name      string
		input     domaincollection.CreateInput
		wantErr   bool
		errMsg    string
		wantColor string
	}{
		{
			name: "valid input with custom color",
			input: domaincollection.CreateInput{
				UserID:      validUserID,
				Name:        "Transformer Optimization",
				Description: "Papers on attention pruning and flash attention",
				Color:       "#10B981",
				IsPublic:    true,
			},
			wantErr:   false,
			wantColor: "#10B981",
		},
		{
			name: "valid input uses default color when blank",
			input: domaincollection.CreateInput{
				UserID: validUserID,
				Name:   "Quantum Computing",
			},
			wantErr:   false,
			wantColor: domaincollection.DefaultCollectionColor,
		},
		{
			name: "empty name fails",
			input: domaincollection.CreateInput{
				UserID: validUserID,
				Name:   "   ",
			},
			wantErr: true,
			errMsg:  "blank",
		},
		{
			name: "missing user id fails",
			input: domaincollection.CreateInput{
				UserID: uuid.Nil,
				Name:   "Neuroscience",
			},
			wantErr: true,
			errMsg:  "user_id",
		},
		{
			name: "name exceeding 120 chars fails",
			input: domaincollection.CreateInput{
				UserID: validUserID,
				Name:   strings.Repeat("a", 121),
			},
			wantErr: true,
			errMsg:  "exceeds 120",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			input := tc.input
			err := input.Validate()
			if tc.wantErr {
				if err == nil {
					t.Fatalf("expected error containing %q, got nil", tc.errMsg)
				}
				if !strings.Contains(err.Error(), tc.errMsg) {
					t.Fatalf("expected error %q to contain %q", err.Error(), tc.errMsg)
				}
			} else {
				if err != nil {
					t.Fatalf("unexpected validation error: %v", err)
				}
				if input.Color != tc.wantColor {
					t.Fatalf("expected color %q, got %q", tc.wantColor, input.Color)
				}
			}
		})
	}
}

func TestUpdateInput_Validate(t *testing.T) {
	blankName := "   "
	validName := "  Updated Name  "
	longName := strings.Repeat("b", 121)
	blankColor := "   "
	validColor := "#EC4899"
	desc := "  trimmed description  "

	t.Run("empty name fails", func(t *testing.T) {
		input := domaincollection.UpdateInput{Name: &blankName}
		if err := input.Validate(); err == nil {
			t.Fatal("expected error for empty name, got nil")
		}
	})

	t.Run("long name fails", func(t *testing.T) {
		input := domaincollection.UpdateInput{Name: &longName}
		if err := input.Validate(); err == nil {
			t.Fatal("expected error for name > 120 chars, got nil")
		}
	})

	t.Run("valid name trimmed and blank color defaults", func(t *testing.T) {
		input := domaincollection.UpdateInput{
			Name:        &validName,
			Color:       &blankColor,
			Description: &desc,
		}
		if err := input.Validate(); err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if *input.Name != "Updated Name" {
			t.Fatalf("expected trimmed name, got %q", *input.Name)
		}
		if *input.Color != domaincollection.DefaultCollectionColor {
			t.Fatalf("expected default color for blank, got %q", *input.Color)
		}
		if *input.Description != "trimmed description" {
			t.Fatalf("expected trimmed description, got %q", *input.Description)
		}
	})

	t.Run("valid color retained", func(t *testing.T) {
		input := domaincollection.UpdateInput{Color: &validColor}
		if err := input.Validate(); err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if *input.Color != "#EC4899" {
			t.Fatalf("expected '#EC4899', got %q", *input.Color)
		}
	})
}

func TestRole_Permissions(t *testing.T) {
	tests := []struct {
		role             domaincollection.Role
		canManageMembers bool
		canEditPapers    bool
		canView          bool
	}{
		{domaincollection.RoleOwner, true, true, true},
		{domaincollection.RoleAdmin, true, true, true},
		{domaincollection.RoleEditor, false, true, true},
		{domaincollection.RoleViewer, false, false, true},
		{domaincollection.Role("unknown"), false, false, false},
	}

	for _, tt := range tests {
		t.Run(string(tt.role), func(t *testing.T) {
			if got := tt.role.CanManageMembers(); got != tt.canManageMembers {
				t.Errorf("CanManageMembers() = %v, want %v", got, tt.canManageMembers)
			}
			if got := tt.role.CanEditPapers(); got != tt.canEditPapers {
				t.Errorf("CanEditPapers() = %v, want %v", got, tt.canEditPapers)
			}
			if got := tt.role.CanView(); got != tt.canView {
				t.Errorf("CanView() = %v, want %v", got, tt.canView)
			}
		})
	}
}

func TestAddCollaboratorInput_Validate(t *testing.T) {
	colID := uuid.New()
	userID := uuid.New()

	t.Run("valid input", func(t *testing.T) {
		input := domaincollection.AddCollaboratorInput{
			CollectionID: colID,
			UserID:       userID,
			Role:         domaincollection.RoleEditor,
		}
		if err := input.Validate(); err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
	})

	t.Run("missing collection id", func(t *testing.T) {
		input := domaincollection.AddCollaboratorInput{
			CollectionID: uuid.Nil,
			UserID:       userID,
			Role:         domaincollection.RoleEditor,
		}
		if err := input.Validate(); err == nil {
			t.Fatal("expected error for nil collection_id")
		}
	})

	t.Run("missing user id", func(t *testing.T) {
		input := domaincollection.AddCollaboratorInput{
			CollectionID: colID,
			UserID:       uuid.Nil,
			Role:         domaincollection.RoleViewer,
		}
		if err := input.Validate(); err == nil {
			t.Fatal("expected error for nil user_id")
		}
	})

	t.Run("invalid role", func(t *testing.T) {
		input := domaincollection.AddCollaboratorInput{
			CollectionID: colID,
			UserID:       userID,
			Role:         "superadmin",
		}
		if err := input.Validate(); err == nil {
			t.Fatal("expected error for invalid role")
		}
	})
}
