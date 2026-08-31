package textextract

import (
	"context"
	"fmt"
	"html"
	"io"
	"regexp"
	"strings"

	domainai "athena/backend/internal/domain/ai"
)

var (
	// Elements to completely drop including their inner content
	dropTagRegexes = []*regexp.Regexp{
		regexp.MustCompile(`(?is)<script[^>]*>.*?</script>`),
		regexp.MustCompile(`(?is)<style[^>]*>.*?</style>`),
		regexp.MustCompile(`(?is)<svg[^>]*>.*?</svg>`),
		regexp.MustCompile(`(?is)<noscript[^>]*>.*?</noscript>`),
		regexp.MustCompile(`(?is)<nav[^>]*>.*?</nav>`),
		regexp.MustCompile(`(?is)<header[^>]*>.*?</header>`),
		regexp.MustCompile(`(?is)<footer[^>]*>.*?</footer>`),
		regexp.MustCompile(`(?is)<aside[^>]*>.*?</aside>`),
		regexp.MustCompile(`(?is)<form[^>]*>.*?</form>`),
		regexp.MustCompile(`(?is)<iframe[^>]*>.*?</iframe>`),
	}
	dropSingleTagsRe = regexp.MustCompile(`(?is)<(script|style|svg|noscript|nav|header|footer|aside|form|iframe)[^>]*/>`)

	// Block tags to convert to newlines / headings
	h1h2Re    = regexp.MustCompile(`(?is)<h[1-2][^>]*>(.*?)</h[1-2]>`)
	h3h6Re    = regexp.MustCompile(`(?is)<h[3-6][^>]*>(.*?)</h[3-6]>`)
	pBlockRe  = regexp.MustCompile(`(?is)<p[^>]*>(.*?)</p>`)
	liBlockRe = regexp.MustCompile(`(?is)<li[^>]*>(.*?)</li>`)
	brRe      = regexp.MustCompile(`(?i)<br\s*/?>`)
	tagRe     = regexp.MustCompile(`(?is)<[^>]+>`)
	spacesRe  = regexp.MustCompile(`[ \t\r\f]+`)
	multiNlRe = regexp.MustCompile(`\n{3,}`)
)

// HTMLExtractor extracts clean structured plain text from Open Access academic HTML pages
// (e.g. PubMed Central, Ar5iv, PLOS, Frontiers, and publisher OA articles).
type HTMLExtractor struct{}

func NewHTMLExtractor() *HTMLExtractor {
	return &HTMLExtractor{}
}

var _ domainai.TextExtractor = (*HTMLExtractor)(nil)

func (h *HTMLExtractor) Extract(_ context.Context, r io.Reader) (string, error) {
	data, err := io.ReadAll(io.LimitReader(r, MaxBytes))
	if err != nil {
		return "", fmt.Errorf("read html: %w", err)
	}

	raw := string(data)
	if len(raw) == 0 {
		return "", fmt.Errorf("empty html payload")
	}

	// 1. Try to extract main content area if available
	mainContent := extractMainBody(raw)

	// 2. Strip scripts, styles, navbars, ads
	cleaned := mainContent
	for _, re := range dropTagRegexes {
		cleaned = re.ReplaceAllString(cleaned, "")
	}
	cleaned = dropSingleTagsRe.ReplaceAllString(cleaned, "")

	// 3. Format headings and blocks into clean text layout
	cleaned = h1h2Re.ReplaceAllString(cleaned, "\n\n## $1\n\n")
	cleaned = h3h6Re.ReplaceAllString(cleaned, "\n\n### $1\n\n")
	cleaned = pBlockRe.ReplaceAllString(cleaned, "\n\n$1\n\n")
	cleaned = liBlockRe.ReplaceAllString(cleaned, "\n• $1\n")
	cleaned = brRe.ReplaceAllString(cleaned, "\n")

	// 4. Strip all remaining HTML tags
	cleaned = tagRe.ReplaceAllString(cleaned, " ")

	// 5. Decode HTML entities (&amp;, &nbsp;, etc.)
	cleaned = html.UnescapeString(cleaned)

	// 6. Clean whitespace and line endings
	lines := strings.Split(cleaned, "\n")
	var out []string
	for _, ln := range lines {
		trimmed := strings.TrimSpace(spacesRe.ReplaceAllString(ln, " "))
		if trimmed != "" {
			out = append(out, trimmed)
		}
	}

	result := strings.Join(out, "\n")
	result = multiNlRe.ReplaceAllString(result, "\n\n")
	result = strings.TrimSpace(result)

	if len(result) < 200 {
		return "", fmt.Errorf("html yielded too little text (%d chars): likely paywalled, empty or blocked", len(result))
	}

	return result, nil
}

// extractMainBody targets standard academic article containers (Ar5iv, PMC, PLOS, etc.)
func extractMainBody(s string) string {
	// Ar5iv format: <article class="ltx_document">
	if idx := strings.Index(s, `class="ltx_document"`); idx > 0 {
		if start := strings.LastIndex(s[:idx], "<article"); start >= 0 {
			if end := strings.LastIndex(s, "</article>"); end > start {
				return s[start : end+10]
			}
		}
	}

	// PMC / standard <article> tag
	if start := strings.Index(s, "<article"); start >= 0 {
		if end := strings.LastIndex(s, "</article>"); end > start {
			return s[start : end+10]
		}
	}

	// <main> tag
	if start := strings.Index(s, "<main"); start >= 0 {
		if end := strings.LastIndex(s, "</main>"); end > start {
			return s[start : end+7]
		}
	}

	// <div role="main"> or <div class="c-article-body"> or <div id="body">
	for _, marker := range []string{`role="main"`, `class="c-article-body"`, `id="article-body"`, `class="article-body"`} {
		if idx := strings.Index(s, marker); idx > 0 {
			if start := strings.LastIndex(s[:idx], "<div"); start >= 0 {
				if end := strings.LastIndex(s, "</div>"); end > start {
					return s[start : end+6]
				}
			}
		}
	}

	// Fall back to <body>
	if start := strings.Index(s, "<body"); start >= 0 {
		if end := strings.LastIndex(s, "</body>"); end > start {
			return s[start : end+7]
		}
	}

	return s
}
