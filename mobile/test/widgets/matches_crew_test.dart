import 'package:crewmatch/screens/matches/matches_screen.dart';
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

/// A full crew: you, Tara, and two more matches.
Map<String, dynamic> _fullCrew() => {
      ...crewJson(),
      'members': [
        {...userJson(), 'crewId': 'crew1'},
        cardJson('u2', 'Tara Fernandes'),
        cardJson('u3', 'Yash Agarwal'),
        cardJson('u4', 'Zoya Khan'),
      ],
      'spotsLeft': 0,
    };

void main() {
  setUpAll(() {
    AppType.fetchFonts = false;
    Motion.enabled = false;
  });

  testWidgets('tapping “Added” takes a match out of a full crew, freeing a spot', (tester) async {
    final requests = <http.Request>[];
    final session = Session(
      api: fakeApi({
        'GET /matches': (_) => (200, {
              'matches': [
                for (final id in ['u2', 'u3', 'u4', 'u5']) {...cardJson(id, 'Person $id'), 'inCrew': id != 'u5'},
              ],
            }),
        'GET /crews/mine': (_) => (200, {'crew': _fullCrew()}),
        'DELETE /crews/mine/members/u3': (_) => (200, {
              'crew': {..._fullCrew(), 'members': (_fullCrew()['members'] as List).where((m) => (m as Map)['id'] != 'u3').toList(), 'spotsLeft': 1},
            }),
      }, log: requests),
      tokens: MemoryTokenStore(),
    );
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SessionScope(
      session: session,
      child: MaterialApp(theme: buildTheme(), home: Scaffold(body: MatchesScreen(onOpen: (_) {}))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('✓ Added'), findsNWidgets(3));

    // Full crew: Add explains instead of failing.
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.textContaining('YOUR CREW IS FULL'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('✓ Added').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(requests.last.method, 'DELETE');
    expect(requests.last.url.path, '/api/crews/mine/members/u3');
    expect(find.text('✓ Added'), findsNWidgets(2));
    expect(find.text('Add'), findsNWidgets(2));
  });
}
