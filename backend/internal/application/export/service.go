// Package export implements research paper citation and bibliography export use cases.
package export

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"

	domainexport "athena/backend/internal/domain/export"
	"athena/backend/internal/domain/research"
)

// Service formats papers into standard bibliographic and citation formats.
type Service struct {
	reader research.PaperReader
}

// NewService constructs an export service.
func NewService(reader research.PaperReader) *Service {
	return &Service{reader: reader}
}

// ExportPaper formats a single paper into the specified bibliography format.
func (s *Service) ExportPaper(ctx context.Context, paperID uuid.UUID, format domainexport.Format) (string, string, error) {
	if paperID == uuid.Nil {
		return "", "", fmt.Errorf("paper_id is required")
	}
	detail, err := s.reader.GetDetailByID(ctx, paperID)
	if err != nil {
		return "", "", err
	}

	formatted, err := domainexport.FormatPaper(detail, format)
	if err != nil {
		return "", "", err
	}
	return formatted, format.ContentType(), nil
}

// ExportPapersBulk formats multiple papers into a combined bibliography.
func (s *Service) ExportPapersBulk(ctx context.Context, paperIDs []uuid.UUID, format domainexport.Format) (string, string, error) {
	if len(paperIDs) == 0 {
		return "", format.ContentType(), nil
	}
	var sb strings.Builder
	for i, id := range paperIDs {
		detail, err := s.reader.GetDetailByID(ctx, id)
		if err != nil {
			continue
		}
		formatted, err := domainexport.FormatPaper(detail, format)
		if err != nil {
			continue
		}
		if i > 0 && format != domainexport.FormatBibTeX && format != domainexport.FormatRIS {
			sb.WriteString("\n\n")
		}
		sb.WriteString(formatted)
	}
	return sb.String(), format.ContentType(), nil
}
