import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// A newer Android build on GitHub Releases.
class AppUpdate {
  const AppUpdate({required this.version, required this.current, required this.url, this.notes = ''});

  /// The new version, e.g. `1.1.0`.
  final String version;

  /// The version installed now.
  final String current;

  /// Direct download link to the APK.
  final String url;

  /// The release notes, as written on GitHub.
  final String notes;
}

/// Checks GitHub Releases for a newer Android app.
///
/// Every release is tagged `vX.Y.Z` with the APK attached. The app compares
/// that tag with its own version (from pubspec.yaml) and offers the download
/// when GitHub's is newer. The website always serves the latest build, so it
/// never checks.
class UpdateChecker {
  static const repo = 'sahilsea/crewmatch';

  /// Already asked during this run of the app.
  static var _checked = false;

  /// The update to offer, or null when up to date, offline, or not on Android.
  static Future<AppUpdate?> check({http.Client? client, String? currentVersion}) async {
    if (currentVersion == null && (kIsWeb || defaultTargetPlatform != TargetPlatform.android)) return null;
    try {
      final current = currentVersion ?? (await PackageInfo.fromPlatform()).version;
      final res = await (client ?? http.Client())
          .get(
            Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final latest = (json['tag_name'] as String? ?? '').replaceFirst(RegExp('^v'), '');
      if (!isNewer(latest, current)) return null;
      final assets = (json['assets'] as List? ?? const []).cast<Map<String, dynamic>>();
      final apk = assets.where((a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk')).firstOrNull;
      if (apk == null) return null;
      return AppUpdate(
        version: latest,
        current: current,
        url: apk['browser_download_url'] as String,
        notes: (json['body'] as String? ?? '').trim(),
      );
    } catch (_) {
      // No network or GitHub is down: try again next launch.
      return null;
    }
  }

  /// Once per app launch.
  static Future<AppUpdate?> checkOnce() async {
    if (_checked) return null;
    _checked = true;
    return check();
  }

  /// True when [candidate] (e.g. `1.10.0`) is a higher version than [current] (e.g. `1.9.2`).
  static bool isNewer(String candidate, String current) {
    List<int> parts(String v) => [
          for (final p in v.split('+').first.split('.')) int.tryParse(p) ?? 0,
        ];
    final a = parts(candidate), b = parts(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
