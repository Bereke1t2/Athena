import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/prefs/prefs_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_notifier.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Profile & Settings',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: ListView(
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
                        backgroundColor: AppTheme.canaryYellow,
                        child: Text(
                          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF141416),
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
                                backgroundColor: AppTheme.canaryYellow,
                                foregroundColor: const Color(0xFF141416),
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
            icon: Icons.category_rounded,
            title: 'Subscribed Topics',
            subtitle: 'Manage topic filters and focus areas',
            onTap: () => context.push('/topics'),
            isDark: isDark,
          ),
          _Tile(
            icon: Icons.brightness_6_rounded,
            title: 'Appearance',
            subtitle: isDark ? 'Dark theme (Canary)' : 'Light theme',
            trailing: Switch(
              value: isDark,
              activeTrackColor: AppTheme.canaryYellow,
              onChanged: (_) => ref.read(appThemeModeProvider.notifier).toggle(),
            ),
            isDark: isDark,
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
          ],
        ],
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
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? (isDark ? AppTheme.canaryYellow : const Color(0xFF141416))).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor ?? (isDark ? AppTheme.canaryYellow : const Color(0xFF141416)),
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
    );
  }
}
