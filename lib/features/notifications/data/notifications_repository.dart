import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'notification_models.dart';
import 'notification_settings_models.dart';

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

  /// v87: `GET /api/mobile/notifications/settings` — returns the full
  /// notification configuration. Our model only parses the safe-to-edit
  /// subset (channel on/off + per-section enabled flags).
  Future<NotificationSettingsSnapshot> fetchSettings() async {
    final response =
        await _api.get('/api/mobile/notifications/settings');
    return NotificationSettingsSnapshot.fromJson(response.data);
  }

  /// v87: `PATCH /api/mobile/notifications/settings` with a `settings:`
  /// map of allowed keys (per backend whitelist). Returns the refreshed
  /// snapshot from the server.
  Future<NotificationSettingsSnapshot> patchSettings(
    Map<String, bool> booleanSettings,
  ) async {
    final response = await _api.patch(
      '/api/mobile/notifications/settings',
      body: {'settings': booleanSettings},
    );
    return NotificationSettingsSnapshot.fromJson(response.data);
  }
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

/// v87: snapshot of the user's notification settings.
final notificationSettingsProvider =
    FutureProvider<NotificationSettingsSnapshot>((ref) {
  return ref.watch(notificationsRepositoryProvider).fetchSettings();
});
