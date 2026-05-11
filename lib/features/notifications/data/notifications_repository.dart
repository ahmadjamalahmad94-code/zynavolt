import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'notification_models.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  /// `GET /api/mobile/notifications?page=&page_size=` — newest first.
  Future<NotificationsPage> fetchPage({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _api.get(
      '/api/mobile/notifications',
      query: {
        'page': page,
        'page_size': pageSize,
      },
    );
    return NotificationsPage.fromEnvelope(
      data: response.data,
      meta: response.meta,
    );
  }

  /// `POST /api/mobile/notifications/<id>/read` — backend returns the
  /// updated notification + the new unread count. The UI never assumes
  /// success without parsing this envelope.
  Future<MarkReadResult> markRead(int notificationId) async {
    final response = await _api.post(
      '/api/mobile/notifications/$notificationId/read',
    );
    return MarkReadResult.fromJson(response.data);
  }

  /// `POST /api/mobile/notifications/read-all` — bulk mark-as-read.
  Future<ReadAllResult> markAllRead() async {
    final response = await _api.post('/api/mobile/notifications/read-all');
    return ReadAllResult.fromJson(response.data);
  }
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});
