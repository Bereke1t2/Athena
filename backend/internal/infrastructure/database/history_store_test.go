package database

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestHistoryCursorRoundTrip(t *testing.T) {
	now := time.Now().UTC().Truncate(time.Microsecond)
	paperID := uuid.New()

	c := historyCursor{
		V:        1,
		LastRead: now,
		PaperID:  paperID,
	}

	tok := encodeHistoryCursor(c)
	decoded, err := decodeHistoryCursor(tok)
	if err != nil {
		t.Fatalf("decode failed: %v", err)
	}

	if decoded.V != 1 || !decoded.LastRead.Equal(now) || decoded.PaperID != paperID {
		t.Fatalf("cursor mismatch: expected %+v, got %+v", c, decoded)
	}

	// Invalid version or malformed
	if _, err := decodeHistoryCursor("invalid-base64"); err == nil {
		t.Fatalf("expected error for invalid base64")
	}
}
