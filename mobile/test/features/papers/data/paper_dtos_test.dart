import 'package:athena/features/papers/data/paper.dtos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const summaryJson = <String, dynamic>{
    'id': '0197c0de-0000-7000-8000-000000000001',
    'title': 'Scaling Laws',
    'abstract': 'We study scaling.',
    'publication_date': '2026-05-11T00:00:00Z',
    'publication_year': 2026,
    'venue': {'name': 'NeurIPS', 'type': 'conference'},
    'publication_type': 'conference_paper',
    'oa_status': 'gold',
    'is_open_access': true,
    'cited_by_count': 12,
  };

  test('summary DTO parses snake_case wire format and maps to domain', () {
    final dto = PaperSummaryDto.fromJson(summaryJson);
    final paper = dto.toDomain();

    expect(paper.title, 'Scaling Laws');
    expect(paper.publishedOn, DateTime.utc(2026, 5, 11));
    expect(paper.venueName, 'NeurIPS');
    expect(paper.isOpenAccess, isTrue);
    expect(paper.citedByCount, 12);
  });

  test('blank abstracts become null in domain', () {
    final dto = PaperSummaryDto.fromJson({
      ...summaryJson,
      'abstract': '   ',
    });
    expect(dto.toDomain().abstract, isNull);
  });

  test('detail DTO parses authors/topics/versions and maps to domain', () {
    final dto = PaperDetailDto.fromJson({
      ...summaryJson,
      'language': 'en',
      'license': 'cc-by',
      'best_oa_url': 'https://example.org/pdf',
      'doi': '10.1234/x',
      'arxiv_id': '',
      'authors': [
        {
          'id': '0197c0de-0000-7000-8000-000000000002',
          'name': 'J. Doe',
          'affiliation': ['MIT'],
        }
      ],
      'topics': [
        {'slug': 'ml', 'name': 'Machine Learning', 'is_primary': true},
      ],
      'versions': [
        {'kind': 'preprint', 'url': 'https://arxiv.org/abs/x'},
      ],
      'reference_count': 64,
      'sources': ['openalex'],
    });

    final d = dto.toDomain();
    expect(d.authors.single.name, 'J. Doe');
    expect(d.authors.single.affiliations, ['MIT']);
    expect(d.topics.single.isPrimary, isTrue);
    expect(d.versions.single.kind, 'preprint');
    expect(d.referenceCount, 64);
    expect(d.arxivId, isEmpty);
    expect(d.summary.title, 'Scaling Laws');
  });

  test('venue type omitted gracefully when missing', () {
    final dto = VenueDto.fromJson({'name': 'Some Journal'});
    expect(dto.name, 'Some Journal');
    expect(dto.type, isNull);
  });

  test('summary DTO parses authority_score and is_seminal when present', () {
    final dto = PaperSummaryDto.fromJson({
      ...summaryJson,
      'authority_score': 87.5,
      'is_seminal': true,
    });
    final paper = dto.toDomain();
    expect(paper.authorityScore, 87.5);
    expect(paper.isSeminal, isTrue);
  });

  test('summary DTO defaults authority_score to 0.0 and is_seminal to false', () {
    final dto = PaperSummaryDto.fromJson(summaryJson);
    final paper = dto.toDomain();
    expect(paper.authorityScore, 0.0);
    expect(paper.isSeminal, isFalse);
    expect(paper.hasCode, isFalse);
    expect(paper.primaryCodeUrl, isNull);
  });

  test('summary DTO parses has_code and primary_code_url when present', () {
    final dto = PaperSummaryDto.fromJson({
      ...summaryJson,
      'has_code': true,
      'primary_code_url': 'https://github.com/google-deepmind/vision-transformer',
    });
    final paper = dto.toDomain();
    expect(paper.hasCode, isTrue);
    expect(paper.primaryCodeUrl, 'https://github.com/google-deepmind/vision-transformer');
  });

  test('detail DTO parses code_repositories and datasets', () {
    final dto = PaperDetailDto.fromJson({
      ...summaryJson,
      'has_code': true,
      'primary_code_url': 'https://github.com/google-deepmind/vision-transformer',
      'reference_count': 42,
      'code_repositories': [
        {
          'url': 'https://github.com/google-deepmind/vision-transformer',
          'platform': 'github',
          'owner': 'google-deepmind',
          'repo_name': 'vision-transformer',
          'is_official': true,
          'stars_count': 1250,
        }
      ],
      'datasets': [
        {
          'url': 'https://huggingface.co/datasets/glue',
          'platform': 'huggingface',
          'name': 'glue',
          'description': 'GLUE Benchmark',
        }
      ],
    });

    final detail = dto.toDomain();
    expect(detail.summary.hasCode, isTrue);
    expect(detail.summary.primaryCodeUrl, 'https://github.com/google-deepmind/vision-transformer');
    expect(detail.codeRepositories.length, 1);
    expect(detail.codeRepositories.first.displayName, 'google-deepmind/vision-transformer');
    expect(detail.codeRepositories.first.isOfficial, isTrue);
    expect(detail.codeRepositories.first.starsCount, 1250);
    expect(detail.datasets.length, 1);
    expect(detail.datasets.first.name, 'glue');
    expect(detail.datasets.first.platform, 'huggingface');
  });
}
