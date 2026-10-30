package tts

import (
	"context"
	"sync"

	domainaudio "athena/backend/internal/domain/audio"
)

// MemoryMediaStore provides an in-memory thread-safe audio cache.
type MemoryMediaStore struct {
	mu    sync.RWMutex
	store map[string][]byte
}

func NewMemoryMediaStore() *MemoryMediaStore {
	return &MemoryMediaStore{
		store: make(map[string][]byte),
	}
}

func (m *MemoryMediaStore) SaveAudio(_ context.Context, key string, data []byte) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	copied := make([]byte, len(data))
	copy(copied, data)
	m.store[key] = copied
	return nil
}

func (m *MemoryMediaStore) GetAudio(_ context.Context, key string) ([]byte, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	data, ok := m.store[key]
	if !ok || len(data) == 0 {
		return nil, domainaudio.ErrAudioNotFound
	}
	out := make([]byte, len(data))
	copy(out, data)
	return out, nil
}
