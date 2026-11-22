package database

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"athena/backend/internal/domain/research"
)

// GetCitationEdgesForScoring retrieves all active papers and directed citation edges
// for computing graph centrality and PageRank authority scores.
func (s *PaperStore) GetCitationEdgesForScoring(ctx context.Context) ([]research.GraphEdge, []uuid.UUID, error) {
	// 1. Fetch all active paper IDs
	paperRows, err := s.pool.Query(ctx, `SELECT id FROM papers WHERE deleted_at IS NULL`)
	if err != nil {
		return nil, nil, fmt.Errorf("fetch active papers: %w", err)
	}
	defer paperRows.Close()

	var allPaperIDs []uuid.UUID
	for paperRows.Next() {
		var id uuid.UUID
		if err := paperRows.Scan(&id); err != nil {
			return nil, nil, fmt.Errorf("scan paper id: %w", err)
		}
		allPaperIDs = append(allPaperIDs, id)
	}
	if err := paperRows.Err(); err != nil {
		return nil, nil, err
	}

	// 2. Fetch all citation edges between active papers
	edgeRows, err := s.pool.Query(ctx, `
		SELECT c.citing_paper_id, c.cited_paper_id, COALESCE(c.is_influential, false), COALESCE(c.stance, 'mentions'), COALESCE(c.context, '')
		FROM citations c
		JOIN papers p1 ON p1.id = c.citing_paper_id AND p1.deleted_at IS NULL
		JOIN papers p2 ON p2.id = c.cited_paper_id AND p2.deleted_at IS NULL
	`)
	if err != nil {
		return nil, nil, fmt.Errorf("fetch citation edges: %w", err)
	}
	defer edgeRows.Close()

	var edges []research.GraphEdge
	for edgeRows.Next() {
		var edge research.GraphEdge
		var stanceStr string
		if err := edgeRows.Scan(&edge.Source, &edge.Target, &edge.IsInfluential, &stanceStr, &edge.Context); err != nil {
			return nil, nil, fmt.Errorf("scan citation edge: %w", err)
		}
		edge.Stance = research.CitationStance(stanceStr)
		edges = append(edges, edge)
	}
	if err := edgeRows.Err(); err != nil {
		return nil, nil, err
	}

	return edges, allPaperIDs, nil
}

// UpdatePaperAuthorityScores bulk updates computed authority scores and seminal flags.
func (s *PaperStore) UpdatePaperAuthorityScores(ctx context.Context, scores map[uuid.UUID]float64, seminalIDs map[uuid.UUID]bool) (int, error) {
	if len(scores) == 0 {
		return 0, nil
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin transaction: %w", err)
	}
	defer tx.Rollback(ctx) // nolint:errcheck

	updated := 0
	for id, score := range scores {
		isSeminal := seminalIDs[id]
		tag, err := tx.Exec(ctx, `
			UPDATE papers
			SET authority_score = $1, is_seminal = $2, updated_at = NOW()
			WHERE id = $3 AND deleted_at IS NULL
		`, score, isSeminal, id)
		if err != nil {
			return 0, fmt.Errorf("update paper authority %s: %w", id, err)
		}
		updated += int(tag.RowsAffected())
	}

	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit authority updates: %w", err)
	}

	return updated, nil
}
