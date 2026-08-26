-- Seeds the initial research providers (ADR-0002).
BEGIN;

INSERT INTO sources (id, slug, name, base_url, terms_of_use_url) VALUES
  (gen_random_uuid(), 'semanticscholar', 'Semantic Scholar',
   'https://api.semanticscholar.org', 'https://www.semanticscholar.org/product-api#terms'),
  (gen_random_uuid(), 'openalex', 'OpenAlex',
   'https://api.openalex.org', 'https://openalex.org/terms-of-service'),
  (gen_random_uuid(), 'arxiv', 'arXiv',
   'https://export.arxiv.org', 'https://info.arxiv.org/help/api/tou.html')
ON CONFLICT (slug) DO NOTHING;

COMMIT;
