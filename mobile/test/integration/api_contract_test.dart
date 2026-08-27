import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Live-contract smoke against the local backend. Skipped unless
/// ATHENA_INTEGRATION_BASE_URL is set (CI has no server).
///
///   ATHENA_INTEGRATION_BASE_URL=http://localhost:8080/api/v1 flutter test
void main() {
  final base = Platform.environment['ATHENA_INTEGRATION_BASE_URL'];

  test('feed/search/topics/detail payloads match mobile DTO expectations',
      skip: base == null
          ? 'set ATHENA_INTEGRATION_BASE_URL to run against a live backend'
          : false,
      timeout: const Timeout(Duration(seconds: 30)), () async {
    final client = http.Client();

    // 1. Feed list envelope + paper summary fields.
    var res = await client.get(Uri.parse('$base/feed?section=latest&limit=2'));
    expect(res.statusCode, 200);
    var body = res.body;
    for (final key in ['items', 'meta', 'next_cursor', '"paper":', 'title',
        'publication_year', 'is_open_access', 'cited_by_count', 'venue']) {
      expect(body.contains(key), isTrue, reason: 'feed missing $key');
    }

    // 2. Search meta fields.
    res = await client.get(Uri.parse('$base/search?q=protein&limit=1'));
    body = res.body;
    for (final key in ['"score"', 'mode_used', 'total_estimate']) {
      expect(body.contains(key), isTrue, reason: 'search missing $key');
    }
    final id = RegExp(r'"id":"([0-9a-f-]{36})"').firstMatch(body)!.group(1)!;

    // 3. Paper detail fields consumed by PaperDetailScreen.
    res = await client.get(Uri.parse('$base/research/papers/$id'));
    expect(res.statusCode, 200);
    body = res.body;
    for (final key in ['authors', 'topics', 'reference_count', 'sources']) {
      expect(body.contains('"$key"'), isTrue, reason: 'detail missing $key');
    }

    // 4. Topics list + detail.
    res = await client.get(Uri.parse('$base/topics?limit=3'));
    body = res.body;
    for (final key in ['slug', 'kind', 'paper_count_estimate']) {
      expect(body.contains(key), isTrue, reason: 'topics missing $key');
    }
    final slug = RegExp(r'"slug":"([a-z0-9-]+)"').firstMatch(body)!.group(1)!;
    res = await client.get(Uri.parse('$base/topics/$slug'));
    expect(res.statusCode, 200);

    // 5. Error envelope shape.
    res = await client.get(Uri.parse('$base/research/papers/00000000-0000-0000-0000-000000000000'));
    expect(res.statusCode, 404);
    expect(res.body.contains('"error"'), isTrue);
    expect(res.body.contains('"code"'), isTrue);
    client.close();
  });
}
