import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../papers/presentation/audio_player_notifier.dart';
import '../digest_notifier.dart';

/// Weekly research podcast & continuous audio briefing card.
class DigestPodcastCard extends ConsumerStatefulWidget {
  const DigestPodcastCard({super.key});

  @override
  ConsumerState<DigestPodcastCard> createState() => _DigestPodcastCardState();
}

class _DigestPodcastCardState extends ConsumerState<DigestPodcastCard> {
  bool _isChaptersExpanded = false;
  String _selectedVoice = 'Alloy';

  static const List<String> _voices = ['Alloy', 'Nova', 'Echo', 'Onyx', 'Shimmer'];

  static String _formatTimestamp(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _handlePlayAction(DigestState digestState) async {
    final audioPlayerNotifier = ref.read(audioPlayerProvider.notifier);
    final audioState = ref.read(audioPlayerProvider);

    final track = digestState.audioTrack;
    final isThisTrack = audioState.currentTrack != null &&
        track != null &&
        audioState.currentTrack!.id == track.id;

    if (isThisTrack) {
      audioPlayerNotifier.togglePlayPause();
      return;
    }

    if (track != null) {
      await audioPlayerNotifier.playTrack(track);
      return;
    }

    // Synthesize on-demand
    final synthesized = await ref
        .read(digestNotifierProvider.notifier)
        .synthesizeAudio(voice: _selectedVoice);
    if (synthesized != null && mounted) {
      await audioPlayerNotifier.playTrack(synthesized);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.athenaColors;
    final isDark = theme.brightness == Brightness.dark;
    final digestState = ref.watch(digestNotifierProvider);
    final audioState = ref.watch(audioPlayerProvider);

    final track = digestState.audioTrack;
    final isThisTrack = audioState.currentTrack != null &&
        track != null &&
        audioState.currentTrack!.id == track.id;
    final isPlaying = isThisTrack && audioState.isPlaying;

    final chapters = track?.chapters ?? const [];
    final currentChapterIdx = isThisTrack ? audioState.currentChapterIndex : 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [colors.surfaceRaised, colors.surfaceBase]
              : [colors.surfaceBase, colors.surfaceLowest],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.coral.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.coral.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.coral.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.headphones_rounded, color: AppTheme.coral, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ATHENA PODCAST · WEEKLY BRIEFING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: AppTheme.coral,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF262C3A) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 11,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      track != null
                          ? '${track.totalDuration.inMinutes} MIN EPISODE'
                          : '8 MIN EPISODE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Title & Description
          Text(
            'The Week in Science: Multidisciplinary Insights',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Listen to a continuous speech-ready audio synthesis covering breakthroughs across your topics, structured with chapter timestamps.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
            ),
          ),

          const SizedBox(height: 16),

          // Action Controls Row
          Row(
            children: [
              // Main Play / Pause Button
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: digestState.isSynthesizingAudio
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 20,
                        ),
                  label: Text(
                    digestState.isSynthesizingAudio
                        ? 'Synthesizing Audio...'
                        : (isPlaying
                            ? 'Pause Briefing'
                            : (track != null ? 'Listen to Briefing' : 'Synthesize & Listen')),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  onPressed: digestState.isSynthesizingAudio
                      ? null
                      : () => _handlePlayAction(digestState),
                ),
              ),
              const SizedBox(width: 8),

              // Voice Selector Dropdown
              PopupMenuButton<String>(
                tooltip: 'Select Voice',
                initialValue: _selectedVoice,
                onSelected: (v) {
                  setState(() {
                    _selectedVoice = v;
                  });
                },
                itemBuilder: (ctx) => [
                  for (final v in _voices)
                    PopupMenuItem(
                      value: v,
                      child: Row(
                        children: [
                          Icon(
                            Icons.record_voice_over_rounded,
                            size: 16,
                            color: _selectedVoice == v ? AppTheme.coral : null,
                          ),
                          const SizedBox(width: 8),
                          Text(v, style: TextStyle(fontWeight: _selectedVoice == v ? FontWeight.w800 : FontWeight.normal)),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222736) : const Color(0xFFF1F3F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF333B4F) : const Color(0xFFD1D5DB),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.record_voice_over_rounded, size: 15),
                      const SizedBox(width: 5),
                      Text(
                        _selectedVoice,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Full Player Launcher
              IconButton(
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                tooltip: 'Open Full Audio Studio',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF222736) : const Color(0xFFF1F3F7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  context.push('/player');
                },
              ),
            ],
          ),

          // Chapter Markers Section (if chapters available)
          if (chapters.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 18),
            InkWell(
              onTap: () {
                setState(() {
                  _isChaptersExpanded = !_isChaptersExpanded;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.list_rounded, size: 16, color: AppTheme.coral),
                        const SizedBox(width: 6),
                        Text(
                          '${chapters.length} CHAPTERS · TIMELINE',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppTheme.coral,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _isChaptersExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ],
                ),
              ),
            ),

            if (_isChaptersExpanded) ...[
              const SizedBox(height: 8),
              for (final ch in chapters)
                InkWell(
                  onTap: () {
                    if (isThisTrack) {
                      ref.read(audioPlayerProvider.notifier).seekTo(ch.startOffset);
                    } else if (track != null) {
                      ref.read(audioPlayerProvider.notifier).playTrack(track).then((_) {
                        ref.read(audioPlayerProvider.notifier).seekTo(ch.startOffset);
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isThisTrack && currentChapterIdx == ch.index)
                          ? AppTheme.coral.withValues(alpha: 0.12)
                          : (isDark ? const Color(0xFF191D28) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isThisTrack && currentChapterIdx == ch.index)
                            ? AppTheme.coral.withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _formatTimestamp(ch.startOffset),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: (isThisTrack && currentChapterIdx == ch.index)
                                ? AppTheme.coral
                                : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ch.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: (isThisTrack && currentChapterIdx == ch.index)
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF141416),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          (isThisTrack && currentChapterIdx == ch.index && isPlaying)
                              ? Icons.graphic_eq_rounded
                              : Icons.play_circle_outline_rounded,
                          size: 16,
                          color: (isThisTrack && currentChapterIdx == ch.index)
                              ? AppTheme.coral
                              : (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
