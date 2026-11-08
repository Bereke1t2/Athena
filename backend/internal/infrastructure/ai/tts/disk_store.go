package tts

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sync"
	"time"

	domainaudio "athena/backend/internal/domain/audio"
)

var safeKeyPattern = regexp.MustCompile(`[^a-zA-Z0-9_\-]`)

// DiskMediaStore persists binary audio files to a designated filesystem directory.
type DiskMediaStore struct {
	baseDir string
	mu      sync.RWMutex
}

// NewDiskMediaStore constructs a DiskMediaStore that stores audio tracks under baseDir.
// It creates baseDir if it does not already exist.
func NewDiskMediaStore(baseDir string) (*DiskMediaStore, error) {
	if baseDir == "" {
		return nil, fmt.Errorf("audio directory cannot be empty")
	}
	cleanDir := filepath.Clean(baseDir)
	if err := os.MkdirAll(cleanDir, 0755); err != nil {
		return nil, fmt.Errorf("create audio directory: %w", err)
	}
	return &DiskMediaStore{baseDir: cleanDir}, nil
}

// BaseDir returns the root directory where audio tracks are persisted.
func (d *DiskMediaStore) BaseDir() string {
	return d.baseDir
}

func (d *DiskMediaStore) filePath(key string) string {
	safeKey := safeKeyPattern.ReplaceAllString(key, "_")
	return filepath.Join(d.baseDir, safeKey+".mp3")
}

// SaveAudio saves binary audio track bytes to disk atomically.
func (d *DiskMediaStore) SaveAudio(_ context.Context, key string, data []byte) error {
	if len(data) == 0 {
		return fmt.Errorf("cannot save empty audio track")
	}

	d.mu.Lock()
	defer d.mu.Unlock()

	targetPath := d.filePath(key)
	tempPath := fmt.Sprintf("%s.tmp.%d", targetPath, time.Now().UnixNano())

	if err := os.WriteFile(tempPath, data, 0644); err != nil {
		return fmt.Errorf("write temporary audio file: %w", err)
	}

	if err := os.Rename(tempPath, targetPath); err != nil {
		_ = os.Remove(tempPath)
		return fmt.Errorf("rename temporary audio file: %w", err)
	}

	return nil
}

// GetAudio retrieves binary audio track bytes from disk.
func (d *DiskMediaStore) GetAudio(_ context.Context, key string) ([]byte, error) {
	d.mu.RLock()
	defer d.mu.RUnlock()

	targetPath := d.filePath(key)
	data, err := os.ReadFile(targetPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, domainaudio.ErrAudioNotFound
		}
		return nil, fmt.Errorf("read audio file: %w", err)
	}

	if len(data) == 0 {
		return nil, domainaudio.ErrAudioNotFound
	}

	return data, nil
}
