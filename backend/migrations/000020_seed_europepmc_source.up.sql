-- Seed Europe PMC source for biomedical and life sciences research aggregation.
INSERT INTO sources (id, slug, name, base_url, terms_of_use_url) VALUES
  (gen_random_uuid(), 'europepmc', 'Europe PMC',
   'https://api.europepmc.org', 'https://europepmc.org/About')
ON CONFLICT (slug) DO NOTHING;
