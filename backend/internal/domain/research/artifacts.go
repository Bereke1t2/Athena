package research

import (
	"net/url"
	"regexp"
	"strings"
)

// CodePlatform identifies the hosting provider of a source code repository.
type CodePlatform string

const (
	PlatformGitHub         CodePlatform = "github"
	PlatformGitLab         CodePlatform = "gitlab"
	PlatformHuggingFace    CodePlatform = "huggingface"
	PlatformPapersWithCode CodePlatform = "paperswithcode"
	PlatformOther          CodePlatform = "other"
)

// CodeRepository represents an open source software repository associated with a paper.
type CodeRepository struct {
	URL         string       `json:"url"`
	Platform    CodePlatform `json:"platform"`
	Owner       string       `json:"owner"`
	RepoName    string       `json:"repo_name"`
	Description string       `json:"description,omitempty"`
	IsOfficial  bool         `json:"is_official"`
	StarsCount  int          `json:"stars_count,omitempty"`
}

// DatasetPlatform identifies the hosting provider of an open dataset or model artifact.
type DatasetPlatform string

const (
	DatasetPlatformHuggingFace    DatasetPlatform = "huggingface"
	DatasetPlatformZenodo         DatasetPlatform = "zenodo"
	DatasetPlatformKaggle         DatasetPlatform = "kaggle"
	DatasetPlatformPapersWithCode DatasetPlatform = "paperswithcode"
	DatasetPlatformGitHub         DatasetPlatform = "github"
	DatasetPlatformOther          DatasetPlatform = "other"
)

// DatasetReference represents a dataset, benchmark, or artifact repository linked to a paper.
type DatasetReference struct {
	URL         string          `json:"url"`
	Platform    DatasetPlatform `json:"platform"`
	Name        string          `json:"name"`
	Description string          `json:"description,omitempty"`
}

var (
	// Regex matching GitHub repositories: github.com/:owner/:repo
	githubRegex = regexp.MustCompile(`(?i)\bhttps?://(?:www\.)?github\.com/([a-zA-Z0-9_\-\.]+)/([a-zA-Z0-9_\-\.]+)`)

	// Regex matching GitLab repositories: gitlab.com/:owner/:repo
	gitlabRegex = regexp.MustCompile(`(?i)\bhttps?://(?:www\.)?gitlab\.com/([a-zA-Z0-9_\-\.]+)/([a-zA-Z0-9_\-\.]+)`)

	// Regex matching Hugging Face models / spaces: huggingface.co/:owner/:repo
	huggingfaceModelRegex = regexp.MustCompile(`(?i)\bhttps?://(?:www\.)?huggingface\.co/(?:spaces/)?([a-zA-Z0-9_\-\.]+)/([a-zA-Z0-9_\-\.]+)`)

	// Regex matching Hugging Face datasets: huggingface.co/datasets/:owner/:dataset
	huggingfaceDatasetRegex = regexp.MustCompile(`(?i)\bhttps?://(?:www\.)?huggingface\.co/datasets/([a-zA-Z0-9_\-\.]+)/([a-zA-Z0-9_\-\.]+)`)

	// Regex matching Zenodo record: zenodo.org/record/:id or /records/:id
	zenodoRegex = regexp.MustCompile(`(?i)\bhttps?://(?:www\.)?zenodo\.org/(?:record|records)/([0-9]+)`)

	// Regex matching Kaggle datasets: kaggle.com/datasets/:owner/:dataset
	kaggleRegex = regexp.MustCompile(`(?i)\bhttps?://(?:www\.)?kaggle\.com/datasets/([a-zA-Z0-9_\-\.]+)/([a-zA-Z0-9_\-\.]+)`)

	// Regex matching Papers With Code: paperswithcode.com/paper/:slug
	papersWithCodeRegex = regexp.MustCompile(`(?i)\bhttps?://(?:www\.)?paperswithcode\.com/paper/([a-zA-Z0-9_\-\.]+)`)
)

// reservedGitHubPaths identifies non-repository paths on GitHub.
var reservedGitHubPaths = map[string]bool{
	"features":     true,
	"pricing":      true,
	"topics":       true,
	"collections":  true,
	"trending":     true,
	"explore":      true,
	"security":     true,
	"enterprise":   true,
	"about":        true,
	"blog":         true,
	"contact":      true,
	"login":        true,
	"signup":       true,
	"settings":     true,
	"orgs":         true,
	"organizations": true,
	"site":         true,
}

// cleanTrailingPunctuation strips punctuation frequently adhering to URLs in academic text.
func cleanTrailingPunctuation(raw string) string {
	for {
		trimmed := strings.TrimRight(raw, ".,;:)\"'>]}!?")
		if trimmed == raw {
			break
		}
		raw = trimmed
	}
	// Also strip trailing .git if present in URL
	raw = strings.TrimSuffix(raw, ".git")
	return strings.TrimSpace(raw)
}

// NormalizeRepoURL normalizes and canonicalizes a code repository URL.
func NormalizeRepoURL(raw string) string {
	raw = cleanTrailingPunctuation(raw)
	parsed, err := url.Parse(raw)
	if err != nil || parsed.Host == "" {
		return raw
	}
	parsed.Scheme = "https"
	parsed.Host = strings.ToLower(parsed.Host)
	parsed.RawQuery = ""
	parsed.Fragment = ""
	path := strings.TrimRight(parsed.Path, "/")
	path = strings.TrimSuffix(path, ".git")
	parsed.Path = path
	return parsed.String()
}

// ExtractArtifacts scans text content (such as paper abstracts, comments, or version links)
// and extracts code repositories and dataset links.
func ExtractArtifacts(text string, additionalURLs []string) ([]CodeRepository, []DatasetReference) {
	var repos []CodeRepository
	var datasets []DatasetReference

	seenRepos := make(map[string]bool)
	seenDatasets := make(map[string]bool)

	// Combine all text sources
	var sources []string
	if text != "" {
		sources = append(sources, text)
	}
	sources = append(sources, additionalURLs...)
	combinedText := strings.Join(sources, "\n")

	// 1. Extract Hugging Face Datasets first (to avoid collision with HF model matcher)
	hfDataMatches := huggingfaceDatasetRegex.FindAllStringSubmatch(combinedText, -1)
	for _, m := range hfDataMatches {
		if len(m) >= 3 {
			owner := m[1]
			datasetName := cleanTrailingPunctuation(m[2])
			canonicalURL := "https://huggingface.co/datasets/" + owner + "/" + datasetName
			if !seenDatasets[canonicalURL] {
				seenDatasets[canonicalURL] = true
				datasets = append(datasets, DatasetReference{
					URL:         canonicalURL,
					Platform:    DatasetPlatformHuggingFace,
					Name:        owner + "/" + datasetName,
					Description: "Hugging Face Dataset",
				})
			}
		}
	}

	// 2. Extract Zenodo Datasets
	zenodoMatches := zenodoRegex.FindAllStringSubmatch(combinedText, -1)
	for _, m := range zenodoMatches {
		if len(m) >= 2 {
			recordID := cleanTrailingPunctuation(m[1])
			canonicalURL := "https://zenodo.org/records/" + recordID
			if !seenDatasets[canonicalURL] {
				seenDatasets[canonicalURL] = true
				datasets = append(datasets, DatasetReference{
					URL:         canonicalURL,
					Platform:    DatasetPlatformZenodo,
					Name:        "Zenodo Record " + recordID,
					Description: "Zenodo Open Research Artifact",
				})
			}
		}
	}

	// 3. Extract Kaggle Datasets
	kaggleMatches := kaggleRegex.FindAllStringSubmatch(combinedText, -1)
	for _, m := range kaggleMatches {
		if len(m) >= 3 {
			owner := m[1]
			datasetName := cleanTrailingPunctuation(m[2])
			canonicalURL := "https://kaggle.com/datasets/" + owner + "/" + datasetName
			if !seenDatasets[canonicalURL] {
				seenDatasets[canonicalURL] = true
				datasets = append(datasets, DatasetReference{
					URL:         canonicalURL,
					Platform:    DatasetPlatformKaggle,
					Name:        owner + "/" + datasetName,
					Description: "Kaggle Dataset",
				})
			}
		}
	}

	// 4. Extract GitHub Repositories
	ghMatches := githubRegex.FindAllStringSubmatch(combinedText, -1)
	for _, m := range ghMatches {
		if len(m) >= 3 {
			owner := strings.ToLower(m[1])
			repoName := cleanTrailingPunctuation(m[2])

			// Skip reserved or documentation paths
			if reservedGitHubPaths[owner] {
				continue
			}

			canonicalURL := "https://github.com/" + m[1] + "/" + repoName
			normalizedKey := strings.ToLower(canonicalURL)
			if !seenRepos[normalizedKey] {
				seenRepos[normalizedKey] = true
				repos = append(repos, CodeRepository{
					URL:        canonicalURL,
					Platform:   PlatformGitHub,
					Owner:      m[1],
					RepoName:   repoName,
					IsOfficial: true,
				})
			}
		}
	}

	// 5. Extract GitLab Repositories
	glMatches := gitlabRegex.FindAllStringSubmatch(combinedText, -1)
	for _, m := range glMatches {
		if len(m) >= 3 {
			owner := m[1]
			repoName := cleanTrailingPunctuation(m[2])
			canonicalURL := "https://gitlab.com/" + owner + "/" + repoName
			normalizedKey := strings.ToLower(canonicalURL)
			if !seenRepos[normalizedKey] {
				seenRepos[normalizedKey] = true
				repos = append(repos, CodeRepository{
					URL:        canonicalURL,
					Platform:   PlatformGitLab,
					Owner:      owner,
					RepoName:   repoName,
					IsOfficial: true,
				})
			}
		}
	}

	// 6. Extract Hugging Face Models/Spaces (excluding /datasets/)
	hfMatches := huggingfaceModelRegex.FindAllStringSubmatch(combinedText, -1)
	for _, m := range hfMatches {
		if len(m) >= 3 {
			owner := m[1]
			modelName := cleanTrailingPunctuation(m[2])
			if strings.EqualFold(owner, "datasets") || strings.EqualFold(owner, "docs") || strings.EqualFold(owner, "models") {
				continue
			}
			canonicalURL := "https://huggingface.co/" + owner + "/" + modelName
			normalizedKey := strings.ToLower(canonicalURL)
			if !seenRepos[normalizedKey] {
				seenRepos[normalizedKey] = true
				repos = append(repos, CodeRepository{
					URL:        canonicalURL,
					Platform:   PlatformHuggingFace,
					Owner:      owner,
					RepoName:   modelName,
					IsOfficial: true,
				})
			}
		}
	}

	return repos, datasets
}
