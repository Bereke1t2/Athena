# AI & RAG Architecture

> Grounded answers or no answers. Never fabricate papers, authors, results,
> citations, or statistics. (ADR-0004)

## 1. Capabilities

| Feature | Phase | Notes |
|---|---|---|
| Structured summaries (TL;DR … why-it-matters) | 4 | cached per (paper, level) |
| Explanation levels | 4 | beginner / intermediate / advanced / expert |
| Chat with a paper | 4 | RAG-grounded, cited, streaming (SSE) |
| Paper comparison | 6 | map-reduce over per-paper structured extraction |

## 2. Ports

```go
// domain/ai
type LLMProvider interface {
    Generate(ctx, GenerateRequest) (GenerateResponse, error)
    GenerateStream(ctx, GenerateRequest) (StreamReader, error)
    GenerateJSON(ctx, GenerateRequest, SchemaHint) (json.RawMessage, error)
}
type EmbeddingProvider interface {
    Embed(ctx context.Context, texts []string) ([]Embedding, error)
}
```

First adapter: OpenAI-compatible HTTP (`openaicompat`) — covers OpenAI, Azure,
vLLM, Ollama, Groq, Together via config. Every call persists
`model_id`, `prompt_template_version`, `token_usage`.

## 3. Full-text acquisition (legal gate first)

Per ADR-0010, only `oa_status ∈ {gold, green, hybrid, bronze}` or arXiv
preprints with text-mining-permitted licenses proceed:

```text
OA URL (best_oa_url / arXiv PDF)
   → TextExtractor port (pluggable: MVP pdf-to-text; GROBID service later for
     section-aware parsing)
   → Cleaning (headers/footers/references normalization, de-hyphenation)
   → Section detection (headings; fallback heuristics)
   → paper_versions + paper_chunks persisted with content_hash
```

Papers without permitted full text remain **metadata-only**: summaries use
abstract when available; chat answers from abstract scope and say so.

## 4. Chunking

- Target ~800 tokens per chunk, 10–15% overlap.
- Section-aware: never split across headings when avoidable; heading breadcrumb
  stored on the chunk (`section_path`).
- Each chunk stores `content_hash`; re-ingesting identical text skips
  re-embedding.

## 5. Embeddings

- Default model configurable (`EMBEDDING_MODEL`, `EMBEDDING_DIM=1536`).
- Stored in `chunk_embeddings(chunk_id, model_id, embedding vector)` with HNSW
  cosine index. Model changes → new `model_id` rows + backfill job; old rows
  pruned after full backfill (no dimension migration pain mid-flight).

## 6. Retrieval & context assembly

```text
question ──▶ embed ──▶ ANN top-k (pgvector, per-paper filter for chat)
                     ─┐
paper FTS hits       ─┴─▶ RRF fuse ──▶ top-N chunks (N by token budget)
                                        + paper metadata card
                                        + rolling summary of long history
                                        = final prompt context (≤ budget)
```

Budgets enforced server-side with a tokenizer approximation; hard cap keeps
costs bounded. Comparison mode retrieves per-paper contexts separately to keep
attribution clean.

## 7. Grounding contract (enforced in prompts + code)

System rules baked into every research prompt:

1. Answer **only** from provided context chunks; cite chunk indices like
   `[chunk 3]`.
2. Distinguish findings vs interpretation vs speculation; preserve stated
   limitations.
3. If evidence is insufficient: reply exactly that — no guessing.
4. Numbers/statistics must appear verbatim in context or be refused.
5. Never invent citations, authors, papers, or figures.

Post-generation checks (Phase 4): citation indices validated against retrieved
set; responses failing validation are regenerated once, then degraded to a
"cannot answer" message. All messages store their citation payloads
(`chat_messages.citations`) so the client can render source links.

## 8. Cost & abuse control

- Summaries cached at `(paper_id, level)` keyed additionally by
  `input_content_hash` — re-summarization happens only if content changed.
- Idempotency-Key accepted on AI POSTs; concurrent duplicates coalesce.
- Per-user/IP quotas via Redis; model tier configurable downward for cost.
