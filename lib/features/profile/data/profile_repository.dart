import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'profile_models.dart';

class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<Profile> fetch() async {
    final response = await _api.get('/api/mobile/profile');
    return Profile.fromJson(response.data);
  }

  /// `PATCH /api/mobile/profile`. The patch body must already be the
  /// minimal set of changed-and-safe fields. Backend re-emits the full
  /// `user` payload on success, which we re-parse so the UI reflects the
  /// server's authoritative values (handles defaults like email
  /// lowercasing, phone cleaning, etc.).
  Future<Profile> update(ProfilePatch patch) async {
    final response = await _api.patch(
      '/api/mobile/profile',
      body: patch.toJson(),
    );
    return Profile.fromJson(response.data);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});
