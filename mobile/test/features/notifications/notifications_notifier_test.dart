import 'package:athena/features/notifications/domain/notification_models.dart';
import 'package:athena/features/notifications/domain/notifications_repository.dart';
import 'package:athena/features/notifications/presentation/notifications_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNotificationsRepository implements NotificationsRepository {
  List<AppNotification> items = [
    AppNotification(
      id: 'n1',
      type: 'new_papers_topic',
      title: 'New paper in AI',
      body: 'Check out the latest preprint',
      createdAt: DateTime.utc(2026, 10, 20),
    ),
    AppNotification(
      id: 'n2',
      type: 'digest',
      title: 'Weekly Briefing',
      body: 'Your summary is ready',
      createdAt: DateTime.utc(2026, 10, 19),
    ),
  ];

  @override
  Future<int> getUnreadCount() async {
    return items.where((n) => !n.isRead).length;
  }

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false, String? cursor, int limit = 20}) async {
    if (unreadOnly) {
      return items.where((n) => !n.isRead).toList();
    }
    return items;
  }

  @override
  Future<void> markAllRead() async {
    items = items.map((n) => n.copyWith(readAt: DateTime.now())).toList();
  }

  @override
  Future<void> markRead(String id) async {
    items = items.map((n) => n.id == id ? n.copyWith(readAt: DateTime.now()) : n).toList();
  }
}

void main() {
  test('notifications notifier loads items and unread count', () async {
    final fake = FakeNotificationsRepository();
    final container = ProviderContainer(
      overrides: [
        notificationsNotifierProvider.overrideWith((ref) => NotificationsNotifier(fake, true)),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(notificationsNotifierProvider.notifier);
    await notifier.loadNotifications();
    final state = container.read(notificationsNotifierProvider);

    expect(state.isLoading, isFalse);
    expect(state.notifications.length, 2);
    expect(state.unreadCount, 2);
  });

  test('notifications notifier markAsRead decrements unread count', () async {
    final fake = FakeNotificationsRepository();
    final container = ProviderContainer(
      overrides: [
        notificationsNotifierProvider.overrideWith((ref) => NotificationsNotifier(fake, true)),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(notificationsNotifierProvider.notifier);
    await notifier.loadNotifications();
    await notifier.markAsRead('n1');

    final state = container.read(notificationsNotifierProvider);
    expect(state.unreadCount, 1);
    expect(state.notifications.firstWhere((n) => n.id == 'n1').isRead, isTrue);
  });

  test('notifications notifier markAllAsRead sets all read', () async {
    final fake = FakeNotificationsRepository();
    final container = ProviderContainer(
      overrides: [
        notificationsNotifierProvider.overrideWith((ref) => NotificationsNotifier(fake, true)),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(notificationsNotifierProvider.notifier);
    await notifier.loadNotifications();
    await notifier.markAllAsRead();

    final state = container.read(notificationsNotifierProvider);
    expect(state.unreadCount, 0);
    expect(state.notifications.every((n) => n.isRead), isTrue);
  });
}
