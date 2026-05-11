import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/app_session.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';

class ProfileController extends AsyncNotifier<Profile> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Future<Profile> build() => _repo.fetch();

  Future<void> refresh() async {
    state = const AsyncLoading<Profile>();
    state = await AsyncValue.guard(() => _repo.fetch());
  }

  /// PATCH /profile, then update both the profile screen state AND the
  /// AppSession's AuthUser so the welcome card / More tab reflect the new
  /// name + email + locale immediately. Returns the saved [Profile] on
  /// success; throws on backend validation / network failure so the screen
  /// can render the real error.
  Future<Profile> save(ProfilePatch patch) async {
    final saved = await _repo.update(patch);
    state = AsyncData(saved);
    // Best-effort sync of AppSession so other screens reflect the change.
    // ignore: discarded_futures
    ref.read(appSessionProvider.notifier).refreshMe();
    return saved;
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, Profile>(
  ProfileController.new,
);
