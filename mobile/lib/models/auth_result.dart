import 'user.dart';

/// `POST /auth/login` and `POST /auth/register`: `{ token, user }`.
class AuthResult {
  const AuthResult({required this.token, required this.user, this.devCode});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        token: json['token'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        devCode: json['devCode'] as String?,
      );

  final String token;
  final User user;

  /// The email code, when the server has no email set up (development and
  /// demos). Shown on the verify screen.
  final String? devCode;
}
