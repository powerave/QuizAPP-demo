import 'dart:convert';

import 'package:http/http.dart' as http;
import '../../domain/models/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';

class ProfileRepository {
  ProfileRepository();

  Profile _profile = const Profile();
  SharedPreferences? _preferences;

  Profile get profile => _profile;

  Future<Profile> load() async {
    _preferences = await SharedPreferences.getInstance();
    final profileId = _preferences!.getString('profile_id') ?? '';
    final authToken = _preferences!.getString('auth_token') ?? '';
    final username = _preferences!.getString('username') ?? '';
    final displayName = _preferences!.getString('display_name') ?? '';
    _profile = _profile.copyWith(
      profileId: profileId,
      authToken: authToken,
      username: username,
      displayName: displayName,
      isLoading: false,
    );
    if (profileId.isNotEmpty && authToken.isNotEmpty) {
      try {
        final response = await http.get(
          _profileUri,
          headers: {'Authorization': 'Bearer $authToken'},
        );
        if (response.statusCode == 200) {
          _profile = Profile.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>,
          ).copyWith(
            authToken: authToken,
            username: username,
          );
        } else if (response.statusCode == 401) {
          await _clearStoredSession();
          _profile = const Profile(isLoading: false);
        }
      } catch (_) {
        // Keep the cached identity when the demo server is temporarily offline.
      }
    }
    return _profile;
  }

  Future<Profile> authenticate({
    required String username,
    required String password,
    required String displayName,
    required bool createAccount,
  }) async {
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    final response = await http.post(
      _authUri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'password': password,
        'displayName': displayName.trim(),
        'profileId': preferences.getString('profile_id') ?? const Uuid().v4(),
        'createAccount': createAccount,
      }),
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(payload['error'] as String? ?? 'Authentification impossible.');
    }
    final profile = Profile.fromJson(payload).copyWith(username: username.trim());
    await preferences.setString('profile_id', profile.profileId);
    await preferences.setString('auth_token', profile.authToken);
    await preferences.setString('username', profile.username);
    await preferences.setString('display_name', profile.displayName);
    _profile = profile;
    return profile;
  }

  Uri get _authUri {
    return _serverUri('/auth');
  }

  Uri get _profileUri {
    return _serverUri('/profile');
  }

  Uri _serverUri(String path) {
    final uri = Uri.parse(AppConfig.quizServerUrl);
    final scheme = uri.scheme == 'wss' ? 'https' : 'http';
    return Uri(
      scheme: scheme,
      host: uri.host.isEmpty ? 'localhost' : uri.host,
      port: uri.hasPort ? uri.port : (scheme == 'https' ? 443 : 8080),
      path: path,
    );
  }

  Future<void> _clearStoredSession() async {
    await _preferences?.remove('profile_id');
    await _preferences?.remove('auth_token');
    await _preferences?.remove('username');
    await _preferences?.remove('display_name');
  }

  Future<Profile> configure(String displayName) async {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) return _profile;
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    final storedName = preferences.getString('display_name') ?? '';
    final isDifferentProfile = storedName.isNotEmpty && storedName != normalizedName;
    final profileId = isDifferentProfile
        ? const Uuid().v4()
        : preferences.getString('profile_id') ?? const Uuid().v4();
    await preferences.setString('profile_id', profileId);
    await preferences.setString('display_name', normalizedName);
    _profile = isDifferentProfile
        ? Profile(
            profileId: profileId,
            displayName: normalizedName,
            isLoading: false,
          )
        : _profile.copyWith(
            profileId: profileId,
            displayName: normalizedName,
            isLoading: false,
          );
    return _profile;
  }

  Future<Profile> updateDisplayName(String displayName) async {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) return _profile;
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    final profileId = _profile.displayName.isNotEmpty &&
        _profile.displayName != normalizedName
      ? const Uuid().v4()
      : _profile.profileId;
    await preferences.setString('profile_id', profileId);
    await preferences.setString('display_name', normalizedName);
    _profile = profileId == _profile.profileId
      ? _profile.copyWith(displayName: normalizedName)
      : Profile(
        profileId: profileId,
        displayName: normalizedName,
        isLoading: false,
        );
    return _profile;
  }

  Future<void> clearSession() async {
    _preferences ??= await SharedPreferences.getInstance();
    await _clearStoredSession();
    _profile = const Profile(isLoading: false);
  }

  // Demo deliberately uses memory. A production app should replace this
  // repository with a Redis-backed implementation for shared history.
  Profile addGame(GameHistory game) {
    _profile = _profile.copyWith(
      gamesPlayed: _profile.gamesPlayed + 1,
      wins: _profile.wins + (game.won ? 1 : 0),
      totalScore: _profile.totalScore + game.score,
      history: [game, ..._profile.history],
    );
    return _profile;
  }
}
