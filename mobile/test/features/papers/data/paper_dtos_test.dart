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
}
