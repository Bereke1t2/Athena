class Topic {
  const Topic({
    required this.slug,
    required this.name,
    required this.kind,
    required this.paperCountEstimate,
    this.description = '',
    this.parentSlug,
    this.parentName,
    this.children = const [],
  });

  final String slug;
  final String name;
  final String description;

  /// "field" or "topic".
  final String kind;
  final int paperCountEstimate;
  final String? parentSlug;
  final String? parentName;

  /// Child topic slugs (the backend returns slugs, not names).
  final List<String> children;

  bool get isField => kind == 'field';

  /// Convert a slug like "machine-learning" to a display name "Machine Learning".
  static String displayNameForSlug(String slug) {
    return slug.split('-').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }
}

class TopicPage {
  const TopicPage({required this.items, required this.nextCursor});

  final List<Topic> items;
  final String? nextCursor;
}
