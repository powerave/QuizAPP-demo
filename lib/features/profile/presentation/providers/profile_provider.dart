import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/profile_repository.dart';
import '../../domain/models/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(),
);

final profileProvider = NotifierProvider<ProfileController, Profile>(
  ProfileController.new,
);

class ProfileController extends Notifier<Profile> {
  late ProfileRepository _repository;

  @override
  Profile build() {
    _repository = ref.watch(profileRepositoryProvider);
    _load();
    return _repository.profile;
  }

  Future<void> _load() async {
    state = await _repository.load();
  }

  Future<void> authenticate({
    required String username,
    required String password,
    required String displayName,
    required bool createAccount,
  }) async {
    state = await _repository.authenticate(
      username: username,
      password: password,
      displayName: displayName,
      createAccount: createAccount,
    );
  }

  Future<void> updateDisplayName(String displayName) async {
    state = await _repository.updateDisplayName(displayName);
  }

  void addGame(GameHistory game) {
    state = _repository.addGame(game);
  }

  void syncFromServer(Map<String, dynamic> json) {
    state = Profile.fromJson(json).copyWith(
      authToken: state.authToken,
      username: state.username,
    );
  }

  Future<void> logout() async {
    await _repository.clearSession();
    state = _repository.profile;
  }
}
