library;

/// Domain models for the audio narration & synthesis experience.
/// Pure Dart (no Flutter/Dio dependencies) to uphold domain layer purity.

class AudioChapter {
  const AudioChapter({
    required this.index,
    required this.title,
    required this.startOffset,
    required this.duration,
  });

  final int index;
  final String title;
  final Duration startOffset;
  final Duration duration;

  Duration get endOffset => startOffset + duration;
}

class AudioQuote {
  const AudioQuote({
    required this.quote,
    required this.context,
    required this.timestamp,
  });

  final String quote;
  final String context;
  final Duration timestamp;
}

class AudioTrack {
  const AudioTrack({
    required this.id,
    this.paperId,
    required this.title,
    required this.authorVenue,
    required this.totalDuration,
    this.chapters = const [],
    this.takeaways = const [],
    this.pullQuote,
    this.tags = const [],
    this.gradientThemeIndex = 0,
  });

  final String id;
  final String? paperId;
  final String title;
  final String authorVenue;
  final Duration totalDuration;
  final List<AudioChapter> chapters;
  final List<String> takeaways;
  final AudioQuote? pullQuote;
  final List<String> tags;
  final int gradientThemeIndex;

  /// Helper factory to generate a rich AudioTrack from a PaperSummary.
  factory AudioTrack.fromPaper({
    required String id,
    required String title,
    required String venue,
    required int year,
    String? abstractText,
    List<String> topics = const [],
  }) {
    final wordCount = (abstractText ?? title).split(RegExp(r'\s+')).length;
    final estimatedSeconds = (wordCount * 4).clamp(180, 1110); // 3 to 18.5 mins
    final duration = Duration(seconds: estimatedSeconds);

    final ch1Dur = Duration(seconds: (estimatedSeconds * 0.25).round());
    final ch2Dur = Duration(seconds: (estimatedSeconds * 0.45).round());
    final ch3Dur = duration - (ch1Dur + ch2Dur);

    final cleanTitle = title.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    final firstSentence = abstractText != null && abstractText.contains('.')
        ? abstractText.split('.').first.trim()
        : 'Key insights and empirical methodologies across neural domains.';

    return AudioTrack(
      id: id,
      paperId: id,
      title: cleanTitle,
      authorVenue: '$venue · $year',
      totalDuration: duration,
      chapters: [
        AudioChapter(
          index: 1,
          title: 'Introduction & Core Thesis',
          startOffset: Duration.zero,
          duration: ch1Dur,
        ),
        AudioChapter(
          index: 2,
          title: 'Methodology & Key Results',
          startOffset: ch1Dur,
          duration: ch2Dur,
        ),
        AudioChapter(
          index: 3,
          title: 'Implications & Future Directions',
          startOffset: ch1Dur + ch2Dur,
          duration: ch3Dur,
        ),
      ],
      takeaways: [
        'Systems and model representations are engineered for retention and generalization across high-dimensional regimes.',
        'Batching neural inputs and context windows restores deep-focus cognitive reasoning capability.',
        'Structured audio syntheses cut technical re-reading and comprehension time roughly in half.',
      ],
      pullQuote: AudioQuote(
        quote: firstSentence.isNotEmpty
            ? '$firstSentence.'
            : 'Knowledge synthesis accelerates retention through multi-sensory immersion.',
        context: 'Core finding · Chapter 2',
        timestamp: Duration(seconds: (estimatedSeconds * 0.3).round()),
      ),
      tags: topics.isNotEmpty ? topics : [venue.isNotEmpty ? venue : 'AI & Tech', '$year'],
      gradientThemeIndex: id.hashCode.abs() % 4,
    );
  }
}

class AudioPlaybackState {
  const AudioPlaybackState({
    this.currentTrack,
    this.isPlaying = false,
    this.currentPosition = Duration.zero,
    this.speed = 1.2,
    this.sleepTimerMinutes,
    this.queue = const [],
    this.recentTracks = const [],
  });

  final AudioTrack? currentTrack;
  final bool isPlaying;
  final Duration currentPosition;
  final double speed;
  final int? sleepTimerMinutes;
  final List<AudioTrack> queue;
  final List<AudioTrack> recentTracks;

  double get progress {
    final total = currentTrack?.totalDuration.inMilliseconds ?? 0;
    if (total <= 0) return 0.0;
    final current = currentPosition.inMilliseconds;
    return (current / total).clamp(0.0, 1.0);
  }

  int get currentChapterIndex {
    final track = currentTrack;
    if (track == null || track.chapters.isEmpty) return 1;
    for (final ch in track.chapters) {
      if (currentPosition >= ch.startOffset && currentPosition <= ch.endOffset) {
        return ch.index;
      }
    }
    return track.chapters.last.index;
  }

  AudioPlaybackState copyWith({
    AudioTrack? currentTrack,
    bool clearCurrentTrack = false,
    bool? isPlaying,
    Duration? currentPosition,
    double? speed,
    int? sleepTimerMinutes,
    bool clearSleepTimer = false,
    List<AudioTrack>? queue,
    List<AudioTrack>? recentTracks,
  }) {
    return AudioPlaybackState(
      currentTrack: clearCurrentTrack ? null : (currentTrack ?? this.currentTrack),
      isPlaying: isPlaying ?? this.isPlaying,
      currentPosition: currentPosition ?? this.currentPosition,
      speed: speed ?? this.speed,
      sleepTimerMinutes: clearSleepTimer ? null : (sleepTimerMinutes ?? this.sleepTimerMinutes),
      queue: queue ?? this.queue,
      recentTracks: recentTracks ?? this.recentTracks,
    );
  }
}
