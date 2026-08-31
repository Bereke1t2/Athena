package textextract_test

import (
	"context"
	"strings"
	"testing"

	"athena/backend/internal/infrastructure/textextract"
	"github.com/stretchr/testify/require"
)

func TestHTMLExtractor_Extract(t *testing.T) {
	htmlPayload := `<!DOCTYPE html>
<html>
<head>
    <title>Attention Is All You Need</title>
    <script>var x = 123;</script>
    <style>body { font-size: 14px; }</style>
</head>
<body>
    <header><nav>Home | Papers | About</nav></header>
    <article>
        <h1>Attention Is All You Need</h1>
        <p>The dominant sequence transduction models are based on complex recurrent or convolutional neural networks that include an encoder and a decoder. The best performing models also connect the encoder and decoder through an attention mechanism.</p>
        <h2>3 Model Architecture</h2>
        <p>Most competitive neural sequence transduction models have an encoder-decoder structure. Here, the encoder maps an input sequence of symbol representations to a sequence of continuous representations.</p>
        <h3>3.1 Scaled Dot-Product Attention</h3>
        <p>We call our particular attention "Scaled Dot-Product Attention". The input consists of queries and keys of dimension d_k, and values of dimension d_v.</p>
        <ul>
            <li>Self-attention enables constant number of operations to relate signals.</li>
            <li>Multi-head attention allows the model to jointly attend to information from different representation subspaces.</li>
        </ul>
    </article>
    <footer>Copyright 2026 Academic Press. All rights reserved.</footer>
</body>
</html>`

	extractor := textextract.NewHTMLExtractor()
	ctx := context.Background()

	text, err := extractor.Extract(ctx, strings.NewReader(htmlPayload))
	require.NoError(t, err)
	require.NotEmpty(t, text)

	// Check headings and sections
	require.Contains(t, text, "## Attention Is All You Need")
	require.Contains(t, text, "## 3 Model Architecture")
	require.Contains(t, text, "### 3.1 Scaled Dot-Product Attention")
	require.Contains(t, text, "• Self-attention enables constant number of operations")

	// Ensure scripts and navbars were stripped
	require.NotContains(t, text, "var x = 123")
	require.NotContains(t, text, "font-size: 14px")
	require.NotContains(t, text, "Home | Papers | About")
}

func TestCompositeExtractor_Sniffing(t *testing.T) {
	extractor := textextract.New()
	ctx := context.Background()

	// HTML payload
	htmlPayload := `<!DOCTYPE html><html><body><article><h1>Deep Residual Learning</h1><p>` +
		strings.Repeat("Deeper neural networks are more difficult to train. We present a residual learning framework to ease the training of networks that are substantially deeper than those used previously. ", 5) +
		`</p></article></body></html>`

	text, err := extractor.Extract(ctx, strings.NewReader(htmlPayload))
	require.NoError(t, err)
	require.Contains(t, text, "Deep Residual Learning")
	require.Contains(t, text, "residual learning framework")
}
