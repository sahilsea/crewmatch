import 'package:crewmatch/screens/clubs/clubs_screen.dart';
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

Map<String, dynamic> _club(String id, String name, {bool joined = false, int members = 10}) => {
      'id': id, 'name': name, 'short': name.substring(0, 2).toUpperCase(), 'tone': 'navy', 'verified': id == 'c1',
      'category': 'tech', 'description': '', 'memberCount': members, 'weekEvents': 1, 'joined': joined, 'isLead': false,
    };

void main() {
  setUpAll(() {
    AppType.fetchFonts = false;
    Motion.enabled = false;
  });

  testWidgets('clubs: yours on top, join another and see it change', (tester) async {
    final requests = <http.Request>[];
    final session = Session(
      api: fakeApi({
        'GET /clubs': (_) => (200, {'clubs': [_club('c1', 'Coding Club', joined: true), _club('c2', 'Robotics Society')]}),
        'POST /clubs/c2/join': (_) => (200, {'user': {...userJson(), 'clubIds': ['c1', 'c2']}}),
      }, log: requests),
      tokens: MemoryTokenStore(),
    );
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SessionScope(session: session, child: MaterialApp(theme: buildTheme(), home: const ClubsScreen())));
    await tester.pumpAndSettle();

    expect(find.text('Coding Club'), findsNWidgets(2), reason: 'in Your clubs and in the list');
    expect(find.text('Joined'), findsOneWidget);
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    expect(requests.last.url.path, '/api/clubs/c2/join');
    expect(find.text('Joined'), findsNWidgets(1 + 1));
    expect(find.text('Joined Robotics Society'), findsOneWidget);
    expect(session.user?.clubIds, ['c1', 'c2']);
  });
}
