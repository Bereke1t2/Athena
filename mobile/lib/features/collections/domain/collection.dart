import '../../papers/domain/paper.dart';

/// A user-curated research folder or reading list.
class Collection {
  const Collection({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.color,
    required this.isPublic,
    required this.paperCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String description;
  final String color;
  final bool isPublic;
  final int paperCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Collection copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? color,
    bool? isPublic,
    int? paperCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Collection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      isPublic: isPublic ?? this.isPublic,
      paperCount: paperCount ?? this.paperCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// A paper within a collection along with personal notes and order.
class CollectionPaper {
  const CollectionPaper({
    required this.collectionId,
    required this.paperId,
    required this.paper,
    required this.note,
    required this.position,
    required this.addedAt,
  });

  final String collectionId;
  final String paperId;
  final PaperSummary paper;
  final String note;
  final int position;
  final DateTime addedAt;
}

/// Representation of whether a paper belongs to a specific collection.
class PaperMembership {
  const PaperMembership({
    required this.collectionId,
    required this.collectionName,
    required this.color,
    required this.containsPaper,
    this.note = '',
  });

  final String collectionId;
  final String collectionName;
  final String color;
  final bool containsPaper;
  final String note;

  PaperMembership copyWith({
    String? collectionId,
    String? collectionName,
    String? color,
    bool? containsPaper,
    String? note,
  }) {
    return PaperMembership(
      collectionId: collectionId ?? this.collectionId,
      collectionName: collectionName ?? this.collectionName,
      color: color ?? this.color,
      containsPaper: containsPaper ?? this.containsPaper,
      note: note ?? this.note,
    );
  }
}
