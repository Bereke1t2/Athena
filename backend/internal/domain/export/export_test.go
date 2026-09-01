package export_test

import (
	"strings"
	"testing"

	"github.com/google/uuid"

	domainexport "athena/backend/internal/domain/export"
	"athena/backend/internal/domain/research"
)

func samplePaper() research.PaperDetail {
	abstract := "This is a seminal paper introducing transformers."
	return research.PaperDetail{
		Summary: research.PaperSummary{
			ID:              uuid.MustParse("00000000-0000-0000-0000-000000000001"),
			Title:           "Attention Is All You Need",
			Abstract:        &abstract,
			Year:            2017,
			VenueName:       "NeurIPS",
			PublicationType: research.PubTypeConferencePaper,
		},
		DOI:     "10.1145/3132847.3132886",
		ArxivID: "1706.03762",
		Authors: []research.AuthorLine{
			{Name: "Ashish Vaswani"},
			{Name: "Noam Shazeer"},
		},
	}
}

func TestExportFormats(t *testing.T) {
	p := samplePaper()

	// BibTeX
	bib, err := domainexport.FormatPaper(p, domainexport.FormatBibTeX)
	if err != nil {
		t.Fatalf("Format BibTeX failed: %v", err)
	}
	if !strings.Contains(bib, "@inproceedings") || !strings.Contains(bib, "title = {Attention Is All You Need}") {
		t.Fatalf("unexpected BibTeX output:\n%s", bib)
	}

	// RIS
	ris, err := domainexport.FormatPaper(p, domainexport.FormatRIS)
	if err != nil {
		t.Fatalf("Format RIS failed: %v", err)
	}
	if !strings.Contains(ris, "TY  - JOUR") || !strings.Contains(ris, "TI  - Attention Is All You Need") {
		t.Fatalf("unexpected RIS output:\n%s", ris)
	}

	// APA
	apa, err := domainexport.FormatPaper(p, domainexport.FormatAPA)
	if err != nil {
		t.Fatalf("Format APA failed: %v", err)
	}
	if !strings.Contains(apa, "Ashish Vaswani & Noam Shazeer (2017). Attention Is All You Need.") {
		t.Fatalf("unexpected APA output:\n%s", apa)
	}

	// MLA
	mla, err := domainexport.FormatPaper(p, domainexport.FormatMLA)
	if err != nil {
		t.Fatalf("Format MLA failed: %v", err)
	}
	if !strings.Contains(mla, "Ashish Vaswani, et al. \"Attention Is All You Need.\"") {
		t.Fatalf("unexpected MLA output:\n%s", mla)
	}

	// Markdown
	md, err := domainexport.FormatPaper(p, domainexport.FormatMarkdown)
	if err != nil {
		t.Fatalf("Format Markdown failed: %v", err)
	}
	if !strings.Contains(md, "# Attention Is All You Need") || !strings.Contains(md, "## Abstract") {
		t.Fatalf("unexpected Markdown output:\n%s", md)
	}

	// Unsupported
	_, err = domainexport.FormatPaper(p, domainexport.Format("unknown"))
	if err == nil {
		t.Fatalf("expected error for unsupported format")
	}
}
