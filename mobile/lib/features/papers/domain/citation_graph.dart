class CitationGraphNode {
  final String id;
  final String title;
  final int year;
  final String venueName;
  final int citedByCount;
  final int depth;
  final bool isSeed;

  const CitationGraphNode({
    required this.id,
    required this.title,
    this.year = 0,
    this.venueName = '',
    this.citedByCount = 0,
    this.depth = 0,
    this.isSeed = false,
  });

  factory CitationGraphNode.fromJson(Map<String, dynamic> json) {
    return CitationGraphNode(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      venueName: json['venue_name'] as String? ?? '',
      citedByCount: (json['cited_by_count'] as num?)?.toInt() ?? 0,
      depth: (json['depth'] as num?)?.toInt() ?? 0,
      isSeed: json['is_seed'] as bool? ?? false,
    );
  }
}

class CitationGraphEdge {
  final String source;
  final String target;
  final bool isInfluential;
  final String stance;
  final String context;

  const CitationGraphEdge({
    required this.source,
    required this.target,
    this.isInfluential = false,
    this.stance = 'mentions',
    this.context = '',
  });

  factory CitationGraphEdge.fromJson(Map<String, dynamic> json) {
    return CitationGraphEdge(
      source: json['source'] as String? ?? '',
      target: json['target'] as String? ?? '',
      isInfluential: json['is_influential'] as bool? ?? false,
      stance: json['stance'] as String? ?? 'mentions',
      context: json['context'] as String? ?? '',
    );
  }
}

class CitationGraph {
  final String rootId;
  final int depth;
  final List<CitationGraphNode> nodes;
  final List<CitationGraphEdge> edges;
  final int totalNodes;
  final int totalEdges;

  const CitationGraph({
    required this.rootId,
    this.depth = 1,
    this.nodes = const [],
    this.edges = const [],
    this.totalNodes = 0,
    this.totalEdges = 0,
  });

  factory CitationGraph.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'] as List<dynamic>? ?? [];
    final rawEdges = json['edges'] as List<dynamic>? ?? [];
    return CitationGraph(
      rootId: json['root_id'] as String? ?? '',
      depth: (json['depth'] as num?)?.toInt() ?? 1,
      nodes: rawNodes
          .map((n) => CitationGraphNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      edges: rawEdges
          .map((e) => CitationGraphEdge.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalNodes: (json['total_nodes'] as num?)?.toInt() ?? rawNodes.length,
      totalEdges: (json['total_edges'] as num?)?.toInt() ?? rawEdges.length,
    );
  }
}
