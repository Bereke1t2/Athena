package v1

import (
	"athena/backend/internal/domain/research"
	"github.com/google/uuid"
)

type authorLineDTO struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	ORCID       string    `json:"orcid,omitempty"`
	Affiliation []string  `json:"affiliation,omitempty"`
}

type topicLineDTO struct {
	Slug      string  `json:"slug"`
	Name      string  `json:"name"`
	Score     float64 `json:"score,omitempty"`
	IsPrimary bool    `json:"is_primary"`
}

type versionLineDTO struct {
	Kind       string `json:"kind"`
	URL        string `json:"url"`
	IsPreprint bool   `json:"is_preprint"`
}

type paperDetailDTO struct {
	paperSummaryDTO
	Language       string           `json:"language,omitempty"`
	License        string           `json:"license,omitempty"`
	BestOAURL      string           `json:"best_oa_url,omitempty"`
	DOI            string           `json:"doi,omitempty"`
	ArxivID        string           `json:"arxiv_id,omitempty"`
	Authors        []authorLineDTO  `json:"authors"`
	Topics         []topicLineDTO   `json:"topics"`
	Versions       []versionLineDTO `json:"versions,omitempty"`
	ReferenceCount int              `json:"reference_count"`
	SourceSlugs    []string         `json:"sources"`
	CreatedAt      string           `json:"created_at"`
	UpdatedAt      string           `json:"updated_at"`
}

func newDetailDTO(d research.PaperDetail) paperDetailDTO {
	out := paperDetailDTO{
		paperSummaryDTO: newSummaryDTO(d.Summary),
		Language:        d.Language,
		License:         d.License,
		BestOAURL:       d.BestOAURL,
		DOI:             d.DOI,
		ArxivID:         d.ArxivID,
		ReferenceCount:  d.ReferenceCount,
		SourceSlugs:     d.SourceSlugs,
		CreatedAt:       d.CreatedAt.UTC().Format(timeFormatRFC3339),
		UpdatedAt:       d.UpdatedAt.UTC().Format(timeFormatRFC3339),
	}
	if out.SourceSlugs == nil {
		out.SourceSlugs = []string{}
	}

	out.Authors = make([]authorLineDTO, 0, len(d.Authors))
	for _, a := range d.Authors {
		line := authorLineDTO{ID: a.ID, Name: a.Name, ORCID: a.ORCID, Affiliation: a.Affiliation}
		if line.Affiliation == nil {
			line.Affiliation = []string{}
		}
		out.Authors = append(out.Authors, line)
	}

	out.Topics = make([]topicLineDTO, 0, len(d.Topics))
	for _, t := range d.Topics {
		out.Topics = append(out.Topics, topicLineDTO{
			Slug: t.Slug, Name: t.Name, Score: t.Score, IsPrimary: t.IsPrimary,
		})
	}

	for _, v := range d.Versions {
		out.Versions = append(out.Versions, versionLineDTO{
			Kind: string(v.Kind), URL: v.URL, IsPreprint: v.IsPreprint || v.Kind == research.VersionPreprint,
		})
	}
	return out
}

const timeFormatRFC3339 = "2006-01-02T15:04:05Z07:00"
