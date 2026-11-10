import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      ),
      child: const SizedBox(height: 56),
    );
  }
}
