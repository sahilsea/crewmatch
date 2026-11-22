import 'package:crewmatch/state/session.dart';
import 'package:crewmatch/state/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';
import '../support/fixtures.dart';

void main() {
  test('restores the user from a saved token', () async {
    final tokens = MemoryTokenStore('saved');
    final session = Session(
      api: fakeApi({'GET /auth/me': (_) => (200, {'user': userJson()})}),
      tokens: tokens,
    );

    await session.restore();

    expect(session.restoring, isFalse);
    expect(session.user!.name, 'Demo Mobile');
    expect(session.api.client.token, 'saved');
  });

  test('continue with Google sends the ID token and keeps the session', () async {
    final tokens = MemoryTokenStore();
    final sent = <String>[];
    final session = Session(
      api: fakeApi({
        'POST /auth/google': (req) {
          sent.add(req.body);
          return (201, {'token': 'g-token', 'user': {...userJson(), 'emailVerified': true}, 'created': true});
        },
      }),
      tokens: tokens,
    );

    await session.signInWithGoogle('google-id-token');

    expect(sent.single, '{"idToken":"google-id-token"}');
    expect(session.user!.emailVerified, isTrue);
    expect(await tokens.read(), 'g-token');
  });

  test('forgets a token the API rejects', () async {
    final tokens = MemoryTokenStore('stale');
    final session = Session(
      api: fakeApi({'GET /auth/me': (_) => (401, {'error': 'Account no longer exists'})}),
      tokens: tokens,
    );

    await session.restore();

    expect(session.user, isNull);
    expect(tokens.token, isNull);
  });

  test('signs in, saves the token, and signs out on a later 401', () async {
    final tokens = MemoryTokenStore();
    final session = Session(
      api: fakeApi({
        'POST /auth/login': (_) => (200, {'token': 'fresh', 'user': userJson()}),
        'GET /matches': (_) => (401, {'error': 'Session expired or invalid, please sign in again'}),
      }),
      tokens: tokens,
    );

    await session.signIn(' mobile@crewmatch.dev ', 'password123');
    expect(session.user, isNotNull);
    expect(tokens.token, 'fresh');

    await expectLater(session.api.matches(), throwsA(anything));
    expect(session.user, isNull);
    expect(session.notice, contains('sign in again'));
    expect(tokens.token, isNull);
  });
}
