-- Seed canonical top-level fields and attach provider topics as children.
--
-- Ingestion only ever creates kind='topic' rows from provider payloads, so the
-- taxonomy shipped without any 'field' nodes and parent_id was NULL everywhere.
-- This backfills a small curated field layer (docs/database/schema.md: field ▸
-- topic hierarchy) by matching topic names against per-field regex patterns.
-- First matching field wins (ordered); unmatched topics stay top-level.

CREATE TEMP TABLE field_seed (
    ord     int PRIMARY KEY,
    slug    text UNIQUE NOT NULL,
    name    text NOT NULL,
    pattern text NOT NULL
);

INSERT INTO field_seed (ord, slug, name, pattern) VALUES
    (1,  'history-and-archaeology',      'History and Archaeology',       'histor|archaeol|ancient|medieval|antiquit|heritage|\yart(s)?\y.*(excavat)|paleo'),
    (2,  'philosophy-and-religion',      'Philosophy and Religion',       'philosoph|ethic|moral|metaphysic|epistemolog|religio|theolog'),
    (3,  'law',                          'Law',                           '\ylaws?\y|legal|judicial|judgment|jurispruden|crimin|justice|constitutiona|statut'),
    (4,  'arts-and-humanities',          'Arts and Humanities',           'literar|literature|linguistic|music|theatre|theater|film|poetr|cultural studies|\yculture\y|visual|photograph|art history|\yarts?\y'),
    (5,  'education',                    'Education',                     'education|pedagog|teaching|curriculum|\ystudents?\y|classroom|school'),
    (6,  'psychology-and-neuroscience',  'Psychology and Neuroscience',   'psycholog|neuro|cognit|\ybrain\y|psychiatric|mental health|behavio|perception|emotion'),
    (7,  'sociology-and-politics',       'Sociology and Politics',        'sociolog|social|politic|governance|policy|democra|migration|gender|inequalit|urban|community'),
    (8,  'economics-and-business',       'Economics and Business',        'econom|business|market|financ|bank|trade|commerce|corporate|entrepreneur|accounting|manag'),
    (9,  'mathematics',                  'Mathematics',                   'mathemat|algebra|geometr|topolog|calculus|number theory|probabilit|statistic|optimiz|optimis|combinatoric|graph theory|algorithm'),
    (10, 'computer-science',             'Computer Science',              '\yai\y|artificial intelligence|machine learning|deep learning|neural network|natural language|computer vision|image processing|robotic|software|computing|cybersecurity|blockchain|data mining|internet of things|cloud comput|\yvlsi\y|integrated circuit|error correct|programming|\ycodes?\y.*decod|semantic web|database|network security|human-computer'),
    (11, 'engineering-and-technology',   'Engineering and Technology',    'engineer|mechanical|manufactur|structural|thermo|fluid|automation|control system|telecommunicat|satellite|antenna|radar|vehicle|brake|weld|machinin'),
    (12, 'materials-science',            'Materials Science',             'material|nano|composite|alloy|coating|thin film|ceramic|metallurg|polymer|crystal|concrete'),
    (13, 'physics-and-astronomy',        'Physics and Astronomy',         'physic|quantum|particle|photon|optic|laser|\yatom|nuclear|plasma|gravitat|cosmol|astron|astro|relativ|electromagnet|semiconductor|magnet'),
    (14, 'chemistry',                    'Chemistry',                     'chemi|catalys|cataly|synthesis|\ycompound|molecule|molecular|spectroscop|electrochem|fluoride|oxid'),
    (15, 'medicine-and-health',          'Medicine and Health',           'medicin|medical|clinical|disease|diagnos|treatment|therapy|cancer|tumo|tumou|patient|health|surger|surgical|virus|viral|covid|infection|epidemiol|pharmac|syndrome|pregnan|cardiac|cardiovascular|immun|antibod|hormon|lesion|\ytumor'),
    (16, 'biology-and-life-sciences',    'Biology and Life Sciences',     'biolog|biological|\ygen(e|omic)|protein|enzyme|\ycells?\y|microb|bacteri|viruse|plant|animal|ecolog|ecosystem|specie|evolution|botan|zool|photosynth|metabolis'),
    (17, 'agriculture-and-food',         'Agriculture and Food',          'agricultur|\ycrops?\y|\yfood\y|farm|agronom|livestock|fisher|horticult|soil fertili'),
    (18, 'environment-and-earth-science','Environment and Earth Science', 'environ|climate|sustainab|\yearth\y|geolog|water|ocean|atmospher|renewable|energy|pollut|biodivers|forestry|mineral');

-- Create the field nodes.
INSERT INTO topics (id, slug, name, kind)
SELECT gen_random_uuid(), s.slug, s.name, 'field'
FROM field_seed s
ON CONFLICT (slug) DO NOTHING;

-- Attach each topic to the highest-priority matching field.
WITH matches AS (
    SELECT DISTINCT ON (t.id)
        t.id AS topic_id, f.id AS field_id
    FROM topics t
    JOIN field_seed s ON t.name ~* s.pattern
    JOIN topics f ON f.slug = s.slug AND f.kind = 'field'
    WHERE t.kind = 'topic' AND t.parent_id IS NULL
    ORDER BY t.id, s.ord
)
UPDATE topics t
SET parent_id = m.field_id
FROM matches m
WHERE t.id = m.topic_id;

DROP TABLE field_seed;
