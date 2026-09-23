import 'notification_models.dart';

abstract class NotificationsRepository {
  Future<List<AppNotification>> list({bool unreadOnly = false, String? cursor, int limit = 20});
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<int> getUnreadCount();
}
