import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The web client ID from Google Cloud (Google Auth Platform → Clients). It is
/// public, like every app's. Android asks Google for ID tokens addressed to it,
/// so the server checks one ID for both platforms. The Android clients are
/// matched by package name and signing key, so they need no ID here.
const googleWebClientId = '856800606024-ncuqqanrfl35dhhmr3dn6c331s2atct8.apps.googleusercontent.com';

/// "Continue with Google": gets a Google ID token for the API to check.
abstract final class GoogleAuth {
  static Future<void>? _ready;

  static Future<void> ready() => _ready ??= GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? googleWebClientId : null,
        serverClientId: kIsWeb ? null : googleWebClientId,
      );

  /// Browsers only allow Google's own button; phones can use ours.
  static bool get usesGoogleButton => kIsWeb;

  /// Phones: opens Google's account picker. Null if the user backs out.
  static Future<String?> pickAccount() async {
    await ready();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) return null;
      rethrow;
    }
  }

  /// Web: ID tokens from Google's button, as people sign in with it.
  static Stream<String> get buttonTokens => GoogleSignIn.instance.authenticationEvents
      .map((event) => event is GoogleSignInAuthenticationEventSignIn ? event.user.authentication.idToken : null)
      .where((token) => token != null)
      .cast<String>();

  /// Forgets the Google account, so the next sign-in asks which one.
  static Future<void> signOut() async {
    if (_ready == null) return;
    try {
      await _ready;
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Signing out of CrewMatch must work even if Google's side fails.
    }
  }
}
