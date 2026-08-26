package research

import "github.com/google/uuid"

// Decision is the outcome of identity resolution for an incoming paper.
type Decision int

const (
	CreateNew Decision = iota
	MergeInto
	ConflictKeepBoth
)

// String renders decisions for logs/metrics.
func (d Decision) String() string {
	switch d {
	case CreateNew:
		return "create_new"
	case MergeInto:
		return "merge_into"
	default:
		return "conflict_keep_both"
	}
}

// IdentityMatch carries what persistence found before deciding. MatchedIDs
// holds distinct papers hit by incoming identifiers; FingerprintCandidate is
// a paper with equal fingerprint (nil when none), with its canonical DOI and
// arXiv ID for the conservative merge rule.
type IdentityMatch struct {
	MatchedIDs          []uuid.UUID
	FingerprintCandidate *uuid.UUID
	CandidateDOI        string
	CandidateArxivID    string
}

// ResolveTarget decides which stored paper (if any) an incoming record refers
// to. Precedence: identifier match → conservative fingerprint merge → new
// row. Multiple identifier hits are a conflict: we refuse to merge rather than
// risk collapsing two distinct works.
func ResolveTarget(in Paper, m IdentityMatch) (uuid.UUID, Decision) {
	switch len(m.MatchedIDs) {
	case 1:
		return m.MatchedIDs[0], MergeInto
	case 0:
	default:
		return uuid.Nil, ConflictKeepBoth
	}

	if m.FingerprintCandidate != nil && in.DOI() == "" && m.CandidateDOI == "" &&
		in.ArxivID() == "" && m.CandidateArxivID == "" {
		return *m.FingerprintCandidate, MergeInto
	}
	return uuid.Nil, CreateNew
}
