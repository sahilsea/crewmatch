import 'dart:convert';

import 'package:crewmatch/screens/admin/admin_review_screen.dart';
import 'package:crewmatch/screens/events/create_event_screen.dart';
import 'package:crewmatch/state/session.dart';
import 'package:crewmatch/state/token_store.dart';
import 'package:crewmatch/ui/motion.dart';
import 'package:crewmatch/ui/theme.dart';
import 'package:crewmatch/ui/type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../support/fake_api.dart';

Map<String, dynamic> _event(String id, String title, {String status = 'official', List<Object> entries = const [], int asked = 0}) => {
      'id': id,
      'kind': status == 'official' && entries.isNotEmpty ? 'challenge' : 'event',
      'title': title,
      'summary': 'A line about $title',
      'category': status == 'official' && entries.isNotEmpty ? 'build' : 'workshop',
      'location': 'Lab 3',
      'startsAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'endsAt': DateTime.now().add(const Duration(days: 1, hours: 2)).toIso8601String(),
      'points': status == 'official' ? 150 : 0,
      'status': status,
      'askedPoints': asked,
      'host': status == 'official' ? null : {'id': 'u9', 'name': 'Aarav Sharma'},
      'state': 'upcoming',
      'crewCount': entries.length,
      'entries': entries,
    };

Future<void> _pump(WidgetTester tester, Session session, Widget child) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SessionScope(
    session: session,
    child: MaterialApp(theme: buildTheme(), home: Scaffold(body: child)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    AppType.fetchFonts = false;
    Motion.enabled = false;
  });

  testWidgets('review: approve a crew link with bonus points, make a proposal official', (tester) async {
    final requests = <http.Request>[];
    final events = [
      _event('c1', 'Fix a Campus Problem', entries: [
        {'crew': {'id': 'crew7', 'name': 'Null Pointers'}, 'status': 'submitted', 'submissionUrl': 'https://github.com/np/fix', 'pointsAwarded': 0},
      ]),
      _event('e2', 'Flutter Study Jam', status: 'pending', asked: 30),
    ];
    final session = Session(
      api: fakeApi({
        'GET /admin/events': (_) => (200, {'events': events}),
        'POST /admin/events/c1/entries/crew7/approve': (_) => (200, {'event': events[0]}),
        'POST /admin/events/e2/official': (_) => (200, {'event': {...events[1], 'status': 'official'}}),
      }, log: requests),
      tokens: MemoryTokenStore(),
    );
    var changed = 0;
    await _pump(tester, session, AdminReviewScreen(wide: false, onChanged: () => changed++));

    expect(find.text('Null Pointers'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    await tester.tap(find.byTooltip('More points'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(requests.last.url.path, '/api/admin/events/c1/entries/crew7/approve');
    expect(jsonDecode(requests.last.body), {'points': 160});
    expect(find.text('Null Pointers'), findsNothing);

    // Proposals: the asked points are the starting value.
    await tester.tap(find.textContaining('Event proposals'));
    await tester.pumpAndSettle();
    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    await tester.tap(find.text('Make official'));
    await tester.pumpAndSettle();
    expect(requests.last.url.path, '/api/admin/events/e2/official');
    expect(jsonDecode(requests.last.body), {'points': 30});
    expect(find.text('All caught up'), findsOneWidget);
    expect(changed, 2);
  });

  testWidgets('a student hosts an event and asks for points', (tester) async {
    final requests = <http.Request>[];
    final session = Session(
      api: fakeApi({
        'POST /events': (req) {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          return (201, {
            'event': {
              ..._event('n1', body['title'] as String, status: 'pending', asked: body['askPoints'] as int),
              'hosting': true,
              'checkinCode': 'J8RW',
            },
          });
        },
      }, log: requests),
      tokens: MemoryTokenStore(),
    );
    await _pump(tester, session, const CreateEventScreen());

    expect(find.text('Publish'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Flutter Study Jam');
    await tester.enterText(find.byType(TextField).at(1), 'Build a to-do app together');
    await tester.ensureVisible(find.text('Ask for leaderboard points'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask for leaderboard points'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+30'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Publish and send for review'));
    await tester.tap(find.text('Publish and send for review'));
    await tester.pumpAndSettle();

    final sent = jsonDecode(requests.last.body) as Map<String, dynamic>;
    expect([sent['kind'], sent['title'], sent['category'], sent['askPoints']], ['event', 'Flutter Study Jam', 'workshop', 30]);
    expect(find.text("It's live"), findsOneWidget);
    expect(find.text('+30 pending review'), findsOneWidget);
    expect(find.text('Code J8RW'), findsOneWidget);
  });
}
