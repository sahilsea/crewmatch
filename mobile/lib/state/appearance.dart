import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light, dark, or whatever the phone uses. Remembered between launches.
class Appearance extends ValueNotifier<ThemeMode> {
  Appearance._() : super(ThemeMode.system);

  static final instance = Appearance._();
  static const _key = 'crewmatch_theme';

  /// Reads the saved choice. Missing storage (tests) keeps "system".
  Future<void> load() async {
    try {
      final saved = await SharedPreferencesAsync().getString(_key);
      value = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    } catch (_) {}
  }

  void choose(ThemeMode mode) {
    value = mode;
    SharedPreferencesAsync().setString(_key, mode.name).catchError((_) {});
  }
}
