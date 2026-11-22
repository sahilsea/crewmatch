import 'dart:convert';

import 'package:crewmatch/models/team_request.dart';
import 'package:crewmatch/models/user.dart';
import 'package:crewmatch/screens/people/people_ui.dart';
import 'package:crewmatch/screens/people/requests_pane.dart';
import 'package:crewmatch/screens/people/search_screen.dart';
import 'package:crewmatch/state/session.dart';
import 'package:crewmatch/state/token_store.dart';
import 'package:crewmatch/ui/motion.dart';
import 'package:crewmatch/ui/theme.dart';
import 'package:crewmatch/ui/type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../support/fake_api.dart';
import '../support/fixtures.dart';

Future<void> _pump(WidgetTester tester, Session session, Widget child) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SessionScope(session: session, child: MaterialApp(theme: buildTheme(), home: child)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    AppType.fetchFonts = false;
    Motion.enabled = false;
  });

  test('reads handles from profile links, QR codes and typed text', () {
    expect(handleFromLink('https://crewmatch.netlify.app/u/tara-fernandes'), 'tara-fernandes');
    expect(handleFromLink('crewmatch.netlify.app/u/Tara-Fernandes?x=1'), 'tara-fernandes');
    expect(handleFromLink('  aarav-sharma '), 'aarav-sharma');
    expect(handleFromLink('https://example.com/not-a-profile'), isNull);
    expect(handleFromLink('hello world'), isNull);
  });

  testWidgets('search, then a quick request turns the button into Sent', (tester) async {
    final requests = <http.Request>[];
    final session = Session(
      api: fakeApi({
        'GET /users/search': (_) => (200, {
              'results': [
                {...cardJson('u2', 'Tara Fernandes', score: 92), 'handle': 'tara-fernandes', 'crewName': null, 'relation': null},
              ],
            }),
        'POST /requests': (_) => (201, {'match': false, 'request': {'id': 'r1', 'status': 'pending'}}),
      }, log: requests),
      tokens: MemoryTokenStore(),
    );
    await _pump(tester, session, const SearchScreen());

    expect(find.text('Tara Fernandes'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('Looking for a crew'), findsOneWidget);
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();

    final sent = requests.lastWhere((r) => r.method == 'POST');
    expect(jsonDecode(sent.body), {'to': 'u2', 'source': 'search'});
    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('Request sent to Tara'), findsOneWidget);
  });

  testWidgets('accepting a request makes a match and removes the card', (tester) async {
    final requests = <http.Request>[];
    final session = Session(
      api: fakeApi({'POST /requests/r9/accept': (_) => (200, {'match': true, 'user': cardJson('u3', 'Aarav Sharma')})}, log: requests),
      tokens: MemoryTokenStore(),
    );
    User? matched;
    var changed = 0;
    final lists = RequestLists.fromJson({
      'incoming': [
        {'id': 'r9', 'note': 'Want to build the Flutter side?', 'source': 'qr', 'createdAt': DateTime.now().toIso8601String(), 'user': {...cardJson('u3', 'Aarav Sharma', score: 81), 'handle': 'aarav-sharma'}},
      ],
      'sent': <Object>[],
    });
    await _pump(
      tester,
      session,
      Scaffold(body: RequestsPane(lists: lists, onChanged: () => changed++, onMatched: (u) => matched = u)),
    );

    expect(find.text('“Want to build the Flutter side?”'), findsOneWidget);
    expect(find.text('QR code'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(requests.last.url.path, '/api/requests/r9/accept');
    expect(matched?.name, 'Aarav Sharma');
    expect(changed, 1);
    expect(find.text('Aarav Sharma'), findsNothing);
    expect(find.text('No new requests'), findsOneWidget);
  });

  testWidgets('tapping someone\'s photo opens their profile', (tester) async {
    final session = Session(
      api: fakeApi({
        'GET /users/handle/u2': (_) => (200, {
              'user': {...cardJson('u2', 'Tara Fernandes', score: 92), 'handle': 'tara-fernandes', 'relation': null},
              'isMe': false,
            }),
      }),
      tokens: MemoryTokenStore(),
    );
    await _pump(
      tester,
      session,
      const Scaffold(body: Center(child: ProfileTap(userId: 'u2', name: 'Tara Fernandes', child: SizedBox.square(dimension: 48)))),
    );
    await tester.tap(find.bySemanticsLabel("Open Tara Fernandes's profile"));
    await tester.pumpAndSettle();
    expect(find.text('Tara Fernandes'), findsOneWidget);
    expect(find.text('Request to team up'), findsOneWidget);
  });
}
