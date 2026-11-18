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
    this.userRole = 'owner',
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
      userRole: json['user_role'] as String? ?? 'owner',
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
  final String userRole;
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
      'user_role': userRole,
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
      userRole: CollectionRole.fromString(userRole),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class CollaboratorDto {
  const CollaboratorDto({
    required this.collectionId,
    required this.userId,
    required this.email,
    required this.role,
    required this.invitedBy,
    required this.createdAt,
  });

  factory CollaboratorDto.fromJson(Map<String, dynamic> json) {
    return CollaboratorDto(
      collectionId: json['collection_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'viewer',
      invitedBy: json['invited_by'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final String collectionId;
  final String userId;
  final String email;
  final String role;
  final String invitedBy;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'collection_id': collectionId,
      'user_id': userId,
      'email': email,
      'role': role,
      'invited_by': invitedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Collaborator toDomain() {
    return Collaborator(
      collectionId: collectionId,
      userId: userId,
      email: email,
      role: CollectionRole.fromString(role),
      invitedBy: invitedBy,
      createdAt: createdAt,
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
