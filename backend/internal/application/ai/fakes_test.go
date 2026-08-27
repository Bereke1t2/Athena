package ai

import (
	"context"
	"errors"

	"github.com/google/uuid"

	domainai "athena/backend/internal/domain/ai"
	"athena/backend/internal/domain/research"
)

var errFakeWrite = errors.New("fake store write failure")

// fakeSummaryStore backs the summary tests.
type fakeSummaryStore struct {
	saved map[string]domainai.Summary
	fail  bool
}

func summaryKey(paperID uuid.UUID, l domainai.ExplanationLevel) string {
	return paperID.String() + "|" + string(l)
}

func (f *fakeSummaryStore) GetSummary(_ context.Context, id uuid.UUID, l domainai.ExplanationLevel) (domainai.Summary, error) {
	if s, ok := f.saved[summaryKey(id, l)]; ok {
		return s, nil
	}
	return domainai.Summary{}, domainai.ErrNotFound
}

func (f *fakeSummaryStore) SaveSummary(_ context.Context, s domainai.Summary) error {
	if f.fail {
		return errFakeWrite
	}
	if f.saved == nil {
		f.saved = map[string]domainai.Summary{}
	}
	f.saved[summaryKey(s.PaperID, s.Level)] = s
	return nil
}

// fakePapers serves one static paper detail.
type fakePapers struct{ detail research.PaperDetail }

func (f *fakePapers) GetDetailByID(context.Context, uuid.UUID) (research.PaperDetail, error) {
	return f.detail, nil
}

// fakeChunks returns a fixed chunk list.
type fakeChunks struct{ list []domainai.Chunk }

func (f *fakeChunks) ListChunks(context.Context, uuid.UUID) ([]domainai.Chunk, error) {
	return f.list, nil
}

// fakeIndexer counts ingest calls and installs its chunks into a target
// source afterwards (mimicking a successful index run).
type fakeIndexer struct {
	calls  int
	chunks []domainai.Chunk
	target *[]domainai.Chunk
}

func (f *fakeIndexer) IngestPaper(context.Context, uuid.UUID) (int, error) {
	f.calls++
	if f.target != nil {
		*f.target = f.chunks
	}
	return len(f.chunks), nil
}
