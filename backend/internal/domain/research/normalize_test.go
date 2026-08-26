package research

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNormalizeTitle(t *testing.T) {
	cases := []struct{ in, want string }{
		{"Scaling Laws for Neural Language Models", "scaling laws for neural language models"},
		{"  Attention   Is All You NEED!! ", "attention is all you need"},
		{"Café au Lait: Émile's Résumé", "cafe au lait emile s resume"},
		{"Self-Supervision (v2): a survey", "self supervision v2 a survey"},
		{"", ""},
		{"\t\n", ""},
	}
	for _, c := range cases {
		assert.Equal(t, c.want, NormalizeTitle(c.in), "input %q", c.in)
	}
}

func TestCanonicalizeDOI(t *testing.T) {
	cases := []struct{ in, want string }{
		{"10.1234/Foo.Bar_42", "10.1234/foo.bar_42"},
		{"https://doi.org/10.5555/123456", "10.5555/123456"},
		{"http://dx.doi.org/10.5555/789", "10.5555/789"},
		{"doi:10.1/abc", "10.1/abc"},
		{"doi:", ""},
		{"not-a-doi", ""},
		{"", ""},
	}
	for _, c := range cases {
		assert.Equal(t, c.want, CanonicalizeDOI(c.in), "input %q", c.in)
	}
}

func TestCanonicalizeArxivID(t *testing.T) {
	cases := []struct{ in, want string }{
		{"2312.00752", "2312.00752"},
		{"2312.00752v3", "2312.00752"},
		{"https://arxiv.org/abs/2401.12345", "2401.12345"},
		{"https://arxiv.org/pdf/2005.14165v2.pdf", "2005.14165"},
		{"arXiv:cs.CL/0301012", ""}, // old-style with subject class is cs/0301012
		{"cs/0301012", "cs/0301012"},
		{"garbage", ""},
	}
	for _, c := range cases {
		assert.Equal(t, c.want, CanonicalizeArxivID(c.in), "input %q", c.in)
	}
}

func TestFingerprintStableAndSensitive(t *testing.T) {
	base := Fingerprint("Attention Is All You Need!", "Jane Doe", 2017)
	same := Fingerprint("ATTENTION is ALL you NEED", "John doe", 2017)
	diffYear := Fingerprint("Attention is all you need", "Jane Doe", 2018)
	diffAuthor := Fingerprint("Attention is all you need", "Someone Else", 2017)

	assert.Equal(t, base, same, "normalization should equalize case/punctuation")
	assert.NotEqual(t, base, diffYear)
	assert.NotEqual(t, base, diffAuthor)
}

func TestFingerprintWithoutAuthors(t *testing.T) {
	a := Fingerprint("Anonymous Title", "", 2020)
	b := Fingerprint("anonymous title", "", 2020)
	assert.Equal(t, a, b)
}

func TestDeriveIdentityFillsFields(t *testing.T) {
	p := &Paper{
		Title: "Über Learning to Learn",
		Identifiers: []Identifier{
			{Type: IDTypeDOI, Value: "HTTPS://doi.org/10.1000/Zen"},
			{Type: IDTypeArxiv, Value: "2401.00001v2"},
			{Type: IDTypeOpenAlex, Value: "W123"},
			{Type: IDTypeOpenAlex, Value: "W123"}, // duplicate dropped
		},
	}
	DeriveIdentity(p)
	assert.Equal(t, "uber learning to learn", p.TitleNormalized)
	assert.Equal(t, "10.1000/zen", p.DOI())
	assert.Equal(t, "2401.00001", p.ArxivID())
	assert.Len(t, p.Identifiers, 3)
	assert.NotEmpty(t, p.Fingerprint)
}

func TestOpenAccessIsOpen(t *testing.T) {
	for _, s := range []OAStatus{OAStatusGold, OAStatusGreen, OAStatusHybrid, OAStatusBronze} {
		assert.True(t, OpenAccess{Status: s}.IsOpen(), string(s))
	}
	assert.False(t, OpenAccess{Status: OAStatusClosed}.IsOpen())
	assert.False(t, OpenAccess{Status: OAStatusUnknown}.IsOpen())
}
