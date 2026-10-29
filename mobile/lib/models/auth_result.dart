import 'user.dart';

/// `POST /auth/login` and `POST /auth/register`: `{ token, user }`.
class AuthResult {
  const AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        token: json['token'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String token;
  final User user;
}
