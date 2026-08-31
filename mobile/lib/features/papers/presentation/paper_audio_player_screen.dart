import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/athena_branding.dart';
import '../domain/audio_playback.dart';
import '../domain/paper.dart';
import 'audio_player_notifier.dart';

/// Screen 4: Now Playing / Audio Experience Screen
class PaperAudioPlayerScreen extends ConsumerStatefulWidget {
  const PaperAudioPlayerScreen({
    super.key,
    this.paper,
    this.title = 'Research Audio Digest',
    this.source = 'AI Research Brief',
  });

  final PaperSummary? paper;
  final String title;
  final String source;

  @override
  ConsumerState<PaperAudioPlayerScreen> createState() => _PaperAudioPlayerScreenState();
}

class _PaperAudioPlayerScreenState extends ConsumerState<PaperAudioPlayerScreen> {
  static String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showSpeedModal(BuildContext context, double currentSpeed) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Playback Speed',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [0.8, 1.0, 1.2, 1.5, 1.75, 2.0].map((speed) {
                    final isSelected = (currentSpeed - speed).abs() < 0.05;
                    return ChoiceChip(
                      label: Text('${speed}x'),
                      selected: isSelected,
                      onSelected: (_) {
                        ref.read(audioPlayerProvider.notifier).setSpeed(speed);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSleepTimerModal(BuildContext context, int? currentMinutes) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sleep Timer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('Off'),
                      selected: currentMinutes == null,
                      onSelected: (_) {
                        ref.read(audioPlayerProvider.notifier).setSleepTimer(null);
                        Navigator.pop(ctx);
                      },
                    ),
                    for (final mins in [15, 30, 45, 60])
                      ChoiceChip(
                        label: Text('$mins min'),
                        selected: currentMinutes == mins,
                        onSelected: (_) {
                          ref.read(audioPlayerProvider.notifier).setSleepTimer(mins);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sleep timer set for $mins minutes'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final audioState = ref.watch(audioPlayerProvider);
    final track = audioState.currentTrack ??
        AudioTrack(
          id: 'placeholder',
          title: widget.paper?.title ?? widget.title,
          authorVenue: widget.paper?.venueName ?? widget.source,
          totalDuration: const Duration(minutes: 18, seconds: 30),
        );

    final position = audioState.currentPosition;
    final total = track.totalDuration;
    final remaining = total > position ? total - position : Duration.zero;
    final progress = audioState.progress;
    final currentChapter = audioState.currentChapterIndex;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: Center(
          child: Text(
            'NOW PLAYING · CHAPTER $currentChapter OF ${track.chapters.isNotEmpty ? track.chapters.length : 3}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: 'Queue',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${audioState.queue.length} items in upcoming queue'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Artwork Card with Overlays
              AnimatedEntrance(
                delay: const Duration(milliseconds: 50),
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE89A84),
                        Color(0xFFD66D75),
                        Color(0xFF2C3E50),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Abstract Visual Pattern Overlay
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Center(
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                audioState.isPlaying ? Icons.graphic_eq_rounded : Icons.headphones_rounded,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Top Chapter & AI-Enhanced Badges
                      Positioned(
                        left: 16,
                        top: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'CHAPTER $currentChapter / ${track.chapters.isNotEmpty ? track.chapters.length : 3}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 16,
                        top: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.canaryYellow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'AI RESEARCH BRIEF',
                            style: TextStyle(
                              color: Color(0xFF141416),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Title and Subtitle
              AnimatedEntrance(
                delay: const Duration(milliseconds: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.authorVenue,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Interactive Waveform Scrubber Visualizer
              AnimatedEntrance(
                delay: const Duration(milliseconds: 150),
                child: Column(
                  children: [
                    GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final width = box.size.width - 40;
                        final localX = details.localPosition.dx.clamp(0.0, width);
                        ref.read(audioPlayerProvider.notifier).seekToProgress(localX / width);
                      },
                      onTapDown: (details) {
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final width = box.size.width - 40;
                        final localX = details.localPosition.dx.clamp(0.0, width);
                        ref.read(audioPlayerProvider.notifier).seekToProgress(localX / width);
                      },
                      child: _WaveformBar(progress: progress),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                        Text(
                          '-${_formatDuration(remaining)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Media Controls (10s back, big circle Play, 10s forward)
              AnimatedEntrance(
                delay: const Duration(milliseconds: 200),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.replay_10_rounded),
                      onPressed: () => ref.read(audioPlayerProvider.notifier).skipSeconds(-10),
                    ),
                    const SizedBox(width: 24),
                    InkWell(
                      onTap: () => ref.read(audioPlayerProvider.notifier).togglePlayPause(),
                      borderRadius: BorderRadius.circular(36),
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFFFEEA66) : const Color(0xFF141416),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          audioState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 36,
                          color: isDark ? const Color(0xFF141416) : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.forward_10_rounded),
                      onPressed: () => ref.read(audioPlayerProvider.notifier).skipSeconds(10),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Utility Controls Row (Speed, Sleep, Transcript, Cast)
              AnimatedEntrance(
                delay: const Duration(milliseconds: 250),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Speed yellow pill
                    GestureDetector(
                      onTap: () => _showSpeedModal(context, audioState.speed),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.canaryYellow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${audioState.speed}x',
                          style: const TextStyle(
                            color: Color(0xFF141416),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _UtilityPill(
                      label: audioState.sleepTimerMinutes != null
                          ? 'Sleep · ${audioState.sleepTimerMinutes}m'
                          : 'Sleep',
                      icon: Icons.bedtime_outlined,
                      isActive: audioState.sleepTimerMinutes != null,
                      onTap: () => _showSleepTimerModal(context, audioState.sleepTimerMinutes),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _UtilityPill(
                      label: 'Transcript',
                      icon: Icons.notes_rounded,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening full interactive transcript…'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _UtilityPill(
                      label: 'AirPlay',
                      icon: Icons.cast_rounded,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Scanning for AirPlay & Cast devices…'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // SMART MARKER Pull Quote Card (data-driven from track.pullQuote)
              if (track.pullQuote != null)
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 300),
                  child: InkWell(
                    onTap: () {
                      ref.read(audioPlayerProvider.notifier).seekTo(track.pullQuote!.timestamp);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Jumped to ${track.pullQuote!.context}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E181D) : const Color(0xFFFFF1F0),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFF7675).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF7675),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'SMART MARKER · ${_formatDuration(track.pullQuote!.timestamp)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.bookmark_add_outlined, size: 18, color: Color(0xFFFF7675)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Saved pull quote to your research highlights!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '"${track.pullQuote!.quote}"',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap to jump · ${track.pullQuote!.context}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFFFA07A) : const Color(0xFFD63031),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Chapter List (data-driven from track.chapters)
              AnimatedEntrance(
                delay: const Duration(milliseconds: 350),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHAPTERS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final ch in track.chapters)
                      _ChapterTile(
                        num: ch.index.toString().padLeft(2, '0'),
                        title: ch.title,
                        timestamp: _formatDuration(ch.startOffset),
                        isActive: ch.index == currentChapter,
                        onTap: () => ref.read(audioPlayerProvider.notifier).seekToChapter(ch.index),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveformBar extends StatelessWidget {
  const _WaveformBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heights = [12, 18, 26, 14, 30, 22, 16, 28, 34, 20, 14, 24, 32, 18, 10, 22, 30, 16, 26, 34, 18, 12, 28, 20, 14, 26, 32, 18, 12, 24, 16, 10];

    return SizedBox(
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < heights.length; i++) ...[
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                height: heights[i].toDouble(),
                decoration: BoxDecoration(
                  color: (i / heights.length) <= progress
                      ? (isDark ? const Color(0xFFFEEA66) : const Color(0xFF141416))
                      : (isDark ? const Color(0xFF2E3340) : const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UtilityPill extends StatelessWidget {
  const _UtilityPill({
    required this.label,
    this.icon,
    this.isActive = false,
    this.onTap,
    required this.isDark,
  });

  final String label;
  final IconData? icon;
  final bool isActive;
  final VoidCallback? onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.canaryYellow
              : (isDark ? const Color(0xFF1F232D) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? AppTheme.canaryYellow
                : (isDark ? const Color(0xFF2C3240) : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isActive
                    ? const Color(0xFF141416)
                    : (isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151)),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? const Color(0xFF141416)
                    : (isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.num,
    required this.title,
    required this.timestamp,
    required this.isActive,
    required this.onTap,
  });

  final String num;
  final String title;
  final String timestamp;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF20242E) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? (isDark ? AppTheme.canaryYellow : const Color(0xFF141416))
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text(
              num,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isActive ? AppTheme.canaryYellow : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF141416),
                ),
              ),
            ),
            Text(
              timestamp,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
