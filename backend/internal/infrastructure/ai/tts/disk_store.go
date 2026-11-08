package tts

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sync"
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
