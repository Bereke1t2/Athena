import '../../papers/domain/paper.dart';

/// Role of a user relative to a research collection.
enum CollectionRole {
  owner,
  admin,
  editor,
  viewer;

  static CollectionRole fromString(String? val) {
    if (val == null) return CollectionRole.viewer;
    switch (val.toLowerCase()) {
      case 'owner':
        return CollectionRole.owner;
      case 'admin':
        return CollectionRole.admin;
      case 'editor':
        return CollectionRole.editor;
      case 'viewer':
      default:
        return CollectionRole.viewer;
    }
  }

  String get label {
    switch (this) {
      case CollectionRole.owner:
        return 'Owner';
      case CollectionRole.admin:
        return 'Admin';
      case CollectionRole.editor:
        return 'Editor';
      case CollectionRole.viewer:
        return 'Viewer';
    }
  }

  bool get isOwner => this == CollectionRole.owner;
  bool get canManageMembers => this == CollectionRole.owner || this == CollectionRole.admin;
  bool get canEditPapers => this == CollectionRole.owner || this == CollectionRole.admin || this == CollectionRole.editor;
  bool get canView => true;
}

/// A member collaborating on a research collection.
class Collaborator {
  const Collaborator({
    required this.collectionId,
    required this.userId,
    required this.email,
    required this.role,
    required this.invitedBy,
    required this.createdAt,
  });

  final String collectionId;
  final String userId;
  final String email;
  final CollectionRole role;
  final String invitedBy;
  final DateTime createdAt;

  Collaborator copyWith({
    String? collectionId,
    String? userId,
    String? email,
    CollectionRole? role,
    String? invitedBy,
    DateTime? createdAt,
  }) {
    return Collaborator(
      collectionId: collectionId ?? this.collectionId,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
      invitedBy: invitedBy ?? this.invitedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

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
    this.userRole = CollectionRole.owner,
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
  final CollectionRole userRole;
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
    CollectionRole? userRole,
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
      userRole: userRole ?? this.userRole,
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
