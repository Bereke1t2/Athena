import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../audio_player_notifier.dart';

/// Persistent global mini-player bar docked directly above the navigation bar
/// across the primary app shell tabs, allowing researchers to listen to paper briefings
/// while browsing the feed, exploring topics, reading digests, or viewing saved papers.
class MiniAudioPlayer extends ConsumerWidget {
  const MiniAudioPlayer({super.key});

  static const List<List<Color>> _gradientThemes = [
    [Color(0xFFE89A84), Color(0xFFD66D75), Color(0xFF2C3E50)],
    [Color(0xFF6B8DD6), Color(0xFF8E37D7), Color(0xFF1E2640)],
    [Color(0xFF43CEA2), Color(0xFF185A9D), Color(0xFF10283C)],
    [Color(0xFFFF7E5F), Color(0xFFFEB47B), Color(0xFF33202A)],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider);
    final track = audioState.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeIndex = track.gradientThemeIndex.clamp(0, _gradientThemes.length - 1);
    final gradientColors = _gradientThemes[themeIndex];

    final currentChapter = audioState.currentChapterIndex;
    final chapterText = track.chapters.isNotEmpty ? ' · Ch. $currentChapter' : '';
    final venueText = track.authorVenue.isNotEmpty ? track.authorVenue : 'Athena Audio Briefing';

    return Container(
      key: const Key('mini_audio_player'),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181F) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
            width: 1.0,
          ),
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF3F4F6),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thin linear playback progress indicator at top edge
          SizedBox(
            height: 2.5,
            width: double.infinity,
            child: LinearProgressIndicator(
              value: audioState.progress,
              backgroundColor: isDark ? const Color(0xFF222632) : const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.coral),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Expandable tap area covering cover art + title metadata
                Expanded(
                  child: InkWell(
                    key: const Key('mini_audio_player_tap_area'),
                    onTap: () => context.push('/player'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                      child: Row(
                        children: [
                          // Track Artwork / Theme Thumbnail
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: gradientColors,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: gradientColors.first.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                audioState.isPlaying
                                    ? Icons.graphic_eq_rounded
                                    : Icons.headphones_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Title & Chapter Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$venueText$chapterText',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
