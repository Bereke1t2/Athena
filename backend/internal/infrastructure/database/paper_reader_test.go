package database

import (
	"testing"

	"athena/backend/internal/domain/research"
)

func TestClassifyStance(t *testing.T) {
	tests := []struct {
		name    string
		context string
		want    research.CitationStance
	}{
		{
			name:    "empty string defaults to mentions",
			context: "",
			want:    research.StanceMentions,
		},
		{
			name:    "supports via confirmation",
			context: "Our empirical findings confirm the scaling hypothesis proposed by Vaswani et al.",
			want:    research.StanceSupports,
		},
		{
			name:    "supports via builds upon",
			context: "This architecture builds upon the transformer block design.",
			want:    research.StanceSupports,
		},
		{
			name:    "contradicts via discrepancy",
			context: "In contrast to previous claims, our benchmarks show significant performance discrepancy.",
			want:    research.StanceContradicts,
		},
		{
			name:    "contradicts via refute",
			context: "These results refute earlier assumptions regarding attention sparsity.",
			want:    research.StanceContradicts,
		},
		{
			name:    "mentions background citation",
			context: "For a comprehensive survey of deep reinforcement learning, see Mnih et al.",
			want:    research.StanceMentions,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ClassifyStance(tt.context)
			if got != tt.want {
				t.Errorf("ClassifyStance(%q) = %v, want %v", tt.context, got, tt.want)
			}
		})
	}
}
