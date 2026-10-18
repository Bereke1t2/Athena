library;

class TopicFollow {
  const TopicFollow({
    required this.topicId,
    required this.topicSlug,
    required this.topicName,
    required this.notify,
    required this.createdAt,
  });

  final String topicId;
  final String topicSlug;
  final String topicName;
  final bool notify;
  final DateTime createdAt;
}

class AuthorFollow {
  const AuthorFollow({
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });

  final String authorId;
  final String authorName;
  final DateTime createdAt;
}
