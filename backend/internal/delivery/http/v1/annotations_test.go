package v1

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	appannotation "athena/backend/internal/application/annotation"
	domainannotation "athena/backend/internal/domain/annotation"
)

type fakeHttpAnnotationStore struct {
	mu          sync.Mutex
	annotations map[uuid.UUID]domainannotation.Annotation
}

func newFakeHttpAnnotationStore() *fakeHttpAnnotationStore {
	return &fakeHttpAnnotationStore{
		annotations: make(map[uuid.UUID]domainannotation.Annotation),
	}
}

func (f *fakeHttpAnnotationStore) Create(_ context.Context, in domainannotation.CreateAnnotationInput) (domainannotation.Annotation, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	now := time.Now()
	a := domainannotation.Annotation{
		ID:           uuid.New(),
		UserID:       in.UserID,
		PaperID:      in.PaperID,
		PageNumber:   in.PageNumber,
		SectionIndex: in.SectionIndex,
		SelectedText: in.SelectedText,
		Note:         in.Note,
		Color:        in.Color,
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	f.annotations[a.ID] = a
	return a, nil
}

func (f *fakeHttpAnnotationStore) GetByID(_ context.Context, id uuid.UUID) (domainannotation.Annotation, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	a, ok := f.annotations[id]
	if !ok {
		return domainannotation.Annotation{}, domainannotation.ErrNotFound
	}
	return a, nil
}

func (f *fakeHttpAnnotationStore) ListByPaperAndUser(_ context.Context, paperID, userID uuid.UUID) ([]domainannotation.Annotation, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	var list []domainannotation.Annotation
	for _, a := range f.annotations {
		if a.PaperID == paperID && a.UserID == userID {
			list = append(list, a)
		}
	}
	return list, nil
}

func (f *fakeHttpAnnotationStore) Update(_ context.Context, in domainannotation.UpdateAnnotationInput) (domainannotation.Annotation, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	a, ok := f.annotations[in.ID]
	if !ok {
		return domainannotation.Annotation{}, domainannotation.ErrNotFound
	}
	if a.UserID != in.UserID {
		return domainannotation.Annotation{}, domainannotation.ErrUnauthorized
	}
	if in.Note != nil {
		a.Note = *in.Note
	}
	if in.Color != nil {
		a.Color = *in.Color
	}
	a.UpdatedAt = time.Now()
	f.annotations[in.ID] = a
	return a, nil
}

func (f *fakeHttpAnnotationStore) Delete(_ context.Context, id, userID uuid.UUID) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	a, ok := f.annotations[id]
	if !ok {
		return domainannotation.ErrNotFound
	}
	if a.UserID != userID {
		return domainannotation.ErrUnauthorized
	}
	delete(f.annotations, id)
	return nil
}

func setupAnnotationsTestHandlers() (*AnnotationsHandlers, *fakeHttpAnnotationStore) {
	store := newFakeHttpAnnotationStore()
	svc := appannotation.NewService(store)
	return NewAnnotationsHandlers(svc, testLogger()), store
}

func TestAnnotationsRequireAuth(t *testing.T) {
	h, _ := setupAnnotationsTestHandlers()
	paperID := uuid.New()
	annotID := uuid.New()

	endpoints := []struct {
		method  string
		path    string
		handler func(w http.ResponseWriter, r *http.Request)
		idVal   string
	}{
		{http.MethodPost, "/api/v1/papers/" + paperID.String() + "/annotations", h.Create, paperID.String()},
		{http.MethodPatch, "/api/v1/annotations/" + annotID.String(), h.Update, annotID.String()},
		{http.MethodDelete, "/api/v1/annotations/" + annotID.String(), h.Delete, annotID.String()},
	}

	for _, ep := range endpoints {
		w := httptest.NewRecorder()
		r := httptest.NewRequest(ep.method, ep.path, strings.NewReader(`{"selected_text":"sample"}`))
		r.SetPathValue("id", ep.idVal)
		ep.handler(w, r)
		assert.Equal(t, http.StatusUnauthorized, w.Code, "endpoint %s %s should require auth", ep.method, ep.path)
	}
}

func TestAnnotationsLifecycle(t *testing.T) {
	h, _ := setupAnnotationsTestHandlers()
	userID := uuid.New()
	otherUserID := uuid.New()
	paperID := uuid.New()

	// 1. Guest list returns empty items without requiring auth
	r := httptest.NewRequest(http.MethodGet, "/api/v1/papers/"+paperID.String()+"/annotations", nil)
	r.SetPathValue("id", paperID.String())
	w := httptest.NewRecorder()
	h.List(w, r)
	require.Equal(t, http.StatusOK, w.Code)
	var listResp struct {
		Items []annotationDTO `json:"items"`
	}
	err := json.Unmarshal(w.Body.Bytes(), &listResp)
	require.NoError(t, err)
	assert.Empty(t, listResp.Items)

	// 2. Create annotation with invalid input (empty selected text) -> 400
	invalidBody := `{"selected_text":"","color":"yellow"}`
	r = withUserContext(httptest.NewRequest(http.MethodPost, "/api/v1/papers/"+paperID.String()+"/annotations", strings.NewReader(invalidBody)), userID)
	r.SetPathValue("id", paperID.String())
	w = httptest.NewRecorder()
	h.Create(w, r)
	assert.Equal(t, http.StatusBadRequest, w.Code)

	// 3. Create valid annotation
	validBody := `{
		"page_number": 3,
		"section_index": 2,
		"selected_text": "Transformer architecture dispenses with recurrence.",
		"note": "Crucial paradigm shift in NLP",
		"color": "coral"
	}`
	r = withUserContext(httptest.NewRequest(http.MethodPost, "/api/v1/papers/"+paperID.String()+"/annotations", strings.NewReader(validBody)), userID)
	r.SetPathValue("id", paperID.String())
	w = httptest.NewRecorder()
	h.Create(w, r)
	require.Equal(t, http.StatusCreated, w.Code)

	var created annotationDTO
	err = json.Unmarshal(w.Body.Bytes(), &created)
	require.NoError(t, err)
	assert.NotEmpty(t, created.ID)
	assert.Equal(t, userID.String(), created.UserID)
	assert.Equal(t, paperID.String(), created.PaperID)
	assert.Equal(t, 3, created.PageNumber)
	assert.Equal(t, 2, created.SectionIndex)
	assert.Equal(t, "Transformer architecture dispenses with recurrence.", created.SelectedText)
	assert.Equal(t, "Crucial paradigm shift in NLP", created.Note)
	assert.Equal(t, "coral", created.Color)
	annotID := created.ID

	// 4. Authenticated list returns created annotation
	r = withUserContext(httptest.NewRequest(http.MethodGet, "/api/v1/papers/"+paperID.String()+"/annotations", nil), userID)
	r.SetPathValue("id", paperID.String())
	w = httptest.NewRecorder()
	h.List(w, r)
	require.Equal(t, http.StatusOK, w.Code)
	err = json.Unmarshal(w.Body.Bytes(), &listResp)
	require.NoError(t, err)
	require.Len(t, listResp.Items, 1)
	assert.Equal(t, annotID, listResp.Items[0].ID)

	// 5. Other user list returns 0 items
	r = withUserContext(httptest.NewRequest(http.MethodGet, "/api/v1/papers/"+paperID.String()+"/annotations", nil), otherUserID)
	r.SetPathValue("id", paperID.String())
	w = httptest.NewRecorder()
	h.List(w, r)
	require.Equal(t, http.StatusOK, w.Code)
	err = json.Unmarshal(w.Body.Bytes(), &listResp)
	require.NoError(t, err)
	assert.Empty(t, listResp.Items)

	// 6. Other user update returns 403 Forbidden
	patchBody := `{"color":"emerald"}`
	r = withUserContext(httptest.NewRequest(http.MethodPatch, "/api/v1/annotations/"+annotID, strings.NewReader(patchBody)), otherUserID)
	r.SetPathValue("id", annotID)
	w = httptest.NewRecorder()
	h.Update(w, r)
	assert.Equal(t, http.StatusForbidden, w.Code)

	// 7. Creator updates note and color
	patchBody = `{"note":"Updated note with literature comparison","color":"emerald"}`
	r = withUserContext(httptest.NewRequest(http.MethodPatch, "/api/v1/annotations/"+annotID, strings.NewReader(patchBody)), userID)
	r.SetPathValue("id", annotID)
	w = httptest.NewRecorder()
	h.Update(w, r)
	require.Equal(t, http.StatusOK, w.Code)

	var updated annotationDTO
	err = json.Unmarshal(w.Body.Bytes(), &updated)
	require.NoError(t, err)
	assert.Equal(t, "Updated note with literature comparison", updated.Note)
	assert.Equal(t, "emerald", updated.Color)

	// 8. Other user delete returns 403 Forbidden
	r = withUserContext(httptest.NewRequest(http.MethodDelete, "/api/v1/annotations/"+annotID, nil), otherUserID)
	r.SetPathValue("id", annotID)
	w = httptest.NewRecorder()
	h.Delete(w, r)
	assert.Equal(t, http.StatusForbidden, w.Code)

	// 9. Creator deletes annotation
	r = withUserContext(httptest.NewRequest(http.MethodDelete, "/api/v1/annotations/"+annotID, nil), userID)
	r.SetPathValue("id", annotID)
	w = httptest.NewRecorder()
	h.Delete(w, r)
	assert.Equal(t, http.StatusNoContent, w.Code)

	// 10. Deleting already deleted annotation returns 404
	r = withUserContext(httptest.NewRequest(http.MethodDelete, "/api/v1/annotations/"+annotID, nil), userID)
	r.SetPathValue("id", annotID)
	w = httptest.NewRecorder()
	h.Delete(w, r)
	assert.Equal(t, http.StatusNotFound, w.Code)
}
