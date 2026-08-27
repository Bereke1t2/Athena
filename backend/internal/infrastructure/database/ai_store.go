package database

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"athena/backend/internal/domain/ai"
)

// AIStore persists AI artifacts: cached summaries, RAG chunks, embeddings
// and chat sessions/messages. All operations are idempotent-friendly.
type AIStore struct {
	pool *pgxpool.Pool
}

func NewAIStore(pool *pgxpool.Pool) *AIStore { return &AIStore{pool: pool} }

// ---- summaries --------------------------------------------------------------

// GetSummary returns the cached summary for (paper, level), or
// ai.ErrNotFound when absent.
func (s *AIStore) GetSummary(ctx context.Context, paperID uuid.UUID, level ai.ExplanationLevel) (ai.Summary, error) {
	row := s.pool.QueryRow(ctx, `
		SELECT paper_id, explanation_level::text, model_id, prompt_template_version,
		       input_content_hash, COALESCE(tldr,''), sections::text,
		       token_usage::text, created_at
		FROM ai_summaries WHERE paper_id = $1 AND explanation_level = $2`,
		paperID, string(level))

	var sum ai.Summary
	var sectionsJSON, usageJSON string
	err := row.Scan(&sum.PaperID, &sum.Level, &sum.ModelID, &sum.PromptVersion,
		&sum.InputContentHash, &sum.TLDR, &sectionsJSON, &usageJSON, &sum.GeneratedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return ai.Summary{}, ai.ErrNotFound
	}
	if err != nil {
		return ai.Summary{}, fmt.Errorf("get summary: %w", err)
	}
	if sectionsJSON != "" {
		_ = json.Unmarshal([]byte(sectionsJSON), &sum.Sections)
	}
	_ = json.Unmarshal([]byte(usageJSON), &sum.TokenUsage)
	return sum, nil
}

// SaveSummary upserts the cache row keyed by (paper_id, level).
func (s *AIStore) SaveSummary(ctx context.Context, sum ai.Summary) error {
	sections, err := json.Marshal(sum.Sections)
	if err != nil {
		return fmt.Errorf("encode summary sections: %w", err)
	}
	usage, err := json.Marshal(sum.TokenUsage)
	if err != nil {
		return fmt.Errorf("encode summary usage: %w", err)
	}
	_, err = s.pool.Exec(ctx, `
		INSERT INTO ai_summaries (id, paper_id, explanation_level, model_id,
			prompt_template_version, input_content_hash, tldr, sections, token_usage)
		VALUES ($1, $2, $3, $4, $5, $6, NULLIF($7,''), $8::jsonb, $9::jsonb)
		ON CONFLICT (paper_id, explanation_level) DO UPDATE SET
			model_id               = EXCLUDED.model_id,
			prompt_template_version = EXCLUDED.prompt_template_version,
			input_content_hash      = EXCLUDED.input_content_hash,
			tldr                    = EXCLUDED.tldr,
			sections                = EXCLUDED.sections,
			token_usage             = EXCLUDED.token_usage,
			created_at              = now()`,
		uuid.New(), sum.PaperID, string(sum.Level), sum.ModelID, sum.PromptVersion,
		sum.InputContentHash, sum.TLDR, string(sections), string(usage))
	if err != nil {
		return fmt.Errorf("save summary: %w", err)
	}
	return nil
}

// ---- chunks -----------------------------------------------------------------

// ReplaceChunks swaps the chunk set of one paper inside a transaction and
// writes embeddings alongside. Embedding rows are keyed (chunk_id, model_id).
func (s *AIStore) ReplaceChunks(ctx context.Context, paperID uuid.UUID,
	chunks []ai.Chunk, vectors [][]float32, modelID string) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if _, err := tx.Exec(ctx, `DELETE FROM paper_chunks WHERE paper_id = $1`, paperID); err != nil {
		return fmt.Errorf("clear chunks: %w", err)
	}
	for i := range chunks {
		c := chunks[i]
		if c.ID == uuid.Nil {
			c.ID = uuid.New()
			chunks[i] = c
		}
		if _, err := tx.Exec(ctx, `
			INSERT INTO paper_chunks (id, paper_id, seq, section_path, heading, content,
				token_count, content_hash)
			VALUES ($1, $2, $3, NULLIF($4,''), NULLIF($5,''), $6, $7, $8)`,
			c.ID, paperID, c.Seq, c.SectionPath, c.Heading, c.Content,
			c.TokenCount, c.ContentHash); err != nil {
			return fmt.Errorf("insert chunk %d: %w", c.Seq, err)
		}
		if modelID != "" && i < len(vectors) && len(vectors[i]) > 0 {
			if _, err := tx.Exec(ctx, `
				INSERT INTO chunk_embeddings (chunk_id, model_id, dim, embedding)
				VALUES ($1, $2, $3, $4::vector)
				ON CONFLICT (chunk_id, model_id) DO UPDATE SET embedding = EXCLUDED.embedding`,
				c.ID, modelID, len(vectors[i]), pgvectorLiteral(vectors[i])); err != nil {
				return fmt.Errorf("insert embedding %d: %w", c.Seq, err)
			}
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit chunks: %w", err)
	}
	return nil
}

// ListChunks returns the paper's chunks in sequence order.
func (s *AIStore) ListChunks(ctx context.Context, paperID uuid.UUID) ([]ai.Chunk, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, paper_id, seq, COALESCE(section_path,''), COALESCE(heading,''),
		       content, token_count, content_hash
		FROM paper_chunks WHERE paper_id = $1 ORDER BY seq`, paperID)
	if err != nil {
		return nil, fmt.Errorf("list chunks: %w", err)
	}
	defer rows.Close()

	var out []ai.Chunk
	for rows.Next() {
		var c ai.Chunk
		if err := rows.Scan(&c.ID, &c.PaperID, &c.Seq, &c.SectionPath,
			&c.Heading, &c.Content, &c.TokenCount, &c.ContentHash); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// ChunkCount returns how many RAG chunks exist for a paper.
func (s *AIStore) ChunkCount(ctx context.Context, paperID uuid.UUID) (int, error) {
	var n int
	err := s.pool.QueryRow(ctx,
		`SELECT count(*) FROM paper_chunks WHERE paper_id = $1`, paperID).Scan(&n)
	return n, err
}

// SearchByVector runs cosine ANN within one paper's chunks; embeddings must
// exist under modelID.
func (s *AIStore) SearchByVector(ctx context.Context, paperID uuid.UUID,
	vec []float32, modelID string, k int) ([]ai.RetrievedChunk, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT c.id, c.paper_id, c.seq, COALESCE(c.section_path,''), COALESCE(c.heading,''),
		       c.content, c.token_count, c.content_hash, 1 - (e.embedding <=> $1::vector) AS score
		FROM paper_chunks c
		JOIN chunk_embeddings e ON e.chunk_id = c.id AND e.model_id = $3
		WHERE c.paper_id = $2
		ORDER BY e.embedding <=> $1::vector
		LIMIT $4`, pgvectorLiteral(vec), paperID, modelID, k)
	if err != nil {
		return nil, fmt.Errorf("vector search: %w", err)
	}
	return scanRetrieved(rows)
}

// SearchKeyword is the lexical leg of hybrid retrieval (per-paper scope, so
// ranking tsvector on the fly is fine).
func (s *AIStore) SearchKeyword(ctx context.Context, paperID uuid.UUID, query string, k int) ([]ai.RetrievedChunk, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, paper_id, seq, COALESCE(section_path,''), COALESCE(heading,''),
		       content, token_count, content_hash,
		       ts_rank_cd(to_tsvector('english', content),
		                  websearch_to_tsquery('english', $2)) AS score
		FROM paper_chunks
		WHERE paper_id = $1
		  AND to_tsvector('english', content) @@ websearch_to_tsquery('english', $2)
		ORDER BY score DESC
		LIMIT $3`, paperID, query, k)
	if err != nil {
		return nil, fmt.Errorf("keyword search: %w", err)
	}
	return scanRetrieved(rows)
}

func scanRetrieved(rows pgx.Rows) ([]ai.RetrievedChunk, error) {
	defer rows.Close()
	var out []ai.RetrievedChunk
	for rows.Next() {
		var rc ai.RetrievedChunk
		if err := rows.Scan(&rc.ID, &rc.PaperID, &rc.Seq, &rc.SectionPath,
			&rc.Heading, &rc.Content, &rc.TokenCount, &rc.ContentHash, &rc.Score); err != nil {
			return nil, err
		}
		out = append(out, rc)
	}
	return out, rows.Err()
}

// pgvectorLiteral renders a float vector as pgvector text input.
func pgvectorLiteral(v []float32) string {
	var b strings.Builder
	b.WriteByte('[')
	for i, x := range v {
		if i > 0 {
			b.WriteByte(',')
		}
		fmt.Fprintf(&b, "%g", x)
	}
	b.WriteByte(']')
	return b.String()
}

// ---- chat -------------------------------------------------------------------

// CreateSession inserts a single-paper chat session.
func (s *AIStore) CreateSession(ctx context.Context, in ai.NewSessionInput) (ai.Session, error) {
	row := s.pool.QueryRow(ctx, `
		INSERT INTO chat_sessions (id, user_id, session_type, paper_id, title)
		VALUES ($1, $2, 'single_paper', $3, NULLIF($4,''))
		RETURNING id, user_id, paper_id, COALESCE(title,''), message_count, last_message_at, created_at`,
		uuid.New(), in.UserID, in.PaperID, in.Title)

	var sess ai.Session
	err := row.Scan(&sess.ID, &sess.UserID, &sess.PaperID, &sess.Title,
		&sess.MessageCount, &sess.LastMessageAt, &sess.CreatedAt)
	if err != nil {
		return ai.Session{}, fmt.Errorf("create chat session: %w", err)
	}
	return sess, nil
}

// GetSession loads one session header.
func (s *AIStore) GetSession(ctx context.Context, id uuid.UUID) (ai.Session, error) {
	row := s.pool.QueryRow(ctx, `
		SELECT id, user_id, paper_id, COALESCE(title,''), message_count, last_message_at, created_at
		FROM chat_sessions WHERE id = $1 AND session_type = 'single_paper'`, id)
	var sess ai.Session
	err := row.Scan(&sess.ID, &sess.UserID, &sess.PaperID, &sess.Title,
		&sess.MessageCount, &sess.LastMessageAt, &sess.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return ai.Session{}, ai.ErrNotFound
	}
	if err != nil {
		return ai.Session{}, fmt.Errorf("get chat session: %w", err)
	}
	return sess, nil
}

// ListMessages returns the session transcript oldest-first.
func (s *AIStore) ListMessages(ctx context.Context, sessionID uuid.UUID, limit int) ([]ai.Message, error) {
	if limit <= 0 || limit > 500 {
		limit = 200
	}
	rows, err := s.pool.Query(ctx, `
		SELECT id, session_id, role::text, content, citations::text,
		       COALESCE(model_id,''), COALESCE(token_usage::text,'{}'), created_at
		FROM chat_messages WHERE session_id = $1 ORDER BY created_at LIMIT $2`,
		sessionID, limit)
	if err != nil {
		return nil, fmt.Errorf("list messages: %w", err)
	}
	defer rows.Close()

	var out []ai.Message
	for rows.Next() {
		m, scanErr := scanMessage(rows)
		if scanErr != nil {
			return nil, scanErr
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

type rowScanner interface{ Scan(dest ...any) error }

func scanMessage(row rowScanner) (ai.Message, error) {
	var m ai.Message
	var citationsJSON, usageJSON string
	if err := row.Scan(&m.ID, &m.SessionID, &m.Role, &m.Content,
		&citationsJSON, &m.ModelID, &usageJSON, &m.CreatedAt); err != nil {
		return ai.Message{}, err
	}
	if citationsJSON != "" && citationsJSON != "[]" {
		_ = json.Unmarshal([]byte(citationsJSON), &m.Citations)
	}
	if usageJSON != "" {
		_ = json.Unmarshal([]byte(usageJSON), &m.TokenUsage)
	}
	return m, nil
}

// AppendMessage stores one turn and bumps the session counters atomically.
func (s *AIStore) AppendMessage(ctx context.Context, m ai.Message) (ai.Message, error) {
	citations, err := json.Marshal(m.Citations)
	if err != nil {
		return ai.Message{}, fmt.Errorf("encode citations: %w", err)
	}
	usage, err := json.Marshal(m.TokenUsage)
	if err != nil {
		return ai.Message{}, fmt.Errorf("encode token usage: %w", err)
	}

	row := s.pool.QueryRow(ctx, `
		WITH ins AS (
			INSERT INTO chat_messages (id, session_id, role, content, citations, model_id, token_usage)
			VALUES ($1, $2, $3, $4, $5::jsonb, NULLIF($6,''), $7::jsonb)
			RETURNING id, session_id, role::text, content, citations::text,
			          COALESCE(model_id,'') AS model_id, COALESCE(token_usage::text,'{}') AS token_usage, created_at
		), bump AS (
			UPDATE chat_sessions SET
				message_count = message_count + 1,
				last_message_at = now()
			WHERE id = $2
		)
		SELECT id, session_id, role, content, citations, model_id, token_usage, created_at FROM ins`,
		uuid.New(), m.SessionID, string(m.Role), m.Content, string(citations),
		m.ModelID, string(usage))

	msg, err := scanMessage(row)
	if err != nil {
		return ai.Message{}, fmt.Errorf("append message: %w", err)
	}
	return msg, nil
}
