package textextract

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"strings"

	domainai "athena/backend/internal/domain/ai"
)

// CompositeExtractor automatically detects content format (PDF vs HTML vs plain text)
// and routes to the appropriate specialized extractor.
type CompositeExtractor struct {
	pdf  *PDFExtractor
	html *HTMLExtractor
}

// New creates a unified CompositeExtractor supporting both PDF and Web/HTML full text.
func New() *CompositeExtractor {
	return &CompositeExtractor{
		pdf:  NewPDFExtractor(),
		html: NewHTMLExtractor(),
	}
}

var _ domainai.TextExtractor = (*CompositeExtractor)(nil)

func (c *CompositeExtractor) Extract(ctx context.Context, r io.Reader) (string, error) {
	data, err := io.ReadAll(io.LimitReader(r, MaxBytes))
	if err != nil {
		return "", fmt.Errorf("read document stream: %w", err)
	}

	if len(data) == 0 {
		return "", fmt.Errorf("document stream is empty")
	}

	// Sniff document format:
	// 1. PDF magic bytes %PDF
	if bytes.HasPrefix(data, []byte("%PDF")) || bytes.Contains(data[:min(len(data), 1024)], []byte("%PDF-")) {
		return c.pdf.Extract(ctx, bytes.NewReader(data))
	}

	// 2. HTML inspection
	sample := strings.ToLower(string(data[:min(len(data), 2048)]))
	if strings.Contains(sample, "<!doctype html") ||
		strings.Contains(sample, "<html") ||
		strings.Contains(sample, "<article") ||
		strings.Contains(sample, "<body") ||
		strings.Contains(sample, "<head") {
		return c.html.Extract(ctx, bytes.NewReader(data))
	}

	// 3. Fallback: try PDF first; if that errors, try HTML
	text, pdfErr := c.pdf.Extract(ctx, bytes.NewReader(data))
	if pdfErr == nil && len(text) >= 200 {
		return text, nil
	}

	htmlText, htmlErr := c.html.Extract(ctx, bytes.NewReader(data))
	if htmlErr == nil && len(htmlText) >= 200 {
		return htmlText, nil
	}

	return "", fmt.Errorf("unrecognized document format or insufficient text: pdf error: %v, html error: %v", pdfErr, htmlErr)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
