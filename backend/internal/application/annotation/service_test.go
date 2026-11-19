package annotation

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	domainannotation "athena/backend/internal/domain/annotation"
)

type mockStore struct {
	annotations map[uuid.UUID]domainannotation.Annotation
}

func newMockStore() *mockStore {
	return &mockStore{annotations: make(map[uuid.UUID]domainannotation.Annotation)}
}

func (m *mockStore) Create(_ context.Context, in domainannotation.CreateAnnotationInput) (domainannotation.Annotation, error) {
	id := uuid.New()
	a := domainannotation.Annotation{
		ID:           id,
		UserID:       in.UserID,
		PaperID:      in.PaperID,
		PageNumber:   in.PageNumber,
		SectionIndex: in.SectionIndex,
		SelectedText: in.SelectedText,
		Note:         in.Note,
		Color:        in.Color,
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}
	m.annotations[id] = a
	return a, nil
}

func (m *mockStore) GetByID(_ context.Context, id uuid.UUID) (domainannotation.Annotation, error) {
	if a, ok := m.annotations[id]; ok {
		return a, nil
	}
	return domainannotation.Annotation{}, domainannotation.ErrNotFound
}

func (m *mockStore) ListByPaperAndUser(_ context.Context, paperID, userID uuid.UUID) ([]domainannotation.Annotation, error) {
	var list []domainannotation.Annotation
	for _, a := range m.annotations {
		if a.PaperID == paperID && a.UserID == userID {
			list = append(list, a)
		}
	}
	return list, nil
}

func (m *mockStore) Update(_ context.Context, in domainannotation.UpdateAnnotationInput) (domainannotation.Annotation, error) {
	a, ok := m.annotations[in.ID]
	if !ok || a.UserID != in.UserID {
		return domainannotation.Annotation{}, domainannotation.ErrNotFound
	}
	if in.Note != nil {
		a.Note = *in.Note
	}
	if in.Color != nil {
		a.Color = *in.Color
	}
	a.UpdatedAt = time.Now().UTC()
	m.annotations[in.ID] = a
	return a, nil
}

func (m *mockStore) Delete(_ context.Context, id, userID uuid.UUID) error {
	a, ok := m.annotations[id]
	if !ok || a.UserID != userID {
		return domainannotation.ErrNotFound
	}
	delete(m.annotations, id)
	return nil
}

func TestAnnotationService(t *testing.T) {
	store := newMockStore()
	svc := NewService(store)
	ctx := context.Background()

	paperID := uuid.New()
	userID := uuid.New()

	t.Run("guest user returns empty list without error", func(t *testing.T) {
		res, err := svc.ListAnnotations(ctx, paperID, uuid.Nil)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if len(res) != 0 {
			t.Errorf("expected 0 annotations for guest, got %d", len(res))
		}
	})

	t.Run("create annotation", func(t *testing.T) {
		in := domainannotation.CreateAnnotationInput{
			UserID:       userID,
			PaperID:      paperID,
			PageNumber:   2,
			SectionIndex: 1,
			SelectedText: "Transformers achieve state-of-the-art results.",
			Note:         "Check attention head count.",
			Color:        "Coral",
		}
		created, err := svc.CreateAnnotation(ctx, in)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if created.ID == uuid.Nil {
			t.Error("expected non-nil ID")
		}
		if created.Color != "coral" {
			t.Errorf("expected lowercase color 'coral', got %q", created.Color)
		}

		// Verify listing returns created annotation
		list, err := svc.ListAnnotations(ctx, paperID, userID)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if len(list) != 1 {
			t.Fatalf("expected 1 annotation, got %d", len(list))
		}
		if list[0].SelectedText != in.SelectedText {
			t.Errorf("expected text %q, got %q", in.SelectedText, list[0].SelectedText)
		}

		// Update annotation
		newNote := "Updated: verified with 8 attention heads."
		updated, err := svc.UpdateAnnotation(ctx, domainannotation.UpdateAnnotationInput{
			ID:     created.ID,
			UserID: userID,
			Note:   &newNote,
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if updated.Note != newNote {
			t.Errorf("expected note %q, got %q", newNote, updated.Note)
		}

		// Delete annotation
		if err := svc.DeleteAnnotation(ctx, created.ID, userID); err != nil {
			t.Fatalf("unexpected error on delete: %v", err)
		}

		// Verify list is empty
		listAfter, err := svc.ListAnnotations(ctx, paperID, userID)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if len(listAfter) != 0 {
			t.Errorf("expected 0 annotations after delete, got %d", len(listAfter))
		}
	})
}
