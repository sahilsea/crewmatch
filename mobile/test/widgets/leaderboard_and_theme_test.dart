import 'package:crewmatch/models/leaderboard.dart';
import 'package:crewmatch/screens/leaderboard/leaderboard_screen.dart';
import 'package:crewmatch/state/session.dart';
import 'package:crewmatch/state/token_store.dart';
import 'package:crewmatch/ui/motion.dart';
import 'package:crewmatch/ui/palette.dart';
import 'package:crewmatch/ui/theme.dart';
import 'package:crewmatch/ui/type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../support/fake_api.dart';
import '../support/fixtures.dart';

Map<String, dynamic> _hackathonsJson() => {
      'hackathons': [
        {'id': 'current', 'name': 'MERNOVA X 2026', 'status': 'live', 'crewCount': 2, 'myRank': 2, 'myCrewName': 'Pixel Pushers', 'myPoints': 0},
        {'id': 'hc', 'name': 'HackCampus Winter', 'status': 'upcoming', 'startsAt': '2026-12-12T12:00:00.000Z', 'crewCount': 0, 'myRank': null},
        {'id': 'df', 'name': 'DevFest Hack Mumbai', 'status': 'ended', 'endedAt': '2026-08-23T12:30:00.000Z', 'crewCount': 9, 'myRank': 9, 'myCrewName': 'Stack Smashers', 'myPoints': 230},
      ],
      'record': {'hackathons': 2, 'bestFinish': 2, 'totalPoints': 230},
    };

Map<String, dynamic> _pastBoardJson() => {
      'title': 'DevFest Hack Mumbai',
      'status': 'ended',
      'myCrewId': 'stack-smashers',
      'crews': [
        for (final (i, name) in ['Overclocked', 'Segfault', 'Cache Me', 'Deep Dish', 'Pull Request', 'Sudo Make', 'Tab Hoarders', 'Big O', 'Stack Smashers'].indexed)
          {'rank': i + 1, 'id': name.toLowerCase().replaceAll(' ', '-'), 'name': name, 'points': 500 - 30 * i, 'members': <Object>[]},
      ],
    };

void main() {
  setUpAll(() {
    AppType.fetchFonts = false;
    Motion.enabled = false;
  });
  tearDown(() => Palette.isDark = false);

  test('palette colours switch with the theme, so const widgets follow it', () {
    const card = Palette.window;
    expect(card.toARGB32(), 0xFFF3E6CD);
    Palette.isDark = true;
    expect(card.toARGB32(), 0xFF1F1812);
    expect(Palette.ink.toARGB32(), 0xFFF3E9D2);
    expect(buildTheme().brightness, Brightness.dark);
  });

  test('the hackathon list keeps each rank separate and reads the record', () {
    final list = HackathonList.fromJson(_hackathonsJson());
    expect(list.hackathons.map((h) => h.status), [HackathonStatus.live, HackathonStatus.upcoming, HackathonStatus.ended]);
    expect(list.hackathons.map((h) => h.myRank), [2, null, 9]);
    expect((list.attended, list.bestFinish, list.totalPoints), (2, 2, 230));
  });

  testWidgets('switching hackathon loads that board and pins your crew there', (tester) async {
    final requests = <http.Request>[];
    final session = Session(
      api: fakeApi({
        'GET /leaderboard': (_) => (200, leaderboardJson()),
        'GET /hackathons': (_) => (200, _hackathonsJson()),
        'GET /hackathons/df/leaderboard': (_) => (200, _pastBoardJson()),
      }, log: requests),
      tokens: MemoryTokenStore(),
    );
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SessionScope(
      session: session,
      child: MaterialApp(theme: buildTheme(), home: Scaffold(body: LeaderboardScreen(onOpen: (_) {}))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('MERNOVA X 2026'), findsOneWidget);
    expect(find.text('Night Shift'), findsOneWidget);

    await tester.tap(find.text('MERNOVA X 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Best finish'), findsOneWidget);
    expect(find.text('Live · #2 of 2'), findsOneWidget);
    expect(find.text('Starts Dec 12'), findsOneWidget);
    expect(find.text('Aug 2026 · #9 of 9'), findsOneWidget);

    await tester.tap(find.text('DevFest Hack Mumbai'));
    await tester.pumpAndSettle();
    expect(requests.last.url.path, '/api/hackathons/df/leaderboard');
    expect(find.text('Overclocked'), findsOneWidget);
    // Ranks 4–7 show, then your crew at #9 is pinned below them.
    expect(find.text('Big O'), findsNothing);
    expect(find.text('Stack Smashers'), findsOneWidget);
    expect(find.text('Show all 9'), findsOneWidget);
  });
}
