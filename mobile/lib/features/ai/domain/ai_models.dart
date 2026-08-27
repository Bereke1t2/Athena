/// AI layer domain models (Phase 4): explanation levels, structured summaries,
/// grounded chat messages with citations.
enum ExplanationLevel { beginner, intermediate, advanced, expert }

extension ExplanationLevelWire on ExplanationLevel {
  String get wireValue => name;

  String get label => switch (this) {
        ExplanationLevel.beginner => 'Beginner',
        ExplanationLevel.intermediate => 'Intermediate',
        ExplanationLevel.advanced => 'Advanced',
        ExplanationLevel.expert => 'Expert',
      };
}

ExplanationLevel? explanationLevelFromWire(String? raw) {
  for (final l in ExplanationLevel.values) {
    if (l.wireValue == raw) return l;
  }
  return null;
}

/// What the artifact was actually generated from — the honest-degradation
/// contract ("abstract+full_text" vs "abstract").
class Grounding {
  const Grounding({required this.basedOn, this.chunkCount = 0});

  final String basedOn;
  final int chunkCount;
}

class SummarySections {
  const SummarySections({
    this.simpleExplanation = '',
    this.academicExplanation = '',
    this.keyFindings = const [],
    this.methodology = '',
    this.results = '',
    this.limitations = const [],
    this.whyItMatters = '',
  });

  final String simpleExplanation;
  final String academicExplanation;
  final List<String> keyFindings;
  final String methodology;
  final String results;
  final List<String> limitations;
  final String whyItMatters;
}

class PaperSummaryAI {
  const PaperSummaryAI({
    required this.paperId,
    required this.level,
    required this.tldr,
    required this.sections,
    required this.grounding,
    required this.cacheHit,
    required this.modelId,
  });

  final String paperId;
  final ExplanationLevel level;
  final String tldr;
  final SummarySections sections;
  final Grounding grounding;
  final bool cacheHit;
  final String modelId;
}

class ChatCitation {
  const ChatCitation({
    required this.chunkId,
    this.sectionPath = '',
    this.quote = '',
  });

  final String chunkId;
  final String sectionPath;
  final String quote;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.citations = const [],
    this.createdAt,
  });

  final String id;
  final String role; // "user" | "assistant"
  final String content;
  final List<ChatCitation> citations;
  final DateTime? createdAt;

  bool get isUser => role == 'user';
}

/// One SSE event from the ask stream.
sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class ChatDelta extends ChatStreamEvent {
  const ChatDelta(this.text);
  final String text;
}

class ChatDone extends ChatStreamEvent {
  const ChatDone(this.message);
  final ChatMessage message;
}

class ChatFailed extends ChatStreamEvent {
  const ChatFailed(this.message);
  final String message;
}
