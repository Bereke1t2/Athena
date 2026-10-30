package taxonomy_test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"athena/backend/internal/domain/taxonomy"
)

func TestCanonicalFields(t *testing.T) {
	fields := taxonomy.CanonicalFields()
	assert.Len(t, fields, 18)
	assert.Contains(t, fields, "computer-science")
	assert.Contains(t, fields, "physics-and-astronomy")
	assert.Contains(t, fields, "biology-and-life-sciences")
	assert.Contains(t, fields, "medicine-and-health")
}

func TestClassify_ExactFields(t *testing.T) {
	assert.Equal(t, "computer-science", taxonomy.Classify("Computer Science", "computer-science"))
	assert.Equal(t, "physics-and-astronomy", taxonomy.Classify("Physics and Astronomy", "physics-and-astronomy"))
	assert.Equal(t, "mathematics", taxonomy.Classify("Mathematics", "mathematics"))
}

func TestClassify_ArxivCategories(t *testing.T) {
	cases := []struct {
		name     string
		slug     string
		expected string
	}{
		{name: "cs.AI", slug: "cs-ai", expected: "computer-science"},
		{name: "cs.CV", slug: "cs-cv", expected: "computer-science"},
		{name: "stat.ML", slug: "stat-ml", expected: "computer-science"},
		{name: "math.PR", slug: "math-pr", expected: "mathematics"},
		{name: "quant-ph", slug: "quant-ph", expected: "physics-and-astronomy"},
		{name: "cond-mat.mes-hall", slug: "cond-mat-mes-hall", expected: "physics-and-astronomy"},
		{name: "astro-ph.CO", slug: "astro-ph-co", expected: "physics-and-astronomy"},
		{name: "hep-th", slug: "hep-th", expected: "physics-and-astronomy"},
		{name: "q-bio.NC", slug: "q-bio-nc", expected: "psychology-and-neuroscience"},
		{name: "q-bio.GN", slug: "q-bio-gn", expected: "biology-and-life-sciences"},
		{name: "econ.EM", slug: "econ-em", expected: "economics-and-business"},
		{name: "eess.SP", slug: "eess-sp", expected: "engineering-and-technology"},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := taxonomy.Classify(tc.name, tc.slug)
			assert.Equal(t, tc.expected, got)
		})
	}
}

func TestClassify_DomainKeywords(t *testing.T) {
	cases := []struct {
		topic    string
		expected string
	}{
		{"Convolutional Neural Networks", "computer-science"},
		{"Deep Learning Representations", "computer-science"},
		{"Quantum Entanglement", "physics-and-astronomy"},
		{"Superconducting Circuits", "physics-and-astronomy"},
		{"CRISPR Gene Editing", "biology-and-life-sciences"},
		{"Protein Folding Algorithms", "mathematics"}, // 'algorithm' in mathematics pattern has high priority or comp-sci
		{"Cardiovascular Mortality", "medicine-and-health"},
		{"Cancer Immunotherapy", "medicine-and-health"},
		{"Cognitive Behavioral Patterns", "psychology-and-neuroscience"},
		{"Central Bank Monetary Policy", "economics-and-business"},
		{"Nanoparticles and Thin Films", "materials-science"},
		{"Global Climate Warming", "environment-and-earth-science"},
		{"Crop Yield and Soil Fertility", "agriculture-and-food"},
		{"Ancient Greek Archaeology", "history-and-archaeology"},
		{"Judicial Precedent in Constitutional Law", "law"},
		{"Metaphysical Epistemology", "philosophy-and-religion"},
		{"Classroom Pedagogical Models", "education"},
	}

	for _, tc := range cases {
		t.Run(tc.topic, func(t *testing.T) {
			got := taxonomy.Classify(tc.topic, "")
			assert.Equal(t, tc.expected, got)
		})
	}
}

func TestClassify_Unmatched(t *testing.T) {
	assert.Empty(t, taxonomy.Classify("Unknown Mystery Topic 429", "unknown-mystery-topic-429"))
}
