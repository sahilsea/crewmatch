import 'package:flutter/widgets.dart';

import '../api/api_exception.dart';
import '../api/crewmatch_api.dart';
import '../models/auth_result.dart';
import '../models/user.dart';
import 'token_store.dart';

/// Who is signed in. Owns the API, restores the saved token on launch and
/// signs the user out when the API answers 401.
class Session extends ChangeNotifier {
  Session({required this.api, required this._tokens}) {
    api.client.onUnauthorized = () =>
        signOut(notice: 'Your session ended. Please sign in again.');
  }

  final CrewMatchApi api;
  final TokenStore _tokens;

  User? _user;
  User? get user => _user;

  bool _restoring = true;

  /// True until [restore] has checked the saved token.
  bool get restoring => _restoring;

  /// A message for the sign-in screen, e.g. why the user was signed out.
  String? notice;

  /// The email code to show on screen when the server can't send email.
  String? devCode;

  /// Signs back in with the saved token, if there is one and it still works.
  Future<void> restore() async {
    final token = await _tokens.read();
    if (token != null) {
      api.client.token = token;
      try {
        _user = await api.me();
      } on ApiException catch (e) {
        api.client.token = null;
        // A rejected token is useless; keep it if the server was just unreachable.
        if (!e.isOffline) await _tokens.clear();
        notice = e.isOffline ? e.message : null;
      }
    }
    _restoring = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) =>
      _start(api.login(email.trim(), password));

  Future<void> register(String name, String email, String password) =>
      _start(api.register(name.trim(), email.trim(), password));

  Future<void> _start(Future<AuthResult> request) async {
    final result = await request;
    api.client.token = result.token;
    await _tokens.write(result.token);
    _user = result.user;
    devCode = result.devCode;
    notice = null;
    notifyListeners();
  }

  /// Replaces the signed-in user, e.g. after a profile save.
  void updateUser(User user) {
    _user = user;
    notifyListeners();
  }

  /// Reloads the signed-in user (crew and match count change elsewhere too).
  Future<void> refreshUser() async {
    if (_user == null) return;
    updateUser(await api.me());
  }

  Future<void> signOut({String? notice}) async {
    if (_user == null && api.client.token == null) return;
    api.client.token = null;
    _user = null;
    devCode = null;
    this.notice = notice;
    notifyListeners();
    await _tokens.clear();
  }
}

/// Makes the [Session] available to the widget tree.
class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({super.key, required Session session, required super.child})
      : super(notifier: session);

  /// The session, rebuilding [context] whenever it changes.
  static Session watch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;

  /// The session, without subscribing to changes. Use in callbacks.
  static Session read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}

extension SessionContext on BuildContext {
  Session get session => SessionScope.read(this);
  CrewMatchApi get api => SessionScope.read(this).api;
}
