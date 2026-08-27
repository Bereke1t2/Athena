// Chunking for the RAG pipeline (docs/architecture/ai-rag.md §4): ~800-token
// target with 12% overlap, paragraph-aware, light section detection from
// heading-like lines.
package ai

import (
	"crypto/sha256"
	"encoding/hex"
	"regexp"
	"strings"
)

const (
	chunkTargetTokens  = 800
	chunkOverlapTokens = 96 // ~12%
	tokensPerChar      = 4.0
	minChunkTokens     = 40
)

var headingRe = regexp.MustCompile(`(?m)^(\d+(\.\d+)*\.?\s+\S.{2,80}|[A-Z][A-Z0-9 ,\-]{4,60})$`)

// CleanText normalizes raw PDF text: re-joins hyphenated line breaks,
// collapses runs of whitespace and drops very short junk lines.
func CleanText(s string) string {
	s = strings.ReplaceAll(s, "\r\n", "\n")
	// de-hyphenation: "embed-\ning" -> "embedding"
	s = regexp.MustCompile(`(\p{L})-\n(\p{L})`).ReplaceAllString(s, "$1$2")
	lines := strings.Split(s, "\n")
	out := make([]string, 0, len(lines))
	for _, ln := range lines {
		ln = strings.TrimSpace(ln)
		if ln == "" {
			if len(out) > 0 && out[len(out)-1] != "" {
				out = append(out, "")
			}
			continue
		}
		if len([]rune(ln)) <= 1 { // page furniture artifacts
			continue
		}
		out = append(out, ln)
	}
	return strings.TrimSpace(strings.Join(out, "\n"))
}

type block struct {
	text    string
	heading string
}

// ChunkText splits cleaned text into ordered chunks. Section-aware: a
// heading-like line starts a new section; paragraphs are packed up to the
// token target with a tail overlap carried into the next chunk.
func ChunkText(cleaned string) []ChunkDraft {
	blocks := splitBlocks(cleaned)
	if len(blocks) == 0 {
		return nil
	}

	var drafts []ChunkDraft
	var cur strings.Builder
	curTokens := 0
	section := ""

	flush := func() {
		text := strings.TrimSpace(cur.String())
		cur.Reset()
		curTokens = 0
		if approxTokens(text) < minChunkTokens && len(drafts) > 0 {
			// Too small to stand alone — merge into previous draft.
			prev := drafts[len(drafts)-1]
			drafts[len(drafts)-1].Content = prev.Content + "\n" + text
			return
		}
		if text != "" {
			drafts = append(drafts, ChunkDraft{Content: text, SectionPath: section})
		}
	}

	for _, bl := range blocks {
		if bl.heading != "" {
			if cur.Len() > 0 || curTokens > 0 {
				flush()
			}
			section = bl.heading
		}
		paragraphs := strings.Split(bl.text, "\n\n")
		for _, para := range paragraphs {
			para = strings.TrimSpace(para)
			if para == "" {
				continue
			}
			pTok := approxTokens(para)
			// Oversized paragraph: hard-split on sentence boundaries.
			for pTok+curTokens > chunkTargetTokens && pTok > minChunkTokens {
				overlap := overlapTail(cur.String())
				flush()
				if overlap != "" {
					cur.WriteString(overlap)
					curTokens = approxTokens(overlap)
				}
				cut := cutAtTokenBoundary(para, chunkTargetTokens-curTokens)
				cur.WriteString(cut)
				curTokens += approxTokens(cut)
				para = strings.TrimSpace(para[len(cut):])
				pTok = approxTokens(para)
				if para == "" {
					break
				}
				// Keep chunks flowing: emit what we have when full.
				if curTokens >= chunkTargetTokens {
					flush()
				}
			}
			if para == "" {
				continue
			}
			if curTokens+pTok > chunkTargetTokens && curTokens > 0 {
				flush()
			}
			if cur.Len() > 0 {
				cur.WriteString("\n\n")
			}
			cur.WriteString(para)
			curTokens += pTok
		}
	}
	flush()

	for i := range drafts {
		drafts[i].Seq = i
		drafts[i].SectionPath = strings.TrimSpace(drafts[i].SectionPath)
		sum := sha256.Sum256([]byte(drafts[i].Content))
		drafts[i].ContentHash = hex.EncodeToString(sum[:])
		drafts[i].TokenCount = approxTokens(drafts[i].Content)
	}
	return drafts
}

// ChunkDraft is one produced chunk before persistence assigns IDs.
type ChunkDraft struct {
	Seq         int
	SectionPath string
	Content     string
	TokenCount  int
	ContentHash string
}

func splitBlocks(cleaned string) []block {
	var blocks []block
	var cur strings.Builder
	heading := ""
	flushBlock := func() {
		if t := strings.TrimSpace(cur.String()); t != "" {
			blocks = append(blocks, block{text: t, heading: heading})
		}
		cur.Reset()
	}
	for _, ln := range strings.Split(cleaned, "\n") {
		if isHeadingLine(ln) {
			flushBlock()
			heading = strings.TrimSpace(ln)
			continue
		}
		cur.WriteString(ln)
		cur.WriteByte('\n')
	}
	flushBlock()
	return blocks
}

func isHeadingLine(ln string) bool {
	t := strings.TrimSpace(ln)
	if t == "" || len(t) > 80 || len(t) < 4 {
		return false
	}
	if strings.HasSuffix(t, ".") || strings.HasSuffix(t, ",") {
		return false
	}
	return headingRe.MatchString(t)
}

func approxTokens(s string) int {
	if s == "" {
		return 0
	}
	n := int(float64(len(s)) / tokensPerChar)
	if n < 1 {
		n = 1
	}
	return n
}

// overlapTail returns the last ~chunkOverlapTokens worth of text so the next
// chunk keeps local context.
func overlapTail(text string) string {
	if text == "" {
		return ""
	}
	target := chunkOverlapTokens * int(tokensPerChar)
	runes := []rune(text)
	if len(runes) <= target {
		return text + "\n"
	}
	cut := len(runes) - target
	// Snap to whitespace to avoid splitting a word.
	for cut < len(runes) && !isSpaceRune(runes[cut]) {
		cut++
	}
	return strings.TrimSpace(string(runes[cut:])) + "\n"
}

func cutAtTokenBoundary(s string, maxTokens int) string {
	limit := maxTokens * int(tokensPerChar)
	if limit >= len(s) {
		return s
	}
	runes := []rune(s)
	if limit > len(runes) {
		limit = len(runes)
	}
	for limit > 0 && !isSpaceRune(runes[limit-1]) {
		limit--
	}
	if limit == 0 {
		limit = maxTokens * int(tokensPerChar)
		if limit > len(runes) {
			limit = len(runes)
		}
	}
	return strings.TrimSpace(string(runes[:limit]))
}

func isSpaceRune(r rune) bool {
	return r == ' ' || r == '\t' || r == '\n' || r == '\r'
}
