import '../domain/annotation.dart';

class AnnotationDto {
  const AnnotationDto({
    required this.id,
    required this.userId,
    required this.paperId,
    required this.pageNumber,
    required this.sectionIndex,
    required this.selectedText,
    required this.note,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnnotationDto.fromJson(Map<String, dynamic> json) {
    return AnnotationDto(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      paperId: json['paper_id'] as String? ?? '',
      pageNumber: (json['page_number'] as num?)?.toInt() ?? 1,
      sectionIndex: (json['section_index'] as num?)?.toInt() ?? 0,
      selectedText: json['selected_text'] as String? ?? '',
      note: json['note'] as String? ?? '',
      color: json['color'] as String? ?? 'yellow',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final String id;
  final String userId;
  final String paperId;
  final int pageNumber;
  final int sectionIndex;
  final String selectedText;
  final String note;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'paper_id': paperId,
      'page_number': pageNumber,
      'section_index': sectionIndex,
      'selected_text': selectedText,
      'note': note,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Annotation toDomain() {
    return Annotation(
      id: id,
      userId: userId,
      paperId: paperId,
      pageNumber: pageNumber,
      sectionIndex: sectionIndex,
      selectedText: selectedText,
      note: note,
      color: AnnotationColor.fromCode(color),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static AnnotationDto fromDomain(Annotation a) {
    return AnnotationDto(
      id: a.id,
      userId: a.userId,
      paperId: a.paperId,
      pageNumber: a.pageNumber,
      sectionIndex: a.sectionIndex,
      selectedText: a.selectedText,
      note: a.note,
      color: a.color.code,
      createdAt: a.createdAt,
      updatedAt: a.updatedAt,
    );
  }
}

class UserAnnotationDto {
  const UserAnnotationDto({
    required this.id,
    required this.userId,
    required this.paperId,
    required this.paperTitle,
    this.paperYear,
    this.paperVenue = '',
    this.paperDoi = '',
    required this.pageNumber,
    required this.sectionIndex,
    required this.selectedText,
    required this.note,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserAnnotationDto.fromJson(Map<String, dynamic> json) {
    return UserAnnotationDto(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      paperId: json['paper_id'] as String? ?? '',
      paperTitle: json['paper_title'] as String? ?? '',
      paperYear: (json['paper_year'] as num?)?.toInt(),
      paperVenue: json['paper_venue'] as String? ?? '',
      paperDoi: json['paper_doi'] as String? ?? '',
      pageNumber: (json['page_number'] as num?)?.toInt() ?? 1,
      sectionIndex: (json['section_index'] as num?)?.toInt() ?? 0,
      selectedText: json['selected_text'] as String? ?? '',
      note: json['note'] as String? ?? '',
      color: json['color'] as String? ?? 'yellow',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final String id;
  final String userId;
  final String paperId;
  final String paperTitle;
  final int? paperYear;
  final String paperVenue;
  final String paperDoi;
  final int pageNumber;
  final int sectionIndex;
  final String selectedText;
  final String note;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAnnotation toDomain() {
    return UserAnnotation(
      id: id,
      userId: userId,
      paperId: paperId,
      paperTitle: paperTitle,
      paperYear: paperYear,
      paperVenue: paperVenue,
      paperDoi: paperDoi,
      pageNumber: pageNumber,
      sectionIndex: sectionIndex,
      selectedText: selectedText,
      note: note,
      color: AnnotationColor.fromCode(color),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
