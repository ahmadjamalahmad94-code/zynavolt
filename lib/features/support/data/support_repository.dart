import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'support_models.dart';

class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  /// GET /api/v1/support/cases — list of the user's support cases (mail
  /// threads + tickets). v50 ships read-only, no filters.
  Future<SupportCasesPage> list() async {
    final response = await _api.get('/api/v1/support/cases');
    return SupportCasesPage.fromJson(response.data);
  }

  /// `GET /api/v1/support/cases/:kind/:id` — single case with messages.
  /// `kind` must be `'message'` or `'ticket'` — taken from the case
  /// summary's `type` field, never user-typed.
  Future<SupportCaseDetail> fetch(String kind, int id) async {
    final response = await _api.get('/api/v1/support/cases/$kind/$id');
    return SupportCaseDetail.fromJson(response.data);
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(apiClientProvider));
});

final supportCasesProvider = FutureProvider<SupportCasesPage>((ref) {
  return ref.watch(supportRepositoryProvider).list();
});

/// Per (kind, id) detail family. Keyed on a record so multiple opens of
/// the same case reuse the same in-flight fetch.
final supportCaseDetailProvider =
    FutureProvider.family<SupportCaseDetail, ({String kind, int id})>(
  (ref, key) =>
      ref.watch(supportRepositoryProvider).fetch(key.kind, key.id),
);
