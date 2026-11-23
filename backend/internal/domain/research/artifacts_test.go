package research_test

import (
	"testing"

	"athena/backend/internal/domain/research"
)

func TestExtractArtifacts_GitHubAndPunctuation(t *testing.T) {
	abstract := `In this work, we propose Vision Transformers for high-resolution image synthesis.
Our source code and pretrained weights are available at https://github.com/google-research/vision-transformer.
Please also check our previous codebase (see https://github.com/openai/whisper.git).`

	repos, datasets := research.ExtractArtifacts(abstract, nil)
	if len(repos) != 2 {
		t.Fatalf("expected 2 repositories, got %d", len(repos))
	}

	if repos[0].Platform != research.PlatformGitHub || repos[0].Owner != "google-research" || repos[0].RepoName != "vision-transformer" {
		t.Errorf("unexpected repo 0: %+v", repos[0])
	}
	if repos[0].URL != "https://github.com/google-research/vision-transformer" {
		t.Errorf("unexpected url 0: %s", repos[0].URL)
	}

	if repos[1].Owner != "openai" || repos[1].RepoName != "whisper" {
		t.Errorf("unexpected repo 1: %+v", repos[1])
	}
	if len(datasets) != 0 {
		t.Errorf("expected 0 datasets, got %d", len(datasets))
	}
}

func TestExtractArtifacts_HuggingFaceAndZenodo(t *testing.T) {
	text := `We evaluate our model on benchmarks available on Hugging Face at https://huggingface.co/datasets/glue/glue
and open weights are hosted at https://huggingface.co/meta-llama/Llama-3-8B.
Raw data records are archived on Zenodo at https://zenodo.org/records/1234567.`

	repos, datasets := research.ExtractArtifacts(text, nil)
	if len(repos) != 1 {
		t.Fatalf("expected 1 repo, got %d", len(repos))
	}
	if repos[0].Platform != research.PlatformHuggingFace || repos[0].Owner != "meta-llama" || repos[0].RepoName != "Llama-3-8B" {
		t.Errorf("unexpected model repo: %+v", repos[0])
	}

	if len(datasets) != 2 {
		t.Fatalf("expected 2 datasets, got %d", len(datasets))
	}
	if datasets[0].Platform != research.DatasetPlatformHuggingFace || datasets[0].Name != "glue/glue" {
		t.Errorf("unexpected hf dataset: %+v", datasets[0])
	}
	if datasets[1].Platform != research.DatasetPlatformZenodo || datasets[1].URL != "https://zenodo.org/records/1234567" {
		t.Errorf("unexpected zenodo dataset: %+v", datasets[1])
	}
}

func TestExtractArtifacts_GitLabAndKaggle(t *testing.T) {
	text := `Check implementation at https://gitlab.com/research-org/cool-project;
and data at https://kaggle.com/datasets/datasci/titanic-cleaned.`

	repos, datasets := research.ExtractArtifacts(text, nil)
	if len(repos) != 1 || repos[0].Platform != research.PlatformGitLab {
		t.Fatalf("expected 1 gitlab repo, got: %+v", repos)
	}
	if len(datasets) != 1 || datasets[0].Platform != research.DatasetPlatformKaggle {
		t.Fatalf("expected 1 kaggle dataset, got: %+v", datasets)
	}
}

func TestExtractArtifacts_ReservedPathsIgnored(t *testing.T) {
	text := `Visit https://github.com/features and https://github.com/pricing for details.`
	repos, datasets := research.ExtractArtifacts(text, nil)
	if len(repos) != 0 || len(datasets) != 0 {
		t.Errorf("expected 0 artifacts for reserved github paths, got %d repos and %d datasets", len(repos), len(datasets))
	}
}

func TestExtractArtifacts_DeduplicationWithVersions(t *testing.T) {
	abstract := `Code: https://github.com/org/repo`
	versions := []string{"https://github.com/org/repo/", "https://github.com/org/repo.git"}

	repos, _ := research.ExtractArtifacts(abstract, versions)
	if len(repos) != 1 {
		t.Fatalf("expected 1 unique repository after deduplication, got %d", len(repos))
	}
}
