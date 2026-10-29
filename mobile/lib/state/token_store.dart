import 'package:shared_preferences/shared_preferences.dart';

/// Where the sign-in token is kept between launches.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Keeps the token in shared_preferences (localStorage on the web).
class PrefsTokenStore implements TokenStore {
  PrefsTokenStore([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  static const _key = 'crewmatch_token';
  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read() => _prefs.getString(_key);

  @override
  Future<void> write(String token) => _prefs.setString(_key, token);

  @override
  Future<void> clear() => _prefs.remove(_key);
}

/// Keeps the token in memory only. Used by tests.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async {
    this.token = token;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}
