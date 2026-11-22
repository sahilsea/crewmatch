/// The same sign-up rules the API enforces (server/utils/schemas.js), checked
/// in the app first so people see what's wrong before anything is sent.
abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _name = RegExp(r"^\p{L}[\p{L}\p{M} .'-]*$", unicode: true);

  static String? email(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Enter your email';
    return _email.hasMatch(v) ? null : 'Enter a valid email address';
  }

  static String? name(String value) {
    final v = value.trim();
    if (v.length < 2) return 'Enter your full name';
    if (v.length > 60) return 'Names can be up to 60 characters';
    return _name.hasMatch(v) ? null : 'Use letters only in your name';
  }

  /// Each rule for a new password and whether [value] meets it.
  static List<(String, bool)> passwordRules(String value) => [
        ('At least 8 characters', value.length >= 8),
        ('A letter', RegExp('[A-Za-z]').hasMatch(value)),
        ('A number', RegExp(r'\d').hasMatch(value)),
      ];

  static String? newPassword(String value) {
    if (value.isEmpty) return 'Choose a password';
    if (value.length < 8) return 'Use at least 8 characters';
    if (!RegExp('[A-Za-z]').hasMatch(value)) return 'Add at least one letter';
    if (!RegExp(r'\d').hasMatch(value)) return 'Add at least one number';
    return null;
  }

  static String? password(String value) => value.isEmpty ? 'Enter your password' : null;
}
