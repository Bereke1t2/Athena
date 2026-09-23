import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/notification_models.dart';
import '../domain/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false, String? cursor, int limit = 20}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/me/notifications',
        queryParameters: {
          if (unreadOnly) 'unread_only': 'true',
          if (cursor != null) 'cursor': cursor,
          'limit': limit,
        },
      );
      final items = res.data?['items'] as List<dynamic>? ?? [];
      return items.map((raw) {
        final d = raw as Map<String, dynamic>;
        return AppNotification(
          id: d['id'] as String,
          type: d['type'] as String? ?? 'system',
          title: d['title'] as String? ?? '',
          body: d['body'] as String?,
          data: d['data'] as Map<String, dynamic>? ?? {},
          readAt: d['read_at'] != null ? DateTime.tryParse(d['read_at'] as String) : null,
          createdAt: DateTime.tryParse(d['created_at'] as String? ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _dio.post<void>('/me/notifications/$id/read');
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      await _dio.post<void>('/me/notifications/read-all');
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me/notifications/unread-count');
      return res.data?['count'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
