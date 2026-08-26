package research

import (
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

func idFor(t *testing.T, n int) uuid.UUID {
	t.Helper()
	id, err := uuid.NewV7()
	if err != nil {
		t.Fatal(err)
	}
	_ = n
	return id
}

func TestResolveTargetSingleIdentifierMatchMerges(t *testing.T) {
	existing := idFor(t, 1)
	in := Paper{Title: "T"}
	got, d := ResolveTarget(in, IdentityMatch{MatchedIDs: []uuid.UUID{existing}})
	assert.Equal(t, MergeInto, d)
	assert.Equal(t, existing, got)
}

func TestResolveTargetMultiMatchConflicts(t *testing.T) {
	got, d := ResolveTarget(Paper{}, IdentityMatch{
		MatchedIDs: []uuid.UUID{idFor(t, 1), idFor(t, 2)},
	})
	assert.Equal(t, ConflictKeepBoth, d)
	assert.Equal(t, uuid.Nil, got)
}

func TestResolveTargetConservativeFingerprintMerge(t *testing.T) {
	fp := idFor(t, 3)

	t.Run("merges when no DOI/arXiv on either side", func(t *testing.T) {
		got, d := ResolveTarget(Paper{}, IdentityMatch{
			FingerprintCandidate: &fp,
		})
		assert.Equal(t, MergeInto, d)
		assert.Equal(t, fp, got)
	})

	t.Run("creates new when incoming carries a DOI", func(t *testing.T) {
		in := Paper{Identifiers: []Identifier{{Type: IDTypeDOI, Value: "10.1/x"}}}
		got, d := ResolveTarget(in, IdentityMatch{FingerprintCandidate: &fp})
		assert.Equal(t, CreateNew, d)
		assert.Equal(t, uuid.Nil, got)
	})

	t.Run("creates new when candidate already has a DOI", func(t *testing.T) {
		got, d := ResolveTarget(Paper{}, IdentityMatch{
			FingerprintCandidate: &fp,
			CandidateDOI:         "10.1/y",
		})
		assert.Equal(t, CreateNew, d)
		assert.Equal(t, uuid.Nil, got)
	})

	t.Run("creates new when candidate has an arXiv ID", func(t *testing.T) {
		got, d := ResolveTarget(Paper{}, IdentityMatch{
			FingerprintCandidate: &fp,
			CandidateArxivID:     "2312.00752",
		})
		assert.Equal(t, CreateNew, d)
		assert.Equal(t, uuid.Nil, got)
	})
}

func TestDecisionString(t *testing.T) {
	assert.False(t, strings.Contains(CreateNew.String(), "conflict"))
	assert.Equal(t, "merge_into", MergeInto.String())
	assert.Equal(t, "conflict_keep_both", ConflictKeepBoth.String())
}
