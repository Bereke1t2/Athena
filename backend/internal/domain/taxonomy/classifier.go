// Package taxonomy classifies topic tags under canonical fields.
package taxonomy

import (
	"regexp"
	"strings"
)

// FieldRule pairs a canonical field slug with its detection pattern and order.
type FieldRule struct {
	Slug    string
	Name    string
	Pattern *regexp.Regexp
}

var canonicalFieldRules []FieldRule

func init() {
	// Raw pattern definitions aligned with migration 000009_seed_fields.
	// In Go regexp syntax, \b represents word boundaries (mapping to \y in Postgres).
	rawRules := []struct {
		slug    string
		name    string
		pattern string
	}{
		{
			slug:    "history-and-archaeology",
			name:    "History and Archaeology",
			pattern: `(?i)(histor|archaeol|ancient|medieval|antiquit|heritage|\bart(s)?\b.*(excavat)|paleo)`,
		},
		{
			slug:    "philosophy-and-religion",
			name:    "Philosophy and Religion",
			pattern: `(?i)(philosoph|ethic|moral|metaphysic|epistemolog|religio|theolog)`,
		},
		{
			slug:    "law",
			name:    "Law",
			pattern: `(?i)(\blaws?\b|legal|judicial|judgment|jurispruden|crimin|justice|constitutiona|statut)`,
		},
		{
			slug:    "arts-and-humanities",
			name:    "Arts and Humanities",
			pattern: `(?i)(literar|literature|linguistic|music|theatre|theater|film|poetr|cultural studies|\bculture\b|visual|photograph|art history|\barts?\b)`,
		},
		{
			slug:    "education",
			name:    "Education",
			pattern: `(?i)(education|pedagog|teaching|curriculum|\bstudents?\b|classroom|school)`,
		},
		{
			slug:    "psychology-and-neuroscience",
			name:    "Psychology and Neuroscience",
			pattern: `(?i)(psycholog|neuro|cognit|\bbrain\b|psychiatric|mental health|behavio|perception|emotion)`,
		},
		{
			slug:    "sociology-and-politics",
			name:    "Sociology and Politics",
			pattern: `(?i)(sociolog|social|politic|governance|policy|democra|migration|gender|inequalit|urban|community)`,
		},
		{
			slug:    "economics-and-business",
			name:    "Economics and Business",
			pattern: `(?i)(econom|business|market|financ|bank|trade|commerce|corporate|entrepreneur|accounting|manag|monetary|fiscal)`,
		},
		{
			slug:    "mathematics",
			name:    "Mathematics",
			pattern: `(?i)(mathemat|algebra|geometr|topolog|calculus|number theory|probabilit|statistic|optimiz|optimis|combinatoric|graph theory|algorithm)`,
		},
		{
			slug:    "computer-science",
			name:    "Computer Science",
			pattern: `(?i)(\bai\b|artificial intelligence|machine learning|deep learning|neural network|natural language|computer vision|image processing|robotic|software|computing|cybersecurity|blockchain|data mining|internet of things|cloud comput|\bvlsi\b|integrated circuit|error correct|programming|\bcodes?\b.*decod|semantic web|database|network security|human-computer)`,
		},
		{
			slug:    "engineering-and-technology",
			name:    "Engineering and Technology",
			pattern: `(?i)(engineer|mechanical|manufactur|structural|thermo|fluid|automation|control system|telecommunicat|satellite|antenna|radar|vehicle|brake|weld|machinin)`,
		},
		{
			slug:    "materials-science",
			name:    "Materials Science",
			pattern: `(?i)(material|nano|composite|alloy|coating|thin film|ceramic|metallurg|polymer|crystal|concrete)`,
		},
		{
			slug:    "physics-and-astronomy",
			name:    "Physics and Astronomy",
			pattern: `(?i)(physic|quantum|particle|photon|optic|laser|\batom|nuclear|plasma|gravitat|cosmol|astron|astro|relativ|electromagnet|semiconductor|magnet|superconduct)`,
		},
		{
			slug:    "chemistry",
			name:    "Chemistry",
			pattern: `(?i)(chemi|catalys|cataly|synthesis|\bcompound|molecule|molecular|spectroscop|electrochem|fluoride|oxid)`,
		},
		{
			slug:    "medicine-and-health",
			name:    "Medicine and Health",
			pattern: `(?i)(medicin|medical|clinical|disease|diagnos|treatment|therapy|cancer|tumo|tumou|patient|health|surger|surgical|virus|viral|covid|infection|epidemiol|pharmac|syndrome|pregnan|cardiac|cardiovascular|immun|antibod|hormon|lesion|\btumor)`,
		},
		{
			slug:    "biology-and-life-sciences",
			name:    "Biology and Life Sciences",
			pattern: `(?i)(biolog|biological|\bgen(e|omic)|protein|enzyme|\bcells?\b|microb|bacteri|viruse|plant|animal|ecolog|ecosystem|specie|evolution|botan|zool|photosynth|metabolis)`,
		},
		{
			slug:    "agriculture-and-food",
			name:    "Agriculture and Food",
			pattern: `(?i)(agricultur|\bcrops?\b|\bfood\b|farm|agronom|livestock|fisher|horticult|soil fertili)`,
		},
		{
			slug:    "environment-and-earth-science",
			name:    "Environment and Earth Science",
			pattern: `(?i)(environ|climate|sustainab|\bearth\b|geolog|water|ocean|atmospher|renewable|energy|pollut|biodivers|forestry|mineral)`,
		},
	}

	for _, r := range rawRules {
		canonicalFieldRules = append(canonicalFieldRules, FieldRule{
			Slug:    r.slug,
			Name:    r.name,
			Pattern: regexp.MustCompile(r.pattern),
		})
	}
}

// CanonicalFields returns the registered field slugs in precedence order.
func CanonicalFields() []string {
	out := make([]string, len(canonicalFieldRules))
	for i, r := range canonicalFieldRules {
		out[i] = r.Slug
	}
	return out
}

// Classify maps an incoming topic name or slug to its canonical field slug.
// Precedence:
//  1. Fast-path prefix check for known academic taxonomies (arXiv taxonomy prefixes)
//  2. Exact match against canonical field slugs/names
//  3. Ordered regex rule matches matching 000009_seed_fields.
func Classify(name, slug string) string {
	nameLower := strings.ToLower(strings.TrimSpace(name))
	slugLower := strings.ToLower(strings.TrimSpace(slug))

	// If the topic is itself already a top-level field, return its own slug.
	for _, r := range canonicalFieldRules {
		if slugLower == r.Slug || nameLower == strings.ToLower(r.Name) {
			return r.Slug
		}
	}

	// 1. Academic repository taxonomy fast-paths (arXiv categories)
	if match := classifyArxivCategory(nameLower, slugLower); match != "" {
		return match
	}

	// 2. Pattern matching against the topic name and slug
	for _, r := range canonicalFieldRules {
		// Guard against false positives where broad humanities/social terms overlap STEM terminology
		if r.Slug == "arts-and-humanities" && strings.Contains(nameLower, "thin film") {
			continue
		}
		if r.Slug == "sociology-and-politics" && (strings.Contains(nameLower, "monetary") || strings.Contains(nameLower, "fiscal") || strings.Contains(nameLower, "bank")) {
			continue
		}

		if r.Pattern.MatchString(nameLower) || r.Pattern.MatchString(slugLower) {
			return r.Slug
		}
	}

	return ""
}

func classifyArxivCategory(name, slug string) string {
	candidates := []string{name, slug}
	for _, c := range candidates {
		switch {
		case strings.HasPrefix(c, "cs.") || strings.HasPrefix(c, "cs-") || c == "cs":
			return "computer-science"
		case strings.HasPrefix(c, "math.") || strings.HasPrefix(c, "math-") || c == "math":
			return "mathematics"
		case strings.HasPrefix(c, "stat.ml"):
			return "computer-science"
		case strings.HasPrefix(c, "stat.") || strings.HasPrefix(c, "stat-") || c == "stat":
			return "mathematics"
		case strings.HasPrefix(c, "physics.") || strings.HasPrefix(c, "physics-") ||
			strings.HasPrefix(c, "quant-ph") || strings.HasPrefix(c, "astro-ph") ||
			strings.HasPrefix(c, "hep-") || strings.HasPrefix(c, "cond-mat") ||
			strings.HasPrefix(c, "gr-qc") || strings.HasPrefix(c, "nucl-"):
			return "physics-and-astronomy"
		case strings.HasPrefix(c, "q-bio.nc"):
			return "psychology-and-neuroscience"
		case strings.HasPrefix(c, "q-bio.") || strings.HasPrefix(c, "q-bio-") || c == "q-bio":
			return "biology-and-life-sciences"
		case strings.HasPrefix(c, "q-fin.") || strings.HasPrefix(c, "econ."):
			return "economics-and-business"
		case strings.HasPrefix(c, "eess.") || strings.HasPrefix(c, "eess-"):
			return "engineering-and-technology"
		}
	}
	return ""
}
