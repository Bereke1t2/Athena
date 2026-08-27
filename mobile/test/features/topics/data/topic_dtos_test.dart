import 'package:athena/features/topics/data/topics_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('topic list DTO parses snake_case wire format', () {
    final dto = TopicListDto.fromJson({
      'items': [
        {
          'slug': 'philosophy-of-mind',
          'name': 'Philosophy of Mind',
          'kind': 'topic',
          'parent': {'slug': 'philosophy-and-religion', 'name': 'Philosophy and Religion'},
          'paper_count_estimate': 42311,
        },
        {
          'slug': 'medicine-and-health',
          'name': 'Medicine and Health',
          'kind': 'field',
          'paper_count_estimate': 7687,
          'children': ['epidemiology'],
        },
      ],
      'meta': {'next_cursor': 'abc', 'limit': 50},
    });

    expect(dto.items, hasLength(2));
    final topic = dto.items[0].toDomain();
    expect(topic.slug, 'philosophy-of-mind');
    expect(topic.paperCountEstimate, 42311);
    expect(topic.parentSlug, 'philosophy-and-religion');
    expect(topic.isField, isFalse);

    final field = dto.items[1].toDomain();
    expect(field.isField, isTrue);
    expect(field.children, ['epidemiology']);

    expect(dto.meta.nextCursor, 'abc');
  });

  test('omitted optional fields default cleanly', () {
    final dto = TopicDto.fromJson({
      'slug': 'quantum-optics',
      'name': 'Quantum Optics',
      'kind': 'topic',
      'paper_count_estimate': 0,
    }).toDomain();

    expect(dto.description, isEmpty);
    expect(dto.parentSlug, isNull);
    expect(dto.children, isEmpty);
  });
}
