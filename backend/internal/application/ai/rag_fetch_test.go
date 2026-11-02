package ai

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	domainai "athena/backend/internal/domain/ai"
	"athena/backend/internal/domain/research"
)

func TestHTTPFetcher_StreamLifecycle(t *testing.T) {
	// Verify that HTTPFetcher keeps the stream open until caller explicitly closes it
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/pdf")
		w.WriteHeader(http.StatusOK)
		// Send data in chunks with slight delay to ensure context cancellation does not occur mid-stream
		for i := 0; i < 5; i++ {
			_, _ = w.Write([]byte("%PDF-1.4 sample payload chunk\n"))
			if flusher, ok := w.(http.Flusher); ok {
				flusher.Flush()
			}
			time.Sleep(5 * time.Millisecond)
		}
	}))
	defer srv.Close()

	fetcher := HTTPFetcher{}
	ctx := context.Background()

	body, err := fetcher.Fetch(ctx, srv.URL)
	require.NoError(t, err)
	require.NotNil(t, body)

	// Read all bytes after Fetch() has already returned
	data, err := io.ReadAll(body)
	require.NoError(t, err, "reading body after Fetch returned must not fail with context canceled")
	assert.Contains(t, string(data), "%PDF-1.4 sample payload chunk")

	// Closing body should be safe and idempotent
	err = body.Close()
	assert.NoError(t, err)
}

type fakeFetcherWithPDF struct {
	htmlContent string
	pdfContent  string
	pdfFetched  bool
}

func (f *fakeFetcherWithPDF) Fetch(ctx context.Context, docURL string) (io.ReadCloser, error) {
	if docURL == "https://publisher.com/articles/123.pdf" {
		f.pdfFetched = true
		return io.NopCloser(strings.NewReader(f.pdfContent)), nil
	}
	return io.NopCloser(strings.NewReader(f.htmlContent)), nil
}

type memoryChunkWriter struct {
	chunks  []domainai.Chunk
	vectors [][]float32
}

func (m *memoryChunkWriter) ReplaceChunks(ctx context.Context, paperID uuid.UUID,
	chunks []domainai.Chunk, vectors [][]float32, modelID string) error {
	m.chunks = chunks
	m.vectors = vectors
	return nil
}

type stubExtractor struct{}

func (stubExtractor) Extract(ctx context.Context, r io.Reader) (string, error) {
	data, err := io.ReadAll(r)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func TestRAGService_HTMLCitationPDFDiscovery(t *testing.T) {
	paperID := uuid.New()
	detail := research.PaperDetail{
		Summary: research.PaperSummary{
			ID:           paperID,
			Title:        "Advanced LLM Reasoning",
			IsOpenAccess: true,
		},
		BestOAURL: "https://publisher.com/articles/123",
	}

	paperStore := &fakePapers{detail: detail}
	chunkWriter := &memoryChunkWriter{}

	// HTML page containing citation_pdf_url pointing to 123.pdf
	landingHTML := `<!DOCTYPE html><html><head>
<meta name="citation_pdf_url" content="https://publisher.com/articles/123.pdf">
</head><body><p>Short abstract</p></body></html>`

	pdfContent := "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n" +
		strings.Repeat("Detailed full-text methodology and extensive empirical findings. ", 50)

	fetcher := &fakeFetcherWithPDF{
		htmlContent: landingHTML,
		pdfContent:  pdfContent,
	}

	rag := NewRAGService(paperStore, chunkWriter, stubExtractor{}, nil, fetcher, nil)
	count, err := rag.IngestPaper(context.Background(), paperID)
	require.NoError(t, err)
	assert.True(t, fetcher.pdfFetched, "expected citation PDF to be discovered and fetched from HTML metadata")
	assert.Greater(t, count, 0, "expected chunks to be produced")
}
