// Package export defines citation and bibliography export formatters for research papers.
package export

import (
	"errors"
	"fmt"
	"strings"

	"athena/backend/internal/domain/research"
)

var (
	// ErrUnsupportedFormat is returned when an unrecognized export format is requested.
	ErrUnsupportedFormat = errors.New("export: unsupported format")
)

// Format enumerates supported citation export formats.
type Format string

const (
	FormatBibTeX   Format = "bibtex"
	FormatRIS      Format = "ris"
	FormatAPA      Format = "apa"
	FormatMLA      Format = "mla"
	FormatMarkdown Format = "markdown"
)

// ContentType returns the MIME type for the format.
func (f Format) ContentType() string {
	switch f {
	case FormatBibTeX:
		return "application/x-bibtex; charset=utf-8"
	case FormatRIS:
		return "application/x-research-info-systems; charset=utf-8"
	case FormatMarkdown:
		return "text/markdown; charset=utf-8"
	default:
		return "text/plain; charset=utf-8"
	}
}

// FormatPaper exports a single paper detail to the desired citation format.
func FormatPaper(p research.PaperDetail, format Format) (string, error) {
	switch format {
	case FormatBibTeX:
		return toBibTeX(p), nil
	case FormatRIS:
		return toRIS(p), nil
	case FormatAPA:
		return toAPA(p), nil
	case FormatMLA:
		return toMLA(p), nil
	case FormatMarkdown:
		return toMarkdown(p), nil
	default:
		return "", fmt.Errorf("%w: %s", ErrUnsupportedFormat, format)
	}
}

func sanitizeKey(s string) string {
	fields := strings.Fields(s)
	if len(fields) == 0 {
		return "paper"
	}
	first := strings.ToLower(fields[0])
	var clean strings.Builder
	for _, r := range first {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			clean.WriteRune(r)
		}
	}
	if clean.Len() == 0 {
		return "paper"
	}
	return clean.String()
}

func toBibTeX(p research.PaperDetail) string {
	firstAuthor := "author"
	if len(p.Authors) > 0 {
		firstAuthor = sanitizeKey(p.Authors[0].Name)
	}
	year := p.Summary.Year
	if year == 0 {
		year = 2026
	}
	citeKey := fmt.Sprintf("%s%d%s", firstAuthor, year, sanitizeKey(p.Summary.Title))

	authorNames := make([]string, 0, len(p.Authors))
	for _, a := range p.Authors {
		authorNames = append(authorNames, a.Name)
	}
	authorsJoined := strings.Join(authorNames, " and ")
	if authorsJoined == "" {
		authorsJoined = "Anonymous"
	}

	entryType := "article"
	if p.Summary.PublicationType == research.PubTypeConferencePaper {
		entryType = "inproceedings"
	}

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("@%s{%s,\n", entryType, citeKey))
	sb.WriteString(fmt.Sprintf("  title = {%s},\n", p.Summary.Title))
	sb.WriteString(fmt.Sprintf("  author = {%s},\n", authorsJoined))
	sb.WriteString(fmt.Sprintf("  year = {%d},\n", year))
	if p.Summary.VenueName != "" {
		if entryType == "inproceedings" {
			sb.WriteString(fmt.Sprintf("  booktitle = {%s},\n", p.Summary.VenueName))
		} else {
			sb.WriteString(fmt.Sprintf("  journal = {%s},\n", p.Summary.VenueName))
		}
	}
	if p.DOI != "" {
		sb.WriteString(fmt.Sprintf("  doi = {%s},\n", p.DOI))
	}
	if p.ArxivID != "" {
		sb.WriteString(fmt.Sprintf("  eprint = {%s},\n  archivePrefix = {arXiv},\n", p.ArxivID))
	}
	sb.WriteString("}\n")
	return sb.String()
}

func toRIS(p research.PaperDetail) string {
	var sb strings.Builder
	sb.WriteString("TY  - JOUR\n")
	sb.WriteString(fmt.Sprintf("TI  - %s\n", p.Summary.Title))
	for _, a := range p.Authors {
		sb.WriteString(fmt.Sprintf("AU  - %s\n", a.Name))
	}
	if p.Summary.Year > 0 {
		sb.WriteString(fmt.Sprintf("PY  - %d\n", p.Summary.Year))
	}
	if p.Summary.VenueName != "" {
		sb.WriteString(fmt.Sprintf("JO  - %s\n", p.Summary.VenueName))
	}
	if p.DOI != "" {
		sb.WriteString(fmt.Sprintf("DO  - %s\n", p.DOI))
	}
	if p.Summary.Abstract != nil && *p.Summary.Abstract != "" {
		sb.WriteString(fmt.Sprintf("AB  - %s\n", *p.Summary.Abstract))
	}
	sb.WriteString("ER  - \n")
	return sb.String()
}

func toAPA(p research.PaperDetail) string {
	authors := "Anonymous"
	if len(p.Authors) > 0 {
		names := make([]string, 0, len(p.Authors))
		for _, a := range p.Authors {
			names = append(names, a.Name)
		}
		if len(names) == 1 {
			authors = names[0]
		} else if len(names) == 2 {
			authors = names[0] + " & " + names[1]
		} else {
			authors = names[0] + " et al."
		}
	}
	year := "n.d."
	if p.Summary.Year > 0 {
		year = fmt.Sprintf("%d", p.Summary.Year)
	}

	venue := p.Summary.VenueName
	if venue != "" {
		venue = " " + venue + "."
	}
	doi := ""
	if p.DOI != "" {
		doi = fmt.Sprintf(" https://doi.org/%s", p.DOI)
	}

	return fmt.Sprintf("%s (%s). %s.%s%s", authors, year, p.Summary.Title, venue, doi)
}

func toMLA(p research.PaperDetail) string {
	authors := "Anonymous"
	if len(p.Authors) > 0 {
		authors = p.Authors[0].Name
		if len(p.Authors) > 1 {
			authors += ", et al."
		}
	}
	year := "n.d."
	if p.Summary.Year > 0 {
		year = fmt.Sprintf("%d", p.Summary.Year)
	}
	venue := ""
	if p.Summary.VenueName != "" {
		venue = fmt.Sprintf(" %s,", p.Summary.VenueName)
	}
	return fmt.Sprintf("%s \"%s.\"%s %s.", authors, p.Summary.Title, venue, year)
}

func toMarkdown(p research.PaperDetail) string {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("# %s\n\n", p.Summary.Title))
	if len(p.Authors) > 0 {
		names := make([]string, 0, len(p.Authors))
		for _, a := range p.Authors {
			names = append(names, a.Name)
		}
		sb.WriteString(fmt.Sprintf("**Authors:** %s\n\n", strings.Join(names, ", ")))
	}
	if p.Summary.VenueName != "" || p.Summary.Year > 0 {
		sb.WriteString(fmt.Sprintf("**Published:** %s (%d)\n\n", p.Summary.VenueName, p.Summary.Year))
	}
	if p.DOI != "" {
		sb.WriteString(fmt.Sprintf("**DOI:** [%s](https://doi.org/%s)\n\n", p.DOI, p.DOI))
	}
	if p.Summary.Abstract != nil && *p.Summary.Abstract != "" {
		sb.WriteString(fmt.Sprintf("## Abstract\n\n%s\n", *p.Summary.Abstract))
	}
	return sb.String()
}
