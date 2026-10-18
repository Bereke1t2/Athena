import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../domain/notification_models.dart';
import '../domain/notifications_repository.dart';


class NotificationsState {
  const NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final notificationsNotifierProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  final auth = ref.watch(authNotifierProvider);
  return NotificationsNotifier(repo, auth.isAuthenticated);
});

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._repo, this._isAuthenticated) : super(const NotificationsState()) {
    if (_isAuthenticated) {
      loadNotifications();
      fetchUnreadCount();
    }
  }

  final NotificationsRepository _repo;
  final bool _isAuthenticated;

  Future<void> loadNotifications() async {
    if (!_isAuthenticated) return;
    state = state.copyWith(isLoading: true);
    try {
      final list = await _repo.list();
      final count = await _repo.getUnreadCount();
      state = state.copyWith(
        notifications: list,
        unreadCount: count,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> fetchUnreadCount() async {
    if (!_isAuthenticated) return;
    try {
      final count = await _repo.getUnreadCount();
      state = state.copyWith(unreadCount: count);
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    // Optimistic update
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        if (n.id == id) {
          return n.copyWith(readAt: DateTime.now());
        }
        return n;
      }).toList(),
      unreadCount: (state.unreadCount - 1).clamp(0, 999),
    );
    try {
      await _repo.markRead(id);
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    state = state.copyWith(
      notifications: state.notifications.map((n) => n.copyWith(readAt: DateTime.now())).toList(),
      unreadCount: 0,
    );
    try {
      await _repo.markAllRead();
    } catch (_) {}
  }
}
