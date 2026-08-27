package database

import "testing"

func TestSanitizeTokens(t *testing.T) {
	got := sanitizeTokens("research about whether consciousness can emerge from artificial systems")
	if len(got) != 9 || got[0] != "research" || got[8] != "systems" {
		t.Fatalf("unexpected tokens: %v", got)
	}
	if got := sanitizeTokens("  ,.(hello-world) 42! "); len(got) != 3 || got[0] != "hello" || got[2] != "42" {
		t.Fatalf("punctuation not stripped: %v", got)
	}
	if got := sanitizeTokens("!!!"); got != nil && len(got) != 0 {
		t.Fatalf("expected no tokens, got %v", got)
	}
}
