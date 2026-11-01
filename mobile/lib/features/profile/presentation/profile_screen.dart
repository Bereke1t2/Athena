import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/prefs/prefs_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/athena_top_bar.dart';
import '../../../core/widgets/dot_grid_background.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../follows/domain/follow_models.dart';
import '../../follows/presentation/follows_notifier.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authNotifierProvider);
    final followsState = ref.watch(followsNotifierProvider);
    final user = authState.user;
    final followedTopics = followsState.followedTopics;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.deepDark : AppTheme.lightBg,
      appBar: const AthenaTopBar(
        title: 'Profile & Settings',
      ),
      body: DotGridBackground(
        child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // User Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161922) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB),
              ),
            ),
            child: authState.isAuthenticated && user != null
                ? Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.coral,
                        child: Text(
                          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: isDark ? const Color(0xFF2A303F) : const Color(0xFFE5E7EB),
                            child: const Icon(Icons.person_outline_rounded, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Guest Researcher',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Sign in to sync across devices',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.coral,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () => context.push('/login'),
                              child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? Colors.white : const Color(0xFF141416),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF3F475A) : const Color(0xFFD1D5DB),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => context.push('/register'),
                              child: const Text('Register', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),

          // Section: Personalization & Library
          _SectionHeader(title: 'PREFERENCES & RESEARCH', isDark: isDark),
          const SizedBox(height: 8),

          _Tile(
            icon: Icons.bookmark_rounded,
            title: 'Saved Library',
            subtitle: 'Access bookmarked papers and reading queue',
            onTap: () => context.push('/saved'),
            isDark: isDark,
          ),
          _Tile(
            icon: Icons.auto_stories_rounded,
            title: 'Research Digest',
            subtitle: 'Personalized executive briefing and topic velocity',
            onTap: () => context.push('/digest'),
            isDark: isDark,
          ),
          _Tile(
            icon: Icons.brightness_6_rounded,
            title: 'Appearance',
            subtitle: isDark ? 'Dark theme (Resarc)' : 'Light theme',
            trailing: Switch(
              value: isDark,
              activeTrackColor: AppTheme.coral,
              onChanged: (_) => ref.read(appThemeModeProvider.notifier).toggle(),
            ),
            isDark: isDark,
          ),

          const SizedBox(height: 24),

          // Section: Followed Topics
          _SectionHeader(title: 'FOLLOWED TOPICS', isDark: isDark),
          const SizedBox(height: 8),
          _FollowedTopicsCard(
            topics: followedTopics,
            isDark: isDark,
            onUnfollow: (slug, name) =>
                ref.read(followsNotifierProvider.notifier).toggleTopicFollow(slug, name),
            onExploreTap: () => context.push('/topics'),
          ),

          const SizedBox(height: 24),

          // Section: Account Actions
          if (authState.isAuthenticated) ...[
            _SectionHeader(title: 'ACCOUNT', isDark: isDark),
            const SizedBox(height: 8),
            _Tile(
              icon: Icons.logout_rounded,
              title: 'Sign Out',
              subtitle: 'Log out of this device',
              iconColor: const Color(0xFFFF7675),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text('Are you sure you want to sign out of Athena?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sign Out', style: TextStyle(color: Color(0xFFFF7675))),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged out successfully')),
                    );
                  }
                }
              },
              isDark: isDark,
            ),
            const SizedBox(height: 6),
            _Tile(
              icon: Icons.delete_forever_rounded,
              title: 'Delete Account',
              subtitle: 'Permanently remove your account and data',
              iconColor: const Color(0xFFE53935),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Account?'),
                    content: const Text(
                      'This action is permanent and cannot be undone. All your bookmarks, reading history, and account settings will be erased.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete Permanently', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await ref.read(authNotifierProvider.notifier).deleteAccount();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Account deleted successfully')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete account: $e')),
                      );
                    }
                  }
                }
              },
              isDark: isDark,
            ),
          ],
        ],
      ),
    ),
  );
}
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.isDark});

  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? (isDark ? AppTheme.coral : const Color(0xFF111827))).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? (isDark ? AppTheme.coral : const Color(0xFF111827)),
            ),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded, size: 20) : null),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _FollowedTopicsCard extends StatelessWidget {
  const _FollowedTopicsCard({
    required this.topics,
    required this.isDark,
    required this.onUnfollow,
    required this.onExploreTap,
  });

  final List<TopicFollow> topics;
  final bool isDark;
  final void Function(String slug, String name) onUnfollow;
  final VoidCallback onExploreTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.coral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tag_rounded, size: 16, color: AppTheme.coral),
              ),
              const SizedBox(width: 10),
              const Text(
                'Subscribed Areas',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF232836) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${topics.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.coral,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
                onPressed: onExploreTap,
                icon: const Text('Browse All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                label: const Icon(Icons.arrow_forward_rounded, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (topics.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final topic in topics)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: () => context.push('/topics/${topic.topicSlug}'),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF222634) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isDark ? const Color(0xFF333A4D) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '#',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.coral,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              topic.topicName,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF141416),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              borderRadius: BorderRadius.circular(50),
                              onTap: () => onUnfollow(topic.topicSlug, topic.topicName),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF2E3547) : const Color(0xFFE5E7EB),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 12,
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B1F2A) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF2A3142) : const Color(0xFFF0F2F5),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 32,
                    color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No topics followed yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF141416),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Subscribe to topics to personalize your feed and research digest.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.coral,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onExploreTap,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Explore Topics', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
