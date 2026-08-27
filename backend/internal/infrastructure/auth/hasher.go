// Package auth provides the production PasswordHasher: PBKDF2-SHA256 from
// the Go standard library, stored in a self-describing
// $pbkdf2-sha256$<iterations>$<salt>$<digest> format so iteration counts can
// rise over time without re-hashing every account at once.
package auth

import (
	"crypto/pbkdf2"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"fmt"
	"strconv"
	"strings"
)

const (
	defaultIterations = 600_000
	saltBytes         = 16
	digestBytes       = 32
	hashPrefix        = "$pbkdf2-sha256$"
)

// Hasher derives and verifies PBKDF2 password hashes. Iterations applies to
// newly created hashes; existing hashes keep whatever their embedded count
// specifies.
type Hasher struct {
	Iterations int
}

func NewHasher() *Hasher { return &Hasher{Iterations: defaultIterations} }

func (h *Hasher) iterations() int {
	if h.Iterations > 0 {
		return h.Iterations
	}
	return defaultIterations
}

// Hash produces an encoded hash string for storage.
func (h *Hasher) Hash(password string) (string, error) {
	salt := make([]byte, saltBytes)
	if _, err := rand.Read(salt); err != nil {
		return "", fmt.Errorf("pbkdf2 salt entropy: %w", err)
	}
	key, err := pbkdf2.Key(sha256.New, password, salt, h.iterations(), digestBytes)
	if err != nil {
		return "", fmt.Errorf("pbkdf2 derive: %w", err)
	}
	return fmt.Sprintf("%s%d$%s$%s", hashPrefix, h.iterations(),
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(key)), nil
}

// Verify reports whether password matches the encoded hash. Malformed or
// foreign-format hashes fail closed with false rather than erroring so the
// login path stays uniform.
func (h *Hasher) Verify(encoded, password string) bool {
	if !strings.HasPrefix(encoded, hashPrefix) {
		return false
	}
	parts := strings.Split(strings.TrimPrefix(encoded, hashPrefix), "$")
	if len(parts) != 3 {
		return false
	}
	iter, err := strconv.Atoi(parts[0])
	if err != nil || iter < 1 || iter > 10_000_000 {
		return false
	}
	salt, err := base64.RawStdEncoding.DecodeString(parts[1])
	if err != nil {
		return false
	}
	want, err := base64.RawStdEncoding.DecodeString(parts[2])
	if err != nil || len(want) == 0 {
		return false
	}
	got, err := pbkdf2.Key(sha256.New, password, salt, iter, len(want))
	if err != nil {
		return false
	}
	// Constant-time comparison regardless of match outcome.
	return subtle.ConstantTimeCompare(got, want) == 1
}
