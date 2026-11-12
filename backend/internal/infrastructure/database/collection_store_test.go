package database_test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	domaincollection "athena/backend/internal/domain/collection"
	"athena/backend/internal/infrastructure/database"
)

func TestCollectionStore_InterfaceConformance(t *testing.T) {
	var _ domaincollection.Store = (*database.CollectionStore)(nil)
}

func TestNewCollectionStore(t *testing.T) {
	store := database.NewCollectionStore(nil)
	assert.NotNil(t, store)
}
