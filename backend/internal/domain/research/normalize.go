package research

import (
	"crypto/sha256"
	"encoding/hex"
	"regexp"
	"strconv"
	"strings"
	"unicode"

	"golang.org/x/text/unicode/norm"
)

var (
	spaceRe      = regexp.MustCompile(`\s+`)
	doiPrefixRe  = regexp.MustCompile(`(?i)^(?:https?://(?:dx\.)?doi\.org/|doi:)`)
	arxivURLRe   = regexp.MustCompile(`(?i)^(?:https?://arxiv\.org/(?:abs|pdf)/|arxiv:)`)
	arxivIDRe    = regexp.MustCompile(`^(\d{4}\.\d{4,5}|[a-z-]+/\d{7})(v\d+)?$`)
	arxivVersion = regexp.MustCompile(`v\d+$`)
	pdfSuffix    = regexp.MustCompile(`(?i)\.pdf$`)
)

// NormalizeTitle canonicalizes a title for matching and fingerprinting:
// lowercase, Unicode NFKD fold, diacritic stripping, punctuation → space,
// whitespace collapse.
func NormalizeTitle(s string) string {
	return normalizeText(s)
}

// NormalizePersonName applies the same canonicalization used for author
// matching.
func NormalizePersonName(s string) string {
	return normalizeText(s)
}

func normalizeText(s string) string {
	decomposed := norm.NFKD.String(strings.ToLower(strings.TrimSpace(s)))
	var b strings.Builder
	b.Grow(len(decomposed))
	for _, r := range decomposed {
		if unicode.Is(unicode.Mn, r) {
			continue
		}
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			b.WriteRune(r)
		} else {
			b.WriteRune(' ')
		}
	}
	return strings.TrimSpace(spaceRe.ReplaceAllString(b.String(), " "))
}

// CanonicalizeDOI normalizes a DOI to bare lowercase form ("10.1234/foo"),
// stripping URL and "doi:" prefixes. Returns "" when the input does not look
// like a DOI.
func CanonicalizeDOI(s string) string {
	cleaned := strings.ToLower(strings.TrimSpace(doiPrefixRe.ReplaceAllString(strings.TrimSpace(s), "")))
	if !strings.HasPrefix(cleaned, "10.") || len(cleaned) < 8 {
		return ""
	}
	return cleaned
}

// CanonicalizeArxivID reduces any arXiv identifier spelling to the modern base
// form without version suffix ("2312.00752"). Returns "" when invalid.
func CanonicalizeArxivID(s string) string {
	base := arxivVersion.ReplaceAllString(pdfSuffix.ReplaceAllString(
		arxivURLRe.ReplaceAllString(strings.TrimSpace(s), ""), ""), "")
	base = strings.TrimPrefix(base, "arXiv:")
	base = strings.ToLower(base)
	if !arxivIDRe.MatchString(base) {
		return ""
	}
	return base
}

// Fingerprint derives a conservative duplicate-detection key from normalized
// title, lead-author surname and publication year. A shared fingerprint makes
// two papers merge *candidates* only; ResolveTarget decides the outcome.
func Fingerprint(title string, leadAuthorDisplayName string, year int) string {
	surname := "noauthor"
	if fields := strings.Fields(leadAuthorDisplayName); len(fields) > 0 {
		if n := normalizeText(fields[len(fields)-1]); n != "" {
			surname = n
		}
	}
	yearToken := strconv.Itoa(year)
	if year <= 0 {
		yearToken = "unknown"
	}
	sum := sha256.Sum256([]byte(strings.Join([]string{NormalizeTitle(title), surname, yearToken}, "\x1f")))
	return hex.EncodeToString(sum[:])
}

// DeriveIdentity fills TitleNormalized and Fingerprint on a paper and
// canonicalizes its identifiers. Provider adapters call this after mapping
// their payloads.
func DeriveIdentity(p *Paper) {
	p.TitleNormalized = NormalizeTitle(p.Title)
	lead := ""
	if len(p.Authors) > 0 {
		lead = p.Authors[0].DisplayName
	}
	p.Fingerprint = Fingerprint(p.Title, lead, p.Year)
	p.Identifiers = CanonicalIdentifiers(p.Identifiers)
}

// CanonicalIdentifiers deduplicates identifiers, canonicalizing DOI/arXiv
// values; invalid ones are dropped.
func CanonicalIdentifiers(in []Identifier) []Identifier {
	seen := make(map[Identifier]struct{}, len(in))
	out := make([]Identifier, 0, len(in))
	add := func(t IdentifierType, v string) {
		v = strings.TrimSpace(v)
		if v == "" {
			return
		}
		id := Identifier{Type: t, Value: v}
		if _, dup := seen[id]; dup {
			return
		}
		seen[id] = struct{}{}
		out = append(out, id)
	}
	for _, id := range in {
		switch id.Type {
		case IDTypeDOI:
			add(IDTypeDOI, CanonicalizeDOI(id.Value))
		case IDTypeArxiv:
			add(IDTypeArxiv, CanonicalizeArxivID(id.Value))
		default:
			add(id.Type, id.Value)
		}
	}
	return out
}
