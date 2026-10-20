import '../../papers/domain/paper.dart';

class TopicPulse {
  const TopicPulse({
    required this.topicSlug,
    required this.topicName,
    required this.paperCount,
    required this.velocity,
    required this.keyThemes,
  });

  final String topicSlug;
  final String topicName;
  final int paperCount;
  final double velocity;
  final List<String> keyThemes;
}

class DigestSection {
  const DigestSection({
    required this.title,
    required this.description,
    required this.papers,
  });

  final String title;
  final String description;
  final List<PaperSummary> papers;
}

class UserDigest {
  const UserDigest({
    required this.id,
    required this.generatedAt,
    required this.frequency,
    required this.pulses,
    required this.sections,
    required this.topTakeaways,
  });

  final String id;
  final DateTime generatedAt;
  final String frequency;
  final List<TopicPulse> pulses;
  final List<DigestSection> sections;
  final List<String> topTakeaways;
}
