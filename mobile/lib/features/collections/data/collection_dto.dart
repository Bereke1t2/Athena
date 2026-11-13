import '../../papers/data/paper.dtos.dart';
import '../domain/collection.dart';

class CollectionDto {
  const CollectionDto({
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

  factory CollectionDto.fromJson(Map<String, dynamic> json) {
    return CollectionDto(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      color: json['color'] as String? ?? '#6366F1',
      isPublic: json['is_public'] as bool? ?? false,
      paperCount: (json['paper_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final String id;
  final String userId;
  final String name;
  final String description;
  final String color;
  final bool isPublic;
  final int paperCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'color': color,
      'is_public': isPublic,
      'paper_count': paperCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Collection toDomain() {
    return Collection(
      id: id,
      userId: userId,
      name: name,
      description: description,
      color: color,
      isPublic: isPublic,
      paperCount: paperCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class CollectionPaperDto {
  const CollectionPaperDto({
    required this.collectionId,
    required this.paperId,
    required this.paper,
    required this.note,
    required this.position,
    required this.addedAt,
  });

  factory CollectionPaperDto.fromJson(Map<String, dynamic> json) {
    final paperMap = (json['paper'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {};
    final paperSummaryDto = PaperSummaryDto.fromJson(paperMap);

    return CollectionPaperDto(
      collectionId: json['collection_id'] as String? ?? '',
      paperId: json['paper_id'] as String? ?? '',
      paper: paperSummaryDto,
      note: json['note'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      addedAt: DateTime.tryParse(json['added_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final String collectionId;
  final String paperId;
  final PaperSummaryDto paper;
  final String note;
  final int position;
  final DateTime addedAt;

  CollectionPaper toDomain() {
    return CollectionPaper(
      collectionId: collectionId,
      paperId: paperId,
      paper: paper.toDomain(),
      note: note,
      position: position,
      addedAt: addedAt,
    );
  }
}

class PaperMembershipDto {
  const PaperMembershipDto({
    required this.collectionId,
    required this.collectionName,
    required this.color,
    required this.containsPaper,
    required this.note,
  });

  factory PaperMembershipDto.fromJson(Map<String, dynamic> json) {
    return PaperMembershipDto(
      collectionId: json['collection_id'] as String? ?? '',
      collectionName: json['collection_name'] as String? ?? '',
      color: json['color'] as String? ?? '#6366F1',
      containsPaper: json['contains_paper'] as bool? ?? false,
      note: json['note'] as String? ?? '',
    );
  }

  final String collectionId;
  final String collectionName;
  final String color;
  final bool containsPaper;
  final String note;

  PaperMembership toDomain() {
    return PaperMembership(
      collectionId: collectionId,
      collectionName: collectionName,
      color: color,
      containsPaper: containsPaper,
      note: note,
    );
  }
}
