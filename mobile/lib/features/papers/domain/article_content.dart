class ArticleSection {
  final int seq;
  final String sectionPath;
  final String heading;
  final String content;
  final int tokenCount;

  const ArticleSection({
    required this.seq,
    this.sectionPath = '',
    this.heading = '',
    required this.content,
    this.tokenCount = 0,
  });

  String get displayTitle {
    if (sectionPath.isNotEmpty) return sectionPath;
    if (heading.isNotEmpty) return heading;
    return 'Section ${seq + 1}';
  }

  factory ArticleSection.fromJson(Map<String, dynamic> json) {
    return ArticleSection(
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      sectionPath: (json['section_path'] as String?) ?? '',
      heading: (json['heading'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      tokenCount: (json['token_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ArticleContent {
  final String paperId;
  final String title;
  final String abstractText;
  final String sourceUrl;
  final String format; // "pdf" or "web_article"
  final List<ArticleSection> sections;
  final int totalChunks;

  const ArticleContent({
    required this.paperId,
    required this.title,
    this.abstractText = '',
    this.sourceUrl = '',
    this.format = 'web_article',
    required this.sections,
    this.totalChunks = 0,
  });

  factory ArticleContent.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? [];
    return ArticleContent(
      paperId: (json['paper_id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      abstractText: (json['abstract'] as String?) ?? '',
      sourceUrl: (json['source_url'] as String?) ?? '',
      format: (json['format'] as String?) ?? 'web_article',
      sections: rawSections
          .map((e) => ArticleSection.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalChunks: (json['total_chunks'] as num?)?.toInt() ?? rawSections.length,
    );
  }
}
