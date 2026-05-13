import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'statistics_models.dart';

/// v57: thin client for the v56 statistics endpoint under
/// `mobile_devices_api_bp`. The endpoint is owner-scoped server-side
/// (same `_device_allowed` guard as `/history` and `/alerts`), so the
/// mobile repository does no filtering — a 404 from the backend means
/// the device isn't on the user's account.
class StatisticsRepository {
  StatisticsRepository(this._api);

  final ApiClient _api;

  /// `GET /api/v1/devices/<id>/statistics?view=day|month&date=YYYY-MM-DD`
  ///
  /// [view] must be one of `day` / `month`. The backend rejects
  /// anything else with `invalid_view` (400). [anchor] is the
  /// `YYYY-MM-DD` date; the backend defaults to "today" in the
  /// device's local timezone when omitted.
  Future<StatisticsSnapshot> fetch({
    required int deviceId,
    required String view,
    String? anchor,
  }) async {
    final response = await _api.get(
      '/api/v1/devices/$deviceId/statistics',
      query: {
        'view': view,
        if (anchor != null && anchor.isNotEmpty) 'date': anchor,
      },
    );
    return StatisticsSnapshot.fromJson(response.data);
  }
}

final statisticsRepositoryProvider = Provider<StatisticsRepository>((ref) {
  return StatisticsRepository(ref.watch(apiClientProvider));
});

/// (deviceId, view, anchor) tuple — a stable key for the
/// FutureProvider.family below. Equality + hashCode delegate to the
/// underlying fields so a fresh tuple with the same values reuses the
/// cached result.
class StatisticsQuery {
  const StatisticsQuery({
    required this.deviceId,
    required this.view,
    required this.anchor,
  });

  final int deviceId;
  final String view;
  final String anchor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StatisticsQuery &&
          other.deviceId == deviceId &&
          other.view == view &&
          other.anchor == anchor);

  @override
  int get hashCode => Object.hash(deviceId, view, anchor);
}

/// Statistics snapshot for one (deviceId, view, anchor). Cached per
/// tuple so range-chip / anchor-navigator interactions don't re-fetch
/// pages the user already saw.
final statisticsProvider =
    FutureProvider.family<StatisticsSnapshot, StatisticsQuery>((ref, q) {
  return ref
      .watch(statisticsRepositoryProvider)
      .fetch(deviceId: q.deviceId, view: q.view, anchor: q.anchor);
});
