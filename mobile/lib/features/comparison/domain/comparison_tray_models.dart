library;

/// Represents an item in the researcher's active multi-paper comparison tray.
class ComparisonTrayItem {
  const ComparisonTrayItem({
    required this.paperId,
    required this.title,
    this.authors = const [],
    this.year = 0,
    this.venue = '',
  });

  final String paperId;
  final String title;
  final List<String> authors;
  final int year;
  final String venue;

  Map<String, dynamic> toJson() => {
        'paper_id': paperId,
        'title': title,
        'authors': authors,
        'year': year,
        'venue': venue,
      };

  factory ComparisonTrayItem.fromJson(Map<String, dynamic> json) =>
      ComparisonTrayItem(
        paperId: json['paper_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        authors: (json['authors'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        year: (json['year'] as num?)?.toInt() ?? 0,
        venue: json['venue'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComparisonTrayItem &&
          runtimeType == other.runtimeType &&
          paperId == other.paperId;

  @override
  int get hashCode => paperId.hashCode;
}

/// State of the researcher's active multi-paper comparison tray.
class ComparisonTrayState {
  const ComparisonTrayState({
    this.items = const [],
    this.isExpanded = false,
  });

  /// Up to 4 papers selected for comparative analysis.
  final List<ComparisonTrayItem> items;

  /// Whether the tray is expanded to show paper cards or minimized into a docked pill.
  final bool isExpanded;

  /// Comparison requires at least 2 papers.
  bool get canCompare => items.length >= 2;

  /// Comparison tray holds at most 4 papers simultaneously.
  bool get isFull => items.length >= 4;

  int get count => items.length;

  bool containsPaper(String paperId) =>
      items.any((item) => item.paperId == paperId);

  List<String> get paperIds => items.map((item) => item.paperId).toList();

  ComparisonTrayState copyWith({
    List<ComparisonTrayItem>? items,
    bool? isExpanded,
  }) =>
      ComparisonTrayState(
        items: items ?? this.items,
        isExpanded: isExpanded ?? this.isExpanded,
      );
}
