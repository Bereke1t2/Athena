# ADR 0010: Content acquisition & licensing policy

- **Status:** accepted
- **Date:** 2026-08-22
- **Deciders:** Lead Architect

## Context

Athena's AI features want full text, but academic publishing has real legal
constraints: most publisher PDFs are copyrighted; APIs have terms of use and
rate limits; abstracts are generally distributable metadata but with
attribution expectations. Building ingestion on scraping paywalled sites would
create existential legal risk.

## Decision

Athena is **metadata-first**. Content classification is explicit in the data
model (`oa_status`: gold/green/hybrid/bronze/closed/unknown; `license`;
per-source URLs) and gates every downstream behavior:

| Content tier | Storage | AI processing | Display |
|---|---|---|---|
| Bibliographic metadata (title/authors/DOI/venue/citations) | ✅ always | ✅ always | ✅ always |
| Abstracts (as permitted by source terms — S2/OpenAlex/arXiv allow display with attribution) | ✅ | ✅ | ✅ with source attribution |
| Open-access full text (gold/hybrid/bronze, CC or similar licenses) | Extracted text + chunks only, no full-PDF redistribution | ✅ | Link out to publisher copy |
| Preprints (arXiv et al.) | Same as OA full text per arXiv license flags | ✅ honoring per-paper license field | Link to arXiv |
| Closed/publisher-only versions | ❌ never fetched | ❌ never | Metadata only |

Operational rules:

- Respect each provider's published rate limits; identify via API keys / polite
  pool mailto.
- No scraping of sites whose terms prohibit it; no paywall circumvention ever.
- Takedown: a documented contact + removal path exists from Phase 1 (even if
  manual).
- Full-text extraction runs only on documents whose recorded license permits
  processing; when uncertain → treat as closed.

## Consequences

**Positive:** legally defensible posture; clear product UX for "metadata only"
papers; providers stay within terms.

**Negative / risks:** AI features unavailable for closed-access subset —
product communicates this honestly ("AI insights available for open research")
rather than bending rules.
