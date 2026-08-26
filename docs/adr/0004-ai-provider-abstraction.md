# ADR 0004: AI provider abstraction

- **Status:** accepted
- **Date:** 2026-08-22
- **Deciders:** Lead Architect

## Context

Athena's core value depends on LLM features (summaries, grounded chat,
comparison), but the LLM vendor landscape changes monthly; pricing, quality,
privacy, and deployment models (cloud vs self-hosted) all vary by customer and
jurisdiction. Business logic must not couple to any single vendor SDK or
schema.

## Decision

Define two ports in `internal/domain/ai`:

```go
type LLMProvider interface {
    Generate(ctx, GenerateRequest) (GenerateResponse, error)
    GenerateStream(ctx, GenerateRequest) (StreamReader, error)
    GenerateJSON(ctx, GenerateRequest, SchemaHint) (json.RawMessage, error)
}

type EmbeddingProvider interface {
    Embed(ctx, texts []string) ([]Embedding, error) // Embedding{Vector, ModelID, Dim}
}
```

First adapter in `infrastructure/ai/openaicompat`: one HTTP client speaking the
OpenAI-compatible chat/embeddings protocol, which covers OpenAI, Azure OpenAI,
Together, Groq, Fireworks, vLLM, and Ollama — selected purely via
configuration. Additional adapters (e.g., native Anthropic Messages API) are
additive.

Ground rules:

- Prompts are versioned artifacts (`prompt_template_version`) and persisted
  alongside every generated output (`ai_summaries.model_id`,
  `.prompt_template_version`) for auditability and cache invalidation.
- Token usage from every call is recorded (`token_usage` JSONB) → cost
  observability from day one.
- Determinism knobs (temperature etc.) are request parameters owned by use
  cases, not hidden inside adapters.
- No retries-with-side-effects inside adapters beyond idempotent transport
  retries; semantic retry policy belongs to application layer.

## Alternatives considered

| Option | Pros | Cons | Why rejected |
|---|---|---|---|
| LangChain / heavyweight orchestration frameworks | Prebuilt chains | Thick dependency, opaque prompts, poor fit for Go-first codebase | We need control over grounding + citations; thin port is enough |
| Direct vendor SDK calls in use cases | Fastest start | Vendor lock-in exactly where change is fastest | Violates product requirement |
| Self-hosted only (Ollama/vLLM) | Privacy, cost control | MVP team lacks GPU ops capacity | Supported *via* the compatible adapter when needed |

## Consequences

**Positive:**

- Vendor swap = config change; local dev can run Ollama.
- Cost/quality experiments (model A/B) are configuration, not refactors.
- Audit trail satisfies accuracy/safety requirements (prompt + model version).

**Negative / risks:**

- Port may lag cutting-edge vendor features (native tool streaming); we extend
  the port deliberately per feature instead of pre-emptively.
- "JSON mode" support varies across vendors → normalized inside the compat
  adapter with schema-hint fallback prompting.

**Follow-ups:**

- [ ] Phase 4: golden-set evaluation harness for summary/chat quality before launch.
