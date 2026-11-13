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

	appcollection "athena/backend/internal/application/collection"
	domaincollection "athena/backend/internal/domain/collection"
	domainexport "athena/backend/internal/domain/export"
	"athena/backend/internal/domain/research"
	domainuser "athena/backend/internal/domain/user"
)

type fakeHttpCollectionStore struct {
	mu          sync.Mutex
	collections map[uuid.UUID]domaincollection.Collection
	papers      map[uuid.UUID][]domaincollection.CollectionPaper
}

func newFakeHttpCollectionStore() *fakeHttpCollectionStore {
	return &fakeHttpCollectionStore{
		collections: make(map[uuid.UUID]domaincollection.Collection),
		papers:      make(map[uuid.UUID][]domaincollection.CollectionPaper),
	}
}

func (f *fakeHttpCollectionStore) Create(_ context.Context, c domaincollection.Collection) (domaincollection.Collection, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, existing := range f.collections {
		if existing.UserID == c.UserID && existing.Name == c.Name {
			return domaincollection.Collection{}, domaincollection.ErrDuplicateName
		}
	}
	c.CreatedAt = time.Now()
	c.UpdatedAt = c.CreatedAt
	f.collections[c.ID] = c
	return c, nil
}

func (f *fakeHttpCollectionStore) GetByID(_ context.Context, id uuid.UUID) (domaincollection.Collection, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	c, ok := f.collections[id]
	if !ok {
		return domaincollection.Collection{}, domaincollection.ErrNotFound
	}
	c.PaperCount = len(f.papers[id])
	return c, nil
}

func (f *fakeHttpCollectionStore) ListByUser(_ context.Context, userID uuid.UUID) ([]domaincollection.Collection, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	var list []domaincollection.Collection
	for _, c := range f.collections {
		if c.UserID == userID {
			c.PaperCount = len(f.papers[c.ID])
			list = append(list, c)
		}
	}
	return list, nil
}

func (f *fakeHttpCollectionStore) Update(_ context.Context, id uuid.UUID, input domaincollection.UpdateInput) (domaincollection.Collection, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	c, ok := f.collections[id]
	if !ok {
		return domaincollection.Collection{}, domaincollection.ErrNotFound
	}
	if input.Name != nil {
		for _, existing := range f.collections {
			if existing.ID != id && existing.UserID == c.UserID && existing.Name == *input.Name {
				return domaincollection.Collection{}, domaincollection.ErrDuplicateName
			}
		}
		c.Name = *input.Name
	}
	if input.Description != nil {
		c.Description = *input.Description
	}
	if input.Color != nil {
		c.Color = *input.Color
	}
	if input.IsPublic != nil {
		c.IsPublic = *input.IsPublic
	}
	c.UpdatedAt = time.Now()
	f.collections[id] = c
	c.PaperCount = len(f.papers[id])
	return c, nil
}

func (f *fakeHttpCollectionStore) Delete(_ context.Context, id uuid.UUID) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if _, ok := f.collections[id]; !ok {
		return domaincollection.ErrNotFound
	}
	delete(f.collections, id)
	delete(f.papers, id)
	return nil
}

func (f *fakeHttpCollectionStore) AddPaper(_ context.Context, collectionID, paperID uuid.UUID, note string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if _, ok := f.collections[collectionID]; !ok {
		return domaincollection.ErrNotFound
	}
	for i, p := range f.papers[collectionID] {
		if p.PaperID == paperID {
			f.papers[collectionID][i].Note = note
			return nil
		}
	}
	f.papers[collectionID] = append(f.papers[collectionID], domaincollection.CollectionPaper{
		CollectionID: collectionID,
		PaperID:      paperID,
		Paper: research.PaperSummary{
			ID:    paperID,
			Title: "Attention Is All You Need",
			Year:  2017,
		},
		Note:     note,
		Position: len(f.papers[collectionID]),
		AddedAt:  time.Now(),
	})
	return nil
}

func (f *fakeHttpCollectionStore) RemovePaper(_ context.Context, collectionID, paperID uuid.UUID) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	papers := f.papers[collectionID]
	filtered := make([]domaincollection.CollectionPaper, 0, len(papers))
	for _, p := range papers {
		if p.PaperID != paperID {
			filtered = append(filtered, p)
		}
	}
	f.papers[collectionID] = filtered
	return nil
}

func (f *fakeHttpCollectionStore) ListPapers(_ context.Context, collectionID uuid.UUID) ([]domaincollection.CollectionPaper, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.papers[collectionID], nil
}

func (f *fakeHttpCollectionStore) GetPaperMemberships(_ context.Context, userID, paperID uuid.UUID) ([]domaincollection.PaperMembership, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	var list []domaincollection.PaperMembership
	for _, c := range f.collections {
		if c.UserID == userID {
			contains := false
			note := ""
			for _, p := range f.papers[c.ID] {
				if p.PaperID == paperID {
					contains = true
					note = p.Note
					break
				}
			}
			list = append(list, domaincollection.PaperMembership{
				CollectionID:   c.ID,
				CollectionName: c.Name,
				Color:          c.Color,
				ContainsPaper:  contains,
				Note:           note,
			})
		}
	}
	return list, nil
}

type fakeHttpExporter struct{}

func (f *fakeHttpExporter) ExportPapersBulk(_ context.Context, paperIDs []uuid.UUID, format domainexport.Format) (string, string, error) {
	return "@article{athena2026, title={Athena}}", format.ContentType(), nil
}

func setupCollectionsTestHandlers() (*CollectionsHandlers, *fakeHttpCollectionStore) {
	store := newFakeHttpCollectionStore()
	svc := appcollection.NewService(store, nil).WithExporter(&fakeHttpExporter{})
	return NewCollectionsHandlers(svc, testLogger()), store
}

func withUserContext(r *http.Request, userID uuid.UUID) *http.Request {
	user := domainuser.User{ID: userID, Email: "researcher@athena.io"}
	return r.WithContext(context.WithValue(r.Context(), userKey{}, user))
}

func TestCollectionsRequireAuth(t *testing.T) {
	h, _ := setupCollectionsTestHandlers()

	endpoints := []struct {
		method  string
		path    string
		handler func(w http.ResponseWriter, r *http.Request)
	}{
		{http.MethodPost, "/api/v1/collections", h.Create},
		{http.MethodGet, "/api/v1/collections", h.List},
		{http.MethodPatch, "/api/v1/collections/00000000-0000-0000-0000-000000000001", h.Update},
		{http.MethodDelete, "/api/v1/collections/00000000-0000-0000-0000-000000000001", h.Delete},
		{http.MethodPost, "/api/v1/collections/00000000-0000-0000-0000-000000000001/papers", h.AddPaper},
		{http.MethodDelete, "/api/v1/collections/00000000-0000-0000-0000-000000000001/papers/00000000-0000-0000-0000-000000000002", h.RemovePaper},
		{http.MethodGet, "/api/v1/papers/00000000-0000-0000-0000-000000000002/collections", h.PaperMemberships},
	}

	for _, ep := range endpoints {
		w := httptest.NewRecorder()
		r := httptest.NewRequest(ep.method, ep.path, strings.NewReader("{}"))
		ep.handler(w, r)
		assert.Equal(t, http.StatusUnauthorized, w.Code, "endpoint %s %s should require auth", ep.method, ep.path)
	}
}

func TestCollectionsLifecycleAndExport(t *testing.T) {
	h, _ := setupCollectionsTestHandlers()
	userID := uuid.New()

	// 1. Create collection
	createBody := `{"name":"Neural Networks","description":"Deep learning papers","color":"#4F46E5","is_public":true}`
	req := withUserContext(httptest.NewRequest(http.MethodPost, "/api/v1/collections", strings.NewReader(createBody)), userID)
	w := httptest.NewRecorder()
	h.Create(w, req)
	require.Equal(t, http.StatusCreated, w.Code)

	var created collectionDTO
	err := json.Unmarshal(w.Body.Bytes(), &created)
	require.NoError(t, err)
	assert.Equal(t, "Neural Networks", created.Name)
	assert.Equal(t, "#4F46E5", created.Color)
	assert.True(t, created.IsPublic)
	colID := created.ID

	// 2. Duplicate collection name returns 409 Conflict
	req = withUserContext(httptest.NewRequest(http.MethodPost, "/api/v1/collections", strings.NewReader(createBody)), userID)
	w = httptest.NewRecorder()
	h.Create(w, req)
	assert.Equal(t, http.StatusConflict, w.Code)

	// 3. List collections
	req = withUserContext(httptest.NewRequest(http.MethodGet, "/api/v1/collections", nil), userID)
	w = httptest.NewRecorder()
	h.List(w, req)
	require.Equal(t, http.StatusOK, w.Code)
	var listResp struct {
		Items []collectionDTO `json:"items"`
	}
	err = json.Unmarshal(w.Body.Bytes(), &listResp)
	require.NoError(t, err)
	assert.Len(t, listResp.Items, 1)

	// 4. Add paper to collection
	paperID := uuid.New()
	addPaperBody := `{"paper_id":"` + paperID.String() + `","note":"Foundational paper"}`
	req = withUserContext(httptest.NewRequest(http.MethodPost, "/api/v1/collections/"+colID+"/papers", strings.NewReader(addPaperBody)), userID)
	req.SetPathValue("id", colID)
	w = httptest.NewRecorder()
	h.AddPaper(w, req)
	assert.Equal(t, http.StatusCreated, w.Code)

	// 5. Get collection with papers
	req = withUserContext(httptest.NewRequest(http.MethodGet, "/api/v1/collections/"+colID, nil), userID)
	req.SetPathValue("id", colID)
	w = httptest.NewRecorder()
	h.Get(w, req)
	require.Equal(t, http.StatusOK, w.Code)
	var detail collectionDetailResponseDTO
	err = json.Unmarshal(w.Body.Bytes(), &detail)
	require.NoError(t, err)
	assert.Equal(t, "Neural Networks", detail.Collection.Name)
	require.Len(t, detail.Papers, 1)
	assert.Equal(t, paperID.String(), detail.Papers[0].PaperID)
	assert.Equal(t, "Foundational paper", detail.Papers[0].Note)

	// 6. Paper memberships
	req = withUserContext(httptest.NewRequest(http.MethodGet, "/api/v1/papers/"+paperID.String()+"/collections", nil), userID)
	req.SetPathValue("id", paperID.String())
	w = httptest.NewRecorder()
	h.PaperMemberships(w, req)
	require.Equal(t, http.StatusOK, w.Code)
	var memResp struct {
		Items []paperMembershipDTO `json:"items"`
	}
	err = json.Unmarshal(w.Body.Bytes(), &memResp)
	require.NoError(t, err)
	require.Len(t, memResp.Items, 1)
	assert.True(t, memResp.Items[0].ContainsPaper)

	// 7. Export collection citations
	req = httptest.NewRequest(http.MethodGet, "/api/v1/collections/"+colID+"/export?format=bibtex", nil)
	req.SetPathValue("id", colID)
	w = httptest.NewRecorder()
	h.Export(w, req)
	require.Equal(t, http.StatusOK, w.Code)
	var exportResp exportResponseDTO
	err = json.Unmarshal(w.Body.Bytes(), &exportResp)
	require.NoError(t, err)
	assert.Contains(t, exportResp.Content, "@article{athena2026")
	assert.Equal(t, "bibtex", exportResp.Format)

	// 8. Update collection
	updateBody := `{"name":"Deep Learning & Transformers","color":"#10B981"}`
	req = withUserContext(httptest.NewRequest(http.MethodPatch, "/api/v1/collections/"+colID, strings.NewReader(updateBody)), userID)
	req.SetPathValue("id", colID)
	w = httptest.NewRecorder()
	h.Update(w, req)
	require.Equal(t, http.StatusOK, w.Code)

	// 9. Remove paper from collection
	req = withUserContext(httptest.NewRequest(http.MethodDelete, "/api/v1/collections/"+colID+"/papers/"+paperID.String(), nil), userID)
	req.SetPathValue("id", colID)
	req.SetPathValue("paper_id", paperID.String())
	w = httptest.NewRecorder()
	h.RemovePaper(w, req)
	assert.Equal(t, http.StatusNoContent, w.Code)

	// 10. Delete collection
	req = withUserContext(httptest.NewRequest(http.MethodDelete, "/api/v1/collections/"+colID, nil), userID)
	req.SetPathValue("id", colID)
	w = httptest.NewRecorder()
	h.Delete(w, req)
	assert.Equal(t, http.StatusNoContent, w.Code)
}
