package annotation

import (
	"testing"

	"github.com/google/uuid"
)

func TestCreateAnnotationInput_Validate(t *testing.T) {
	validUserID := uuid.New()
	validPaperID := uuid.New()

	t.Run("valid input defaults color to yellow", func(t *testing.T) {
		in := CreateAnnotationInput{
			UserID:       validUserID,
			PaperID:      validPaperID,
			SelectedText: "We introduce a novel transformer architecture.",
		}
		if err := in.Validate(); err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if in.Color != ColorYellow {
			t.Errorf("expected default color 'yellow', got %q", in.Color)
		}
		if in.PageNumber != 1 {
			t.Errorf("expected default page_number 1, got %d", in.PageNumber)
		}
	})

	t.Run("valid input with custom color and note", func(t *testing.T) {
		in := CreateAnnotationInput{
			UserID:       validUserID,
			PaperID:      validPaperID,
			PageNumber:   3,
			SectionIndex: 2,
			SelectedText: "Our results demonstrate 15% latency reduction.",
			Note:         "Benchmark with our baseline.",
			Color:        "Coral",
		}
		if err := in.Validate(); err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if in.Color != ColorCoral {
			t.Errorf("expected color 'coral', got %q", in.Color)
		}
		if in.Note != "Benchmark with our baseline." {
			t.Errorf("unexpected note: %q", in.Note)
		}
	})

	t.Run("missing user id returns error", func(t *testing.T) {
		in := CreateAnnotationInput{
			PaperID:      validPaperID,
			SelectedText: "Text",
		}
		if err := in.Validate(); err == nil {
			t.Fatal("expected error for missing user_id")
		}
	})

	t.Run("missing paper id returns error", func(t *testing.T) {
		in := CreateAnnotationInput{
			UserID:       validUserID,
			SelectedText: "Text",
		}
		if err := in.Validate(); err == nil {
			t.Fatal("expected error for missing paper_id")
		}
	})

	t.Run("empty selected text returns error", func(t *testing.T) {
		in := CreateAnnotationInput{
			UserID:       validUserID,
			PaperID:      validPaperID,
			SelectedText: "   ",
		}
		if err := in.Validate(); err == nil {
			t.Fatal("expected error for empty selected_text")
		}
	})

	t.Run("invalid color returns error", func(t *testing.T) {
		in := CreateAnnotationInput{
			UserID:       validUserID,
			PaperID:      validPaperID,
			SelectedText: "Text",
			Color:        "neon-green",
		}
		if err := in.Validate(); err == nil {
			t.Fatal("expected error for invalid color")
		}
	})
}

func TestUpdateAnnotationInput_Validate(t *testing.T) {
	id := uuid.New()
	userID := uuid.New()

	t.Run("valid note update", func(t *testing.T) {
		note := "Updated thought on section 3"
		in := UpdateAnnotationInput{
			ID:     id,
			UserID: userID,
			Note:   &note,
		}
		if err := in.Validate(); err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
	})

	t.Run("valid color update", func(t *testing.T) {
		color := "Emerald"
		in := UpdateAnnotationInput{
			ID:     id,
			UserID: userID,
			Color:  &color,
		}
		if err := in.Validate(); err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if *in.Color != ColorEmerald {
			t.Errorf("expected lowercase 'emerald', got %q", *in.Color)
		}
	})

	t.Run("no fields to update error", func(t *testing.T) {
		in := UpdateAnnotationInput{
			ID:     id,
			UserID: userID,
		}
		if err := in.Validate(); err == nil {
			t.Fatal("expected error when no fields are provided")
		}
	})

	t.Run("invalid color update error", func(t *testing.T) {
		color := "black"
		in := UpdateAnnotationInput{
			ID:     id,
			UserID: userID,
			Color:  &color,
		}
		if err := in.Validate(); err == nil {
			t.Fatal("expected error for invalid color")
		}
	})
}
