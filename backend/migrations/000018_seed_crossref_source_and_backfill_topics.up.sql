-- Seed Crossref source and retroactively backfill unparented topics to canonical fields.
BEGIN;

-- 1. Insert Crossref into sources if not present.
INSERT INTO sources (id, slug, name, base_url, terms_of_use_url) VALUES
  (gen_random_uuid(), 'crossref', 'Crossref',
   'https://api.crossref.org', 'https://www.crossref.org/documentation/retrieve-metadata/rest-api/')
ON CONFLICT (slug) DO NOTHING;

-- 2. Retroactively attach unparented topics to canonical fields using domain patterns.
CREATE TEMP TABLE IF NOT EXISTS field_retro_seed (
    ord     int PRIMARY KEY,
    slug    text UNIQUE NOT NULL,
    pattern text NOT NULL
);

INSERT INTO field_retro_seed (ord, slug, pattern) VALUES
    (1,  'history-and-archaeology',      'histor|archaeol|ancient|medieval|antiquit|heritage|\yart(s)?\y.*(excavat)|paleo'),
    (2,  'philosophy-and-religion',      'philosoph|ethic|moral|metaphysic|epistemolog|religio|theolog'),
    (3,  'law',                          '\ylaws?\y|legal|judicial|judgment|jurispruden|crimin|justice|constitutiona|statut'),
    (4,  'arts-and-humanities',          'literar|literature|linguistic|music|theatre|theater|film|poetr|cultural studies|\yculture\y|visual|photograph|art history|\yarts?\y'),
    (5,  'education',                    'education|pedagog|teaching|curriculum|\ystudents?\y|classroom|school'),
    (6,  'psychology-and-neuroscience',  'psycholog|neuro|cognit|\ybrain\y|psychiatric|mental health|behavio|perception|emotion'),
    (7,  'sociology-and-politics',       'sociolog|social|politic|governance|policy|democra|migration|gender|inequalit|urban|community'),
    (8,  'economics-and-business',       'econom|business|market|financ|bank|trade|commerce|corporate|entrepreneur|accounting|manag'),
    (9,  'mathematics',                  'mathemat|algebra|geometr|topolog|calculus|number theory|probabilit|statistic|optimiz|optimis|combinatoric|graph theory|algorithm'),
    (10, 'computer-science',             '\yai\y|artificial intelligence|machine learning|deep learning|neural network|natural language|computer vision|image processing|robotic|software|computing|cybersecurity|blockchain|data mining|internet of things|cloud comput|\yvlsi\y|integrated circuit|error correct|programming|\ycodes?\y.*decod|semantic web|database|network security|human-computer'),
    (11, 'engineering-and-technology',   'engineer|mechanical|manufactur|structural|thermo|fluid|automation|control system|telecommunicat|satellite|antenna|radar|vehicle|brake|weld|machinin'),
    (12, 'materials-science',            'material|nano|composite|alloy|coating|thin film|ceramic|metallurg|polymer|crystal|concrete'),
    (13, 'physics-and-astronomy',        'physic|quantum|particle|photon|optic|laser|\yatom|nuclear|plasma|gravitat|cosmol|astron|astro|relativ|electromagnet|semiconductor|magnet'),
    (14, 'chemistry',                    'chemi|catalys|cataly|synthesis|\ycompound|molecule|molecular|spectroscop|electrochem|fluoride|oxid'),
    (15, 'medicine-and-health',          'medicin|medical|clinical|disease|diagnos|treatment|therapy|cancer|tumo|tumou|patient|health|surger|surgical|virus|viral|covid|infection|epidemiol|pharmac|syndrome|pregnan|cardiac|cardiovascular|immun|antibod|hormon|lesion|\ytumor'),
    (16, 'biology-and-life-sciences',    'biolog|biological|\ygen(e|omic)|protein|enzyme|\ycells?\y|microb|bacteri|viruse|plant|animal|ecolog|ecosystem|specie|evolution|botan|zool|photosynth|metabolis'),
    (17, 'agriculture-and-food',         'agricultur|\ycrops?\y|\yfood\y|farm|agronom|livestock|fisher|horticult|soil fertili'),
    (18, 'environment-and-earth-science','environ|climate|sustainab|\yearth\y|geolog|water|ocean|atmospher|renewable|energy|pollut|biodivers|forestry|mineral')
ON CONFLICT (slug) DO NOTHING;

WITH matches AS (
    SELECT DISTINCT ON (t.id)
        t.id AS topic_id, f.id AS field_id
    FROM topics t
    JOIN field_retro_seed s ON t.name ~* s.pattern OR t.slug ~* s.pattern
    JOIN topics f ON f.slug = s.slug AND f.kind = 'field'
    WHERE t.kind = 'topic' AND t.parent_id IS NULL
    ORDER BY t.id, s.ord
)
UPDATE topics t
SET parent_id = m.field_id
FROM matches m
WHERE t.id = m.topic_id;

DROP TABLE IF EXISTS field_retro_seed;

COMMIT;
