// Hybrid retrieval (docs/architecture/ai-rag.md §6): embed the question for
// pgvector ANN, run lexical FTS alongside, fuse with Reciprocal Rank Fusion,
// and return the top-k chunks.
package ai

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	domainai "athena/backend/internal/domain/ai"
)

// ChunkSearcher is the store-side search surface (implemented by AIStore).
type ChunkSearcher interface {
	SearchByVector(ctx context.Context, paperID uuid.UUID, vec []float32, modelID string, k int) ([]domainai.RetrievedChunk, error)
	SearchKeyword(ctx context.Context, paperID uuid.UUID, query string, k int) ([]domainai.RetrievedChunk, error)
}

// RetrievalService implements domainai.ChunkRetriever over the hybrid legs.
// Without an Embedder it degrades to keyword-only — never an error.
type RetrievalService struct {
	Embedder   domainai.EmbeddingProvider // nil ⇒ keyword only
	Searcher   ChunkSearcher
	CandidateK int
}

func NewRetrievalService(embedder domainai.EmbeddingProvider, searcher ChunkSearcher) *RetrievalService {
	return &RetrievalService{Embedder: embedder, Searcher: searcher, CandidateK: 12}
}

func (s *RetrievalService) Retrieve(ctx context.Context, q domainai.ChunkQuery) ([]domainai.RetrievedChunk, error) {
	k := q.TopK
	if k <= 0 {
		k = 8
	}
	cand := s.CandidateK
	if cand < k {
		cand = k
	}

	type hit struct {
		rc    domainai.RetrievedChunk
		score float64
	}
	fused := map[uuid.UUID]*hit{}

	add := func(list []domainai.RetrievedChunk, weight float64) {
		for rank, rc := range list {
			h, ok := fused[rc.ID]
			if !ok {
				h = &hit{rc: rc}
				fused[rc.ID] = h
			}
			h.score += weight / float64(60+rank+1)
		}
	}

	var err error
	if s.Embedder != nil && q.Question != "" {
		vecs, embErr := s.Embedder.Embed(ctx, []string{q.Question})
		if embErr == nil && len(vecs) == 1 {
			var vecList []domainai.RetrievedChunk
			vecList, err = s.Searcher.SearchByVector(ctx, q.PaperID, vecs[0], s.Embedder.Model(), cand)
			if err != nil {
				return nil, fmt.Errorf("vector leg: %w", err)
			}
			add(vecList, 1.0)
		} else if embErr != nil {
			// Embedding outage must not kill lexical retrieval.
			fmt.Printf("athena: embedding leg failed, keyword-only: %v\n", embErr)
		}
	}

	if q.Question != "" {
		kwList, kwErr := s.Searcher.SearchKeyword(ctx, q.PaperID, q.Question, cand)
		if kwErr != nil {
			if len(fused) == 0 {
				return nil, fmt.Errorf("keyword leg: %w", kwErr)
			}
			// Keep vector results if the lexical leg fails.
		} else {
			add(kwList, 1.0)
		}
	}

	out := make([]domainai.RetrievedChunk, 0, len(fused))
	for _, h := range fused {
		h.rc.Score = h.score
		out = append(out, h.rc)
	}
	sortByScore(out)
	if len(out) > k {
		out = out[:k]
	}
	return out, nil
}

// sortByScore is a tiny insertion sort — candidate sets are small (<40).
func sortByScore(list []domainai.RetrievedChunk) {
	for i := 1; i < len(list); i++ {
		for j := i; j > 0 && list[j].Score > list[j-1].Score; j-- {
			list[j], list[j-1] = list[j-1], list[j]
		}
	}
}
