import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'reports_models.dart';

/// v60: thin client for the v59 reports-summary endpoint under
/// `mobile_devices_api_bp`. Owner-scoped server-side (same
/// `_device_allowed` guard as the v52 history / v56 statistics
/// endpoints), so the mobile repository does no filtering — a 404
/// from the server means the device isn't on the user's account.
class ReportsRepository {
  ReportsRepository(this._api);

  final ApiClient _api;

  /// `GET /api/v1/devices/<id>/reports/summary?view=day|month&date=YYYY-MM-DD`
  ///
  /// Backend accepts only `view=day` / `view=month`; passing anything
  /// else surfaces as a 400 `invalid_view` ApiException. The optional
  /// `anchor` defaults to "today" in the device's local timezone when
  /// omitted server-side.
  Future<ReportsSnapshot> fetch({
    required int deviceId,
    required String view,
    String? anchor,
  }) async {
    final response = await _api.get(
      '/api/v1/devices/$deviceId/reports/summary',
      query: {
        'view': view,
        if (anchor != null && anchor.isNotEmpty) 'date': anchor,
      },
    );
    return ReportsSnapshot.fromJson(response.data);
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(apiClientProvider));
});

/// `(deviceId, view, anchor)` tuple — stable cache key for the
/// FutureProvider.family below. Equality + hashCode delegate to the
/// underlying fields so a fresh tuple with the same values reuses
/// the cached result.
class ReportsQuery {
  const ReportsQuery({
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
      (other is ReportsQuery &&
          other.deviceId == deviceId &&
          other.view == view &&
          other.anchor == anchor);

  @override
  int get hashCode => Object.hash(deviceId, view, anchor);
}

/// Reports snapshot for one (deviceId, view, anchor). Cached per
/// tuple so range-chip / anchor-pick interactions don't re-fetch
/// pages the user already saw.
final reportsProvider =
    FutureProvider.family<ReportsSnapshot, ReportsQuery>((ref, q) {
  return ref
      .watch(reportsRepositoryProvider)
      .fetch(deviceId: q.deviceId, view: q.view, anchor: q.anchor);
});
