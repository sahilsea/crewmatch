import 'package:flutter/foundation.dart';

/// A profile link the web app was opened with: `/u/tara-fernandes`
/// (or `?u=tara-fernandes`).
abstract final class IncomingLink {
  /// The handle from the address bar, until the app has opened it.
  static String? _handle = _read();

  /// Signed out: show the public card first. Off once they choose to sign in.
  static final showPublic = ValueNotifier<bool>(_handle != null);

  static String? get handle => _handle;

  static String? _read() {
    if (!kIsWeb) return null;
    final segments = Uri.base.pathSegments;
    if (segments.length >= 2 && segments[0] == 'u' && segments[1].isNotEmpty) return segments[1].toLowerCase();
    return Uri.base.queryParameters['u']?.toLowerCase();
  }

  /// Hands the handle over once, after sign-in.
  static String? take() {
    final h = _handle;
    _handle = null;
    showPublic.value = false;
    return h;
  }
}
