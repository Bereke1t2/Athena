package database

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

func TestPaperStore_ResolveFieldID(t *testing.T) {
	csID := uuid.New()
	physicsID := uuid.New()

	store := &PaperStore{
		fieldIDs: map[string]uuid.UUID{
			"computer-science":      csID,
			"physics-and-astronomy": physicsID,
		},
	}

	ctx := context.Background()

	// 1. Topic maps to Computer Science
	csResolved := store.resolveFieldID(ctx, "Convolutional Neural Networks", "cnn")
	assert.NotNil(t, csResolved)
	assert.Equal(t, csID, *csResolved)

	// 2. Topic maps to Physics
	physResolved := store.resolveFieldID(ctx, "Quantum Entanglement", "quantum-entanglement")
	assert.NotNil(t, physResolved)
	assert.Equal(t, physicsID, *physResolved)

	// 3. Topic is itself a canonical field -> must not assign itself as parent
	selfField := store.resolveFieldID(ctx, "Computer Science", "computer-science")
	assert.Nil(t, selfField)

	// 4. Unknown topic -> returns nil without error
	unknown := store.resolveFieldID(ctx, "Arbitrary Mystery X99", "mystery-x99")
	assert.Nil(t, unknown)
}
