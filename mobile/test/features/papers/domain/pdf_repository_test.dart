import 'package:athena/features/papers/domain/paper.dart';
import 'package:athena/features/papers/domain/pdf_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PaperDetail makePaper({
    String arxivId = '',
    String bestOaUrl = '',
    String doi = '',
    List<VersionLine> versions = const [],
  }) {
    return PaperDetail(
      summary: PaperSummary(
        id: 'test-id',
        title: 'Test Paper',
        abstract: 'Test Abstract',
        publishedOn: DateTime(2026, 1, 1),
        year: 2026,
        venueName: 'Test Venue',
        publicationType: 'journal_article',
        oaStatus: 'gold',
        isOpenAccess: true,
        citedByCount: 5,
      ),
      language: 'en',
      license: 'cc-by',
      bestOaUrl: bestOaUrl,
      doi: doi,
      arxivId: arxivId,
      authors: const [],
      topics: const [],
      versions: versions,
      referenceCount: 10,
      sources: const ['openalex'],
    );
  }

  group('resolvePdfUrl', () {
    test('prefers arXiv direct PDF link when arxivId is present', () {
      final paper = makePaper(
        arxivId: '2301.00001',
        bestOaUrl: 'https://example.org/other.pdf',
      );
      expect(resolvePdfUrl(paper), 'https://arxiv.org/pdf/2301.00001');
    });

    test('resolves direct bestOaUrl when it ends with .pdf', () {
      final paper = makePaper(bestOaUrl: 'https://example.org/paper.pdf');
      expect(resolvePdfUrl(paper), 'https://example.org/paper.pdf');
    });

    test('resolves direct bestOaUrl when it contains /pdf/', () {
      final paper = makePaper(bestOaUrl: 'https://example.org/pdf/12345');
      expect(resolvePdfUrl(paper), 'https://example.org/pdf/12345');
    });

    test('resolves from versions when bestOaUrl is an HTML page', () {
      final paper = makePaper(
        bestOaUrl: 'https://example.org/landing/123',
        versions: const [
          VersionLine(kind: 'repository', url: 'https://repo.org/article.pdf', isPreprint: false),
        ],
      );
      expect(resolvePdfUrl(paper), 'https://repo.org/article.pdf');
    });

    test('returns null when no direct PDF link exists', () {
      final paper = makePaper(
        bestOaUrl: 'https://example.org/landing/123',
        doi: '10.1234/5678',
        versions: const [
          VersionLine(kind: 'publisher', url: 'https://publisher.com/article/123', isPreprint: false),
        ],
      );
      expect(resolvePdfUrl(paper), isNull);
    });
  });

  group('resolveWebUrl', () {
    test('resolves DOI to https://doi.org URL', () {
      final paper = makePaper(doi: '10.1234/sample.doi');
      expect(resolveWebUrl(paper), 'https://doi.org/10.1234/sample.doi');
    });

    test('resolves full URL DOI without double prefix', () {
      final paper = makePaper(doi: 'https://doi.org/10.1234/sample.doi');
      expect(resolveWebUrl(paper), 'https://doi.org/10.1234/sample.doi');
    });

    test('falls back to bestOaUrl when DOI is empty', () {
      final paper = makePaper(bestOaUrl: 'https://openaccess.org/paper/123');
      expect(resolveWebUrl(paper), 'https://openaccess.org/paper/123');
    });

    test('falls back to versions when DOI and bestOaUrl are empty', () {
      final paper = makePaper(
        versions: const [
          VersionLine(kind: 'preprint', url: 'https://biorxiv.org/content/123', isPreprint: true),
        ],
      );
      expect(resolveWebUrl(paper), 'https://biorxiv.org/content/123');
    });

    test('falls back to arXiv abstract URL when only arxivId is present', () {
      final paper = makePaper(arxivId: '2301.00001');
      expect(resolveWebUrl(paper), 'https://arxiv.org/abs/2301.00001');
    });

    test('returns null when no identifiers or URLs are available', () {
      final paper = makePaper();
      expect(resolveWebUrl(paper), isNull);
    });
  });
}
