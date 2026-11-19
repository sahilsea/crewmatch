import 'dart:convert';

import 'package:crewmatch/models/deck.dart';
import 'package:crewmatch/models/hub_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/fake_api.dart';
import '../support/fixtures.dart';

void main() {
  test('each call hits the documented method and path', () async {
    final log = <http.Request>[];
    final api = fakeApi({
      'POST /swipe': (_) => (200, {'match': false}),
      'POST /crews': (_) => (201, {'crew': crewJson()}),
      'GET /events': (_) => (200, {'events': [eventJson()]}),
      'DELETE /events/e1/join': (_) => (200, {'event': eventJson()}),
      'POST /events/e1/checkin': (_) => (200, {'event': eventJson(), 'pointsAwarded': 50}),
      'POST /events/e1/submit': (_) => (200, {'event': eventJson(kind: 'challenge')}),
      'DELETE /matches/u2': (_) => (204, null),
    }, log: log);

    await api.swipe('u2', SwipeDirection.right);
    await api.createCrew('Night Shift', ['u2']);
    await api.events(kind: EventKind.challenge);
    await api.leaveEvent('e1');
    await api.checkIn('e1', 'WDGT');
    await api.submitChallenge('e1', url: 'https://example.com/demo', note: '');
    await api.unmatch('u2');

    expect([for (final r in log) '${r.method} ${r.url.path}${r.url.hasQuery ? '?${r.url.query}' : ''}'], [
      'POST /api/swipe',
      'POST /api/crews',
      'GET /api/events?kind=challenge',
      'DELETE /api/events/e1/join',
      'POST /api/events/e1/checkin',
      'POST /api/events/e1/submit',
      'DELETE /api/matches/u2',
    ]);
    expect(jsonDecode(log[0].body), {'targetId': 'u2', 'direction': 'right'});
    expect(jsonDecode(log[1].body), {'name': 'Night Shift', 'memberIds': ['u2']});
    expect(jsonDecode(log[4].body), {'code': 'WDGT'});
    // An empty note is left out rather than sent as "".
    expect(jsonDecode(log[5].body), {'url': 'https://example.com/demo'});
  });

  test('typed results come back from the wrapped responses', () async {
    final api = fakeApi({
      'GET /auth/me': (_) => (200, {'user': userJson()}),
      'GET /crews/mine': (_) => (200, {'crew': null}),
      'GET /matches': (_) => (200, {
            'count': 1,
            'matches': [
              {...cardJson('u2', 'Tara Fernandes'), 'email': 'tara@x.dev', 'inCrew': true},
            ],
          }),
      'POST /events/e1/checkin': (_) => (200, {'event': eventJson(), 'pointsAwarded': 50}),
    });

    expect((await api.me()).name, 'Demo Mobile');
    expect(await api.myCrew(), isNull);
    expect((await api.matches()).single.inCrew, isTrue);
    expect((await api.checkIn('e1', 'wdgt')).pointsAwarded, 50);
  });
}
