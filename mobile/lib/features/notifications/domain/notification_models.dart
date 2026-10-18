library;

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.data = const {},
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String type; // new_papers_topic | new_papers_author | digest | system
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  AppNotification copyWith({
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}
