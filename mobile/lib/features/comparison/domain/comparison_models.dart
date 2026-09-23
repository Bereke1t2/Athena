library;

class ComparisonMatrixItem {
  const ComparisonMatrixItem({
    required this.paperId,
    required this.title,
    required this.authors,
    required this.year,
    required this.venue,
    required this.keyTakeaway,
    required this.methodology,
    required this.strengths,
    required this.limitations,
  });

  final String paperId;
  final String title;
  final List<String> authors;
  final int year;
  final String venue;
  final String keyTakeaway;
  final String methodology;
  final List<String> strengths;
  final List<String> limitations;
}

class ComparisonReport {
  const ComparisonReport({
    required this.papers,
    required this.consensusPoints,
    required this.divergencePoints,
    required this.comparativeSummary,
    required this.grounding,
    required this.modelId,
  });

  final List<ComparisonMatrixItem> papers;
  final List<String> consensusPoints;
  final List<String> divergencePoints;
  final String comparativeSummary;
  final String grounding;
  final String modelId;
}
