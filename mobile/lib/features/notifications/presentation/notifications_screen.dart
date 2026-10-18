import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'notifications_notifier.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(notificationsNotifierProvider);
    final notifier = ref.read(notificationsNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => notifier.markAllAsRead(),
              child: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.loadNotifications(),
        child: state.notifications.isEmpty
            ? (state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1F232D) : const Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.notifications_none_rounded,
                              size: 40,
                              color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'When new papers match your followed topics or authors, you will see alerts here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: state.notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final n = state.notifications[i];
                  final isUnread = !n.isRead;
                  final paperId = n.data['paper_id'] as String?;

                  IconData icon;
                  Color iconColor;
                  switch (n.type) {
                    case 'new_papers_topic':
                      icon = Icons.category_rounded;
                      iconColor = AppTheme.canaryYellow;
                      break;
                    case 'new_papers_author':
                      icon = Icons.person_outline_rounded;
                      iconColor = const Color(0xFF74B9FF);
                      break;
                    case 'digest':
                      icon = Icons.auto_stories_rounded;
                      iconColor = const Color(0xFF55EFC4);
                      break;
                    default:
                      icon = Icons.info_outline_rounded;
                      iconColor = isDark ? Colors.white70 : Colors.black87;
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (!n.isRead) {
                        notifier.markAsRead(n.id);
                      }
                      if (paperId != null && paperId.isNotEmpty) {
                        context.push('/papers/$paperId');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? (isUnread ? const Color(0xFF1B202C) : const Color(0xFF141720))
                            : (isUnread ? Colors.white : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isUnread
                              ? (isDark ? AppTheme.canaryYellow.withValues(alpha: 0.4) : const Color(0xFFCBD5E1))
                              : (isDark ? const Color(0xFF222736) : const Color(0xFFE5E7EB)),
                          width: isUnread ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, size: 18, color: iconColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        n.title,
                                        style: TextStyle(
                                          fontWeight: isUnread ? FontWeight.w900 : FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                    if (isUnread)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.canaryYellow,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                if (n.body != null && n.body!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    n.body!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
