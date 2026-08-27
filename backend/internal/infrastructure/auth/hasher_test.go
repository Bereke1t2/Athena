package auth

import "testing"

func TestHashVerifyRoundTrip(t *testing.T) {
	h := NewHasher()
	encoded, err := h.Hash("correct horse battery staple")
	if err != nil {
		t.Fatal(err)
	}
	if !h.Verify(encoded, "correct horse battery staple") {
		t.Fatal("verify failed for correct password")
	}
	if h.Verify(encoded, "wrong password") {
		t.Fatal("verify accepted wrong password")
	}
}

func TestHashFormatIsSelfDescribing(t *testing.T) {
	h := &Hasher{Iterations: 1000}
	encoded, err := h.Hash("pw")
	if err != nil {
		t.Fatal(err)
	}
	want := "$pbkdf2-sha256$1000$"
	if len(encoded) < len(want) || encoded[:len(want)] != want {
		t.Fatalf("encoded hash missing prefix/iterations: %q", encoded)
	}
	if !NewHasher().Verify(encoded, "pw") {
		t.Fatal("hash not portable across hasher configurations")
	}
}

func TestVerifyMalformedFailsClosed(t *testing.T) {
	h := NewHasher()
	for _, bad := range []string{
		"",
		"bcrypt$saltandhash",
		"$pbkdf2-sha256$notanumber$c2FsdA$aGFzaA",
		"$pbkdf2-sha256$99999999999$c2FsdA$aGFzaA",
		"$pbkdf2-sha256$1000$!!!not-base64!!!$aGFzaA",
	} {
		if h.Verify(bad, "anything") {
			t.Errorf("malformed hash accepted: %q", bad)
		}
	}
}

func TestUniqueSalts(t *testing.T) {
	h := NewHasher()
	a, _ := h.Hash("same-password")
	b, _ := h.Hash("same-password")
	if a == b {
		t.Fatal("two hashes of the same password are identical (salt reuse?)")
	}
}
