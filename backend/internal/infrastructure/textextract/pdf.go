// Package textextract implements the ai.TextExtractor port. The MVP adapter
// pulls plain text from PDFs (the dominant open-access format); a GROBID
// service can replace it behind the same port later.
package textextract

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"strings"

	pdf "github.com/ledongthuc/pdf"

	domainai "athena/backend/internal/domain/ai"
)

// MaxBytes caps document size before parsing (20 MiB default guard).
const MaxBytes = 20 << 20

// PDFExtractor implements ai.TextExtractor for PDF streams.
type PDFExtractor struct{}

// NewPDFExtractor builds a dedicated PDF text extractor.
func NewPDFExtractor() *PDFExtractor { return &PDFExtractor{} }

var _ domainai.TextExtractor = (*PDFExtractor)(nil)

// Extract reads the whole stream and concatenates per-page plain text.
// Scanned/image-only PDFs yield near-empty text and fail honestly so callers
// keep the paper metadata-only instead of storing junk chunks.
func (p *PDFExtractor) Extract(_ context.Context, r io.Reader) (string, error) {
	data, err := io.ReadAll(io.LimitReader(r, MaxBytes))
	if err != nil {
		return "", fmt.Errorf("read pdf: %w", err)
	}

	reader, err := pdf.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return "", fmt.Errorf("open pdf: %w", err)
	}

	var b strings.Builder
	n := reader.NumPage()
	for i := 1; i <= n; i++ {
		page := reader.Page(i)
		if page.V.IsNull() {
			continue
		}
		text, err := page.GetPlainText(nil)
		if err != nil {
			continue // tolerate single broken pages
		}
		b.WriteString(text)
		b.WriteByte('\n')
	}
	out := strings.TrimSpace(b.String())
	if len(out) < 200 { // effectively no extractable text
		return "", fmt.Errorf("pdf yielded too little text (%d chars): likely scanned images", len(out))
	}
	return out, nil
}
