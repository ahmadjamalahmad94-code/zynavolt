import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'device_diagnostics_models.dart';

/// v52: thin client for the two read-only diagnostics endpoints under
/// `mobile_devices_api_bp` (the `/api/v1/devices/*` prefix, distinct
/// from the primary `/api/mobile/devices` core blueprint already used
/// elsewhere in this feature).
///
/// Both endpoints are owner-scoped by the backend, so the mobile
/// repository doesn't need to filter — a 404 from the server means
/// the device isn't on this user's account.
class DeviceDiagnosticsRepository {
  DeviceDiagnosticsRepository(this._api);

  final ApiClient _api;

  /// `GET /api/v1/devices/<id>/history`
  ///
  /// Backend defaults: `page_size=100` (max 500), last 7 days when
  /// no `from`/`to` is supplied. v52 takes the default window — the
  /// UI then renders only the top N rows for a compact secondary
  /// card. No client-side date filtering yet (follow-up gap).
  Future<List<DeviceReadingRow>> history(int deviceId) async {
    final response = await _api.get('/api/v1/devices/$deviceId/history');
    final items = (response.data['items'] as List?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(DeviceReadingRow.fromJson)
        .toList(growable: false);
  }

  /// `GET /api/v1/devices/<id>/alerts`
  ///
  /// Backend derives the list from the latest reading at request
  /// time — there's no persisted alerts table behind this endpoint.
  /// Returns an empty list when no thresholds are tripped, which the
  /// UI renders as "no current alerts" or just hides the section.
  Future<List<DeviceAlert>> alerts(int deviceId) async {
    final response = await _api.get('/api/v1/devices/$deviceId/alerts');
    final items = (response.data['items'] as List?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(DeviceAlert.fromJson)
        .toList(growable: false);
  }
}

final deviceDiagnosticsRepositoryProvider =
    Provider<DeviceDiagnosticsRepository>((ref) {
  return DeviceDiagnosticsRepository(ref.watch(apiClientProvider));
});

/// v52: history rows for one device, fetched lazily when the
/// device-detail screen renders the history card. Invalidated by
/// pull-to-refresh on the parent detail screen — no separate refresh
/// button at the card level (kept minimal per the v52 brief).
final deviceHistoryProvider =
    FutureProvider.family<List<DeviceReadingRow>, int>((ref, deviceId) {
  return ref.watch(deviceDiagnosticsRepositoryProvider).history(deviceId);
});

/// v52: alerts for one device. Same lifecycle as the history provider.
final deviceAlertsProvider =
    FutureProvider.family<List<DeviceAlert>, int>((ref, deviceId) {
  return ref.watch(deviceDiagnosticsRepositoryProvider).alerts(deviceId);
});
