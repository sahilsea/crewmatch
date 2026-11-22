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
