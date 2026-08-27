// Command searchbench runs Athena's Phase 2 golden query set against a live
// API and reports relevance spot-check data plus latency percentiles
// (roadmap.md Phase 2 acceptance).
//
// Usage:
//
//	go run ./cmd/searchbench -base http://localhost:8081 -out report.md
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strings"
	"time"
)

type queryCase struct {
	q     string // raw query string appended after /api/v1/search?
	label string // what a human should eyeball in the top-3
}

func goldenSet() []queryCase {
	single := []string{
		"protein", "graphene", "quantum", "neurons", "catalysis", "algorithm",
		"photosynthesis", "inflation", "seismology", "peptides", "taxonomy",
		"superconductors", "microbiome", "lidar", "chromatography",
	}
	pairs := []string{
		"machine learning", "climate change", "cancer immunotherapy",
		"neural networks", "gene editing", "carbon capture", "dark matter",
		"stem cells", "reinforcement learning", "quantum computing",
		"gut bacteria", "solar cells", "data privacy", "robotics control",
		"water purification", "bone regeneration", "speech recognition",
		"urban planning", "coastal erosion", "battery materials",
	}
	long := []string{
		"how do transformers handle long context windows",
		"research about whether consciousness can emerge from artificial systems",
		"methods for detecting exoplanets using transit photometry",
		"impact of microplastics on marine food chains",
		"approaches to reduce hallucinations in large language models",
		"role of the gut microbiome in mental health",
		"techniques for carbon sequestration in agricultural soils",
		"deep learning models for weather forecasting",
		"ethical considerations of gene drives in wild populations",
		"perovskite stability challenges in commercial solar panels",
	}
	filters := []queryCase{
		{enc("q", "covid vaccine", "open_access", "true", "limit", "10"), "filter: covid vaccine + OA"},
		{enc("q", "transformer attention", "min_citations", "50", "limit", "10"), "filter: attention + min_cit"},
		{enc("q", "deep learning", "sort", "newest", "limit", "10"), "sort=newest deep learning"},
		{enc("q", "deep learning", "sort", "citations", "limit", "10"), "sort=citations deep learning"},
		{enc("open_access", "true", "limit", "5"), "filters only (empty q) OA"},
		{enc("sort", "newest", "limit", "5"), "filters only (empty q) newest"},
		{enc("q", "crispr", "published_after", "2024-01-01", "limit", "10"), "crispr after 2024"},
	}

	var cases []queryCase
	for _, s := range single {
		cases = append(cases,
			queryCase{q: "q=" + url.QueryEscape(s) + "&limit=3", label: s})
	}
	for _, p := range pairs {
		cases = append(cases,
			queryCase{q: "q=" + url.QueryEscape(p) + "&limit=3", label: p})
	}
	for _, l := range long {
		cases = append(cases,
			queryCase{q: "q=" + url.QueryEscape(l) + "&limit=3", label: l})
	}
	cases = append(cases, filters...)

	return cases
}

func enc(kv ...string) string {
	v := url.Values{}
	for i := 0; i+1 < len(kv); i += 2 {
		v.Set(kv[i], kv[i+1])
	}
	return v.Encode()
}

type result struct {
	Label      string   `json:"label"`
	StatusOK   bool     `json:"status_ok"`
	Cold       float64  `json:"cold_ms"`
	Warm       float64  `json:"warm_ms"`
	Estimate   int64    `json:"total_estimate"`
	TopTitles  []string `json:"top_titles"`
	ErrorOrNot string   `json:"error,omitempty"`
}

func percentile(sorted []float64, p float64) float64 {
	if len(sorted) == 0 {
		return 0
	}
	idx := int(p/100*float64(len(sorted)-1) + 0.5)
	if idx >= len(sorted) {
		idx = len(sorted) - 1
	}
	return sorted[idx]
}

func main() {
	base := flag.String("base", "http://localhost:8081", "API base URL")
	out := flag.String("out", "", "write markdown report here (default stdout)")
	flag.Parse()

	client := &http.Client{
		Timeout: 15 * time.Second,
		// Fresh connection per request: a reused keep-alive that the server
		// just closed produces a protocol-level 400 whose plain-text body
		// then fails JSON decoding (observed as bogus bench failures).
		Transport: &http.Transport{DisableKeepAlives: true},
	}
	var results []result

	// One warmup request so process/pool/plan boot cost isn't billed to the
	// first measured query ("cold" below means cache-miss, not server start).
	warm := &result{Label: "warmup"}
	timedGet(client, *base, "q=graphene&limit=1", warm)
	if !warm.StatusOK {
		fmt.Fprintf(os.Stderr, "warmup failed: %s\n", warm.ErrorOrNot)
	}

	for _, tc := range goldenSet() {
		res := result{Label: tc.label}

		res.Cold = timedGet(client, *base, tc.q, &res)
		time.Sleep(80 * time.Millisecond) // let the async cache write land
		res.Warm = timedGet(client, *base, tc.q, &res)

		results = append(results, res)
	}

	report := render(results, *out)
	if *out != "" {
		if err := os.WriteFile(*out, []byte(report), 0o644); err != nil {
			fatal(err)
		}
		fmt.Printf("report written to %s\n", *out)
	} else {
		fmt.Print(report)
	}
}

func timedGet(client *http.Client, base, rawQuery string, res *result) float64 {
	start := time.Now()
	resp, err := client.Get(base + "/api/v1/search?" + rawQuery)
	if err != nil {
		res.StatusOK = false
		res.ErrorOrNot = err.Error()
		return float64(time.Since(start).Milliseconds())
	}
	defer resp.Body.Close()

	raw, readErr := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if readErr != nil {
		res.StatusOK = false
		res.ErrorOrNot = readErr.Error()
		return float64(time.Since(start).Milliseconds())
	}
	var body struct {
		Items []struct {
			Paper struct {
				Title string `json:"title"`
			} `json:"paper"`
		} `json:"items"`
		Meta struct {
			TotalEstimate int64  `json:"total_estimate"`
			ModeUsed      string `json:"mode_used"`
		} `json:"meta"`
		Error *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(raw, &body); err != nil {
		res.StatusOK = false
		res.ErrorOrNot = fmt.Sprintf("%v | body[0..120]=%q", err, string(raw[:min(len(raw), 120)]))
		return float64(time.Since(start).Milliseconds())
	}
	ms := float64(time.Since(start).Milliseconds())

	if resp.StatusCode != http.StatusOK || body.Error != nil {
		res.StatusOK = false
		if body.Error != nil {
			res.ErrorOrNot = body.Error.Message
		} else {
			res.ErrorOrNot = fmt.Sprintf("HTTP %d", resp.StatusCode)
		}
		return ms
	}
	res.StatusOK = true
	res.Estimate = body.Meta.TotalEstimate
	res.TopTitles = nil
	for i, it := range body.Items {
		if i == 3 {
			break
		}
		res.TopTitles = append(res.TopTitles, it.Paper.Title)
	}
	return ms
}

func render(results []result, outPath string) string {
	var b strings.Builder
	title := "# Search Golden Set Report"
	if outPath != "" {
		title += fmt.Sprintf("\n\n_Generated %s against local API; corpus snapshot._",
			time.Now().UTC().Format(time.RFC3339))
	}
	b.WriteString(title + "\n\n")

	var colds, warms []float64
	okCount := 0
	for _, r := range results {
		if r.StatusOK {
			okCount++
		}
		colds = append(colds, r.Cold)
		warms = append(warms, r.Warm)
	}
	sort.Float64s(colds)
	sort.Float64s(warms)

	b.WriteString("## Latency\n\n")
	b.WriteString(fmt.Sprintf("| metric | cold (cache miss) | warm (cached) |\n|---|---|---|\n"))
	b.WriteString(fmt.Sprintf("| p50 | %.0f ms | %.0f ms |\n", percentile(colds, 50), percentile(warms, 50)))
	b.WriteString(fmt.Sprintf("| p95 | %.0f ms | %.0f ms |\n", percentile(colds, 95), percentile(warms, 95)))
	b.WriteString(fmt.Sprintf("| max | %.0f ms | %.0f ms |\n", colds[len(colds)-1], warms[len(warms)-1]))
	b.WriteString(fmt.Sprintf("\n%d/%d queries returned 200.\n", okCount, len(results)))
	b.WriteString(fmt.Sprintf("Acceptance target: **p95 < 300ms** (corpus ≥100k papers; current corpus smaller — treat as provisional).\n\n"))

	b.WriteString("## Relevance spot-check sheet\n\n")
	b.WriteString("Eyeball rule: at least one top-3 title should clearly match the label.\n\n")
	b.WriteString("| # | label | est | cold→warm | top titles |\n|---|---|---|---|---|\n")
	for i, r := range results {
		status := "ok"
		if !r.StatusOK {
			status = "ERROR: " + r.ErrorOrNot
		}
		titles := strings.Join(r.TopTitles, " • ")
		if titles == "" {
			titles = "_(no results)_"
		}
		titles = strings.ReplaceAll(titles, "|", "/")
		b.WriteString(fmt.Sprintf("| %d | %s | %d | %.0f→%.0f ms | %s [%s] |\n",
			i+1, r.Label, r.Estimate, r.Cold, r.Warm, trunc(titles, 160), status))
	}
	return b.String()
}

func trunc(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n-3] + "..."
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, "searchbench:", err)
	os.Exit(1)
}
