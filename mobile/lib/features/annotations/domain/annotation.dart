/// Available highlight and note resonant colors.
enum AnnotationColor {
  yellow('yellow', 'Yellow', 0xFFEAB308, 0x33EAB308),
  coral('coral', 'Coral', 0xFFFF5C00, 0x33FF5C00),
  emerald('emerald', 'Emerald', 0xFF10B981, 0x3310B981),
  cyan('cyan', 'Cyan', 0xFF06B6D4, 0x3306B6D4),
  purple('purple', 'Purple', 0xFFA855F7, 0x33A855F7);

  const AnnotationColor(this.code, this.label, this.colorHex, this.tintHex);

  final String code;
  final String label;
  final int colorHex;
  final int tintHex;

  static AnnotationColor fromCode(String? code) {
    if (code == null) return AnnotationColor.yellow;
    final match = AnnotationColor.values.where(
      (c) => c.code.toLowerCase() == code.toLowerCase().trim(),
    );
    return match.isNotEmpty ? match.first : AnnotationColor.yellow;
  }
}

/// Domain model for persistent paper text highlights and margin notes.
class Annotation {
  const Annotation({
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

  final String id;
  final String userId;
  final String paperId;
  final int pageNumber;
  final int sectionIndex;
  final String selectedText;
  final String note;
  final AnnotationColor color;
  final DateTime createdAt;
  final DateTime updatedAt;

  Annotation copyWith({
    String? id,
    String? userId,
    String? paperId,
    int? pageNumber,
    int? sectionIndex,
    String? selectedText,
    String? note,
    AnnotationColor? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Annotation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      paperId: paperId ?? this.paperId,
      pageNumber: pageNumber ?? this.pageNumber,
      sectionIndex: sectionIndex ?? this.sectionIndex,
      selectedText: selectedText ?? this.selectedText,
      note: note ?? this.note,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'paper_id': paperId,
      'page_number': pageNumber,
      'section_index': sectionIndex,
      'selected_text': selectedText,
      'note': note,
      'color': color.code,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Annotation.fromJson(Map<String, dynamic> json) {
    return Annotation(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      paperId: json['paper_id'] as String? ?? '',
      pageNumber: (json['page_number'] as num?)?.toInt() ?? 1,
      sectionIndex: (json['section_index'] as num?)?.toInt() ?? 0,
      selectedText: json['selected_text'] as String? ?? '',
      note: json['note'] as String? ?? '',
      color: AnnotationColor.fromCode(json['color'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class CreateAnnotationParams {
  const CreateAnnotationParams({
    required this.paperId,
    this.pageNumber = 1,
    this.sectionIndex = 0,
    required this.selectedText,
    this.note = '',
    this.color = AnnotationColor.yellow,
  });

  final String paperId;
  final int pageNumber;
  final int sectionIndex;
  final String selectedText;
  final String note;
  final AnnotationColor color;
}

class UpdateAnnotationParams {
  const UpdateAnnotationParams({
    required this.id,
    required this.paperId,
    this.note,
    this.color,
  });

  final String id;
  final String paperId;
  final String? note;
  final AnnotationColor? color;
}
