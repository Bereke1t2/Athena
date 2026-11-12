package collection_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	appcollection "athena/backend/internal/application/collection"
	domaincollection "athena/backend/internal/domain/collection"
	domainexport "athena/backend/internal/domain/export"
	"athena/backend/internal/domain/research"
)

type mockExporter struct {
	exported map[string]string
}

func (m *mockExporter) ExportPapersBulk(ctx context.Context, paperIDs []uuid.UUID, format domainexport.Format) (string, string, error) {
	return "@article{mock, title={Mock}}", format.ContentType(), nil
}

// mockCollectionStore implements domaincollection.Store in memory.
type mockCollectionStore struct {
	collections map[uuid.UUID]domaincollection.Collection
	papers      map[uuid.UUID][]domaincollection.CollectionPaper
}

func newMockStore() *mockCollectionStore {
	return &mockCollectionStore{
		collections: make(map[uuid.UUID]domaincollection.Collection),
		papers:      make(map[uuid.UUID][]domaincollection.CollectionPaper),
	}
}

func (m *mockCollectionStore) Create(ctx context.Context, c domaincollection.Collection) (domaincollection.Collection, error) {
	for _, existing := range m.collections {
		if existing.UserID == c.UserID && existing.Name == c.Name {
			return domaincollection.Collection{}, domaincollection.ErrDuplicateName
		}
	}
	c.CreatedAt = time.Now()
	c.UpdatedAt = c.CreatedAt
	m.collections[c.ID] = c
	return c, nil
}

func (m *mockCollectionStore) GetByID(ctx context.Context, id uuid.UUID) (domaincollection.Collection, error) {
	c, ok := m.collections[id]
	if !ok {
		return domaincollection.Collection{}, domaincollection.ErrNotFound
	}
	c.PaperCount = len(m.papers[id])
	return c, nil
}

func (m *mockCollectionStore) ListByUser(ctx context.Context, userID uuid.UUID) ([]domaincollection.Collection, error) {
	var list []domaincollection.Collection
	for _, c := range m.collections {
		if c.UserID == userID {
			c.PaperCount = len(m.papers[c.ID])
			list = append(list, c)
		}
	}
	return list, nil
}

func (m *mockCollectionStore) Update(ctx context.Context, id uuid.UUID, input domaincollection.UpdateInput) (domaincollection.Collection, error) {
	c, ok := m.collections[id]
	if !ok {
		return domaincollection.Collection{}, domaincollection.ErrNotFound
	}
	if input.Name != nil {
		for _, existing := range m.collections {
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
	m.collections[id] = c
	c.PaperCount = len(m.papers[id])
	return c, nil
}

func (m *mockCollectionStore) Delete(ctx context.Context, id uuid.UUID) error {
	if _, ok := m.collections[id]; !ok {
		return domaincollection.ErrNotFound
	}
	delete(m.collections, id)
	delete(m.papers, id)
	return nil
}

func (m *mockCollectionStore) AddPaper(ctx context.Context, collectionID, paperID uuid.UUID, note string) error {
	if _, ok := m.collections[collectionID]; !ok {
		return domaincollection.ErrNotFound
	}
	papers := m.papers[collectionID]
	for i, p := range papers {
		if p.PaperID == paperID {
			if note != "" {
				papers[i].Note = note
			}
			return nil
		}
	}
	m.papers[collectionID] = append(papers, domaincollection.CollectionPaper{
		CollectionID: collectionID,
		PaperID:      paperID,
		Paper: research.PaperSummary{
			ID:    paperID,
			Title: "Test Paper",
		},
		Note:     note,
		Position: len(papers),
		AddedAt:  time.Now(),
	})
	return nil
}

func (m *mockCollectionStore) RemovePaper(ctx context.Context, collectionID, paperID uuid.UUID) error {
	papers := m.papers[collectionID]
	filtered := make([]domaincollection.CollectionPaper, 0, len(papers))
	for _, p := range papers {
		if p.PaperID != paperID {
			filtered = append(filtered, p)
		}
	}
	m.papers[collectionID] = filtered
	return nil
}

func (m *mockCollectionStore) ListPapers(ctx context.Context, collectionID uuid.UUID) ([]domaincollection.CollectionPaper, error) {
	return m.papers[collectionID], nil
}

func (m *mockCollectionStore) GetPaperMemberships(ctx context.Context, userID, paperID uuid.UUID) ([]domaincollection.PaperMembership, error) {
	var memberships []domaincollection.PaperMembership
	for _, c := range m.collections {
		if c.UserID == userID {
			contains := false
			note := ""
			for _, p := range m.papers[c.ID] {
				if p.PaperID == paperID {
					contains = true
					note = p.Note
					break
				}
			}
			memberships = append(memberships, domaincollection.PaperMembership{
				CollectionID:   c.ID,
				CollectionName: c.Name,
				Color:          c.Color,
				ContainsPaper:  contains,
				Note:           note,
			})
		}
	}
	return memberships, nil
}

func TestCollectionService_Lifecycle(t *testing.T) {
	store := newMockStore()
	svc := appcollection.NewService(store, nil)
	ctx := context.Background()

	user1 := uuid.New()
	user2 := uuid.New()

	// 1. Create Collection
	col, err := svc.CreateCollection(ctx, domaincollection.CreateInput{
		UserID:      user1,
		Name:        "Attention Is All You Need",
		Description: "Transformers reading list",
		Color:       "#4F46E5",
		IsPublic:    false,
	})
	require.NoError(t, err)
	assert.Equal(t, "Attention Is All You Need", col.Name)
	assert.Equal(t, "#4F46E5", col.Color)

	// 2. Duplicate Name Fails
	_, err = svc.CreateCollection(ctx, domaincollection.CreateInput{
		UserID: user1,
		Name:   "Attention Is All You Need",
	})
	assert.ErrorIs(t, err, domaincollection.ErrDuplicateName)

	// 3. Invalid Name Fails
	_, err = svc.CreateCollection(ctx, domaincollection.CreateInput{
		UserID: user1,
		Name:   "   ",
	})
	assert.ErrorIs(t, err, domaincollection.ErrInvalidInput)

	// 4. Get Collection - Owner succeeds
	got, papers, err := svc.GetCollection(ctx, user1, col.ID)
	require.NoError(t, err)
	assert.Equal(t, col.ID, got.ID)
	assert.Empty(t, papers)

	// 5. Get Collection - Non-owner on private collection returns ErrUnauthorized
	_, _, err = svc.GetCollection(ctx, user2, col.ID)
	assert.ErrorIs(t, err, domaincollection.ErrUnauthorized)

	// 6. Update Collection - Owner succeeds
	newName := "Transformers & LLMs"
	newColor := "#10B981"
	updated, err := svc.UpdateCollection(ctx, user1, col.ID, domaincollection.UpdateInput{
		Name:  &newName,
		Color: &newColor,
	})
	require.NoError(t, err)
	assert.Equal(t, "Transformers & LLMs", updated.Name)
	assert.Equal(t, "#10B981", updated.Color)

	// 7. Update Collection - Non-owner fails
	_, err = svc.UpdateCollection(ctx, user2, col.ID, domaincollection.UpdateInput{
		Name: &newName,
	})
	assert.ErrorIs(t, err, domaincollection.ErrUnauthorized)

	// 8. Add Paper to Collection
	paperID1 := uuid.New()
	paperID2 := uuid.New()
	err = svc.AddPaper(ctx, user1, col.ID, paperID1, "Foundational Transformer architecture")
	require.NoError(t, err)

	err = svc.AddPaper(ctx, user1, col.ID, paperID2, "BERT paper")
	require.NoError(t, err)

	// Non-owner cannot add paper
	err = svc.AddPaper(ctx, user2, col.ID, uuid.New(), "Unauthorized note")
	assert.ErrorIs(t, err, domaincollection.ErrUnauthorized)

	// 9. Verify Papers in Collection
	_, papers, err = svc.GetCollection(ctx, user1, col.ID)
	require.NoError(t, err)
	assert.Len(t, papers, 2)
	assert.Equal(t, paperID1, papers[0].PaperID)
	assert.Equal(t, "Foundational Transformer architecture", papers[0].Note)

	// 10. Check Paper Memberships
	memberships, err := svc.GetPaperMemberships(ctx, user1, paperID1)
	require.NoError(t, err)
	require.Len(t, memberships, 1)
	assert.True(t, memberships[0].ContainsPaper)
	assert.Equal(t, "Foundational Transformer architecture", memberships[0].Note)

	memberships2, err := svc.GetPaperMemberships(ctx, user1, uuid.New())
	require.NoError(t, err)
	require.Len(t, memberships2, 1)
	assert.False(t, memberships2[0].ContainsPaper)

	// 11. Remove Paper from Collection
	err = svc.RemovePaper(ctx, user1, col.ID, paperID1)
	require.NoError(t, err)

	_, papersAfterRemove, err := svc.GetCollection(ctx, user1, col.ID)
	require.NoError(t, err)
	assert.Len(t, papersAfterRemove, 1)
	assert.Equal(t, paperID2, papersAfterRemove[0].PaperID)

	// 12. List Collections
	list, err := svc.ListCollections(ctx, user1)
	require.NoError(t, err)
	assert.Len(t, list, 1)

	// 13. Delete Collection - Non-owner fails
	err = svc.DeleteCollection(ctx, user2, col.ID)
	assert.ErrorIs(t, err, domaincollection.ErrUnauthorized)

	// 14. Delete Collection - Owner succeeds
	err = svc.DeleteCollection(ctx, user1, col.ID)
	require.NoError(t, err)

	_, _, err = svc.GetCollection(ctx, user1, col.ID)
	assert.ErrorIs(t, err, domaincollection.ErrNotFound)
}

func TestCollectionService_ExportCollection(t *testing.T) {
	store := newMockStore()
	exporter := &mockExporter{}
	svc := appcollection.NewService(store, nil).WithExporter(exporter)
	ctx := context.Background()

	user1 := uuid.New()
	user2 := uuid.New()

	col, err := svc.CreateCollection(ctx, domaincollection.CreateInput{
		UserID:      user1,
		Name:        "Graph Neural Networks",
		Description: "Key papers",
		IsPublic:    false,
	})
	require.NoError(t, err)

	err = svc.AddPaper(ctx, user1, col.ID, uuid.New(), "GCN baseline")
	require.NoError(t, err)

	// Owner can export
	content, contentType, err := svc.ExportCollection(ctx, user1, col.ID, domainexport.FormatBibTeX)
	require.NoError(t, err)
	assert.Contains(t, content, "@article{mock")
	assert.Equal(t, "application/x-bibtex; charset=utf-8", contentType)

	// Non-owner cannot export private collection
	_, _, err = svc.ExportCollection(ctx, user2, col.ID, domainexport.FormatBibTeX)
	assert.ErrorIs(t, err, domaincollection.ErrUnauthorized)

	// Public collection can be exported by anyone
	isPublic := true
	_, err = svc.UpdateCollection(ctx, user1, col.ID, domaincollection.UpdateInput{
		IsPublic: &isPublic,
	})
	require.NoError(t, err)

	content, _, err = svc.ExportCollection(ctx, user2, col.ID, domainexport.FormatBibTeX)
	require.NoError(t, err)
	assert.Contains(t, content, "@article{mock")
}

