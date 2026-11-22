import 'dart:convert';

import 'package:crewmatch/models/crew.dart';
import 'package:crewmatch/screens/chat/chat_screen.dart';
import 'package:crewmatch/screens/posts/posts_screen.dart';
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

Map<String, dynamic> _post(String id, String text, {int likes = 3, bool liked = false, String authorId = 'u9'}) => {
      'id': id,
      'author': {'id': authorId, 'name': 'Tara Fernandes', 'avatar': '', 'role': 'designer'},
      'crewName': 'Night Shift',
      'text': text,
      'tag': 'win',
      'photoUrl': null,
      'likeCount': likes,
      'likedByMe': liked,
      'commentCount': 0,
      'comments': <Object>[],
      'createdAt': DateTime.now().subtract(const Duration(minutes: 12)).toUtc().toIso8601String(),
    };

Future<void> _pump(WidgetTester tester, Session session, Widget screen) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SessionScope(
    session: session,
    child: MaterialApp(theme: buildTheme(), home: Scaffold(body: screen)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    AppType.fetchFonts = false;
    Motion.enabled = false;
  });

  testWidgets('the Posts tab shows live events above the feed, and likes update at once', (tester) async {
    final requests = <http.Request>[];
    final session = Session(
      api: fakeApi({
        'GET /posts': (_) => (200, {'posts': [_post('p1', 'We shipped CampusCart!')], 'hasMore': false}),
        'GET /events': (_) => (200, {'events': [eventJson()]}),
        'POST /posts/p1/like': (_) => (200, {'post': _post('p1', 'We shipped CampusCart!', likes: 4, liked: true)}),
      }, log: requests),
      tokens: MemoryTokenStore(),
    );
    await _pump(tester, session, PostsScreen(onOpen: (_) {}));

    expect(find.text('Happening now'), findsOneWidget);
    expect(find.text('All events'), findsOneWidget);
    expect(find.text('We shipped CampusCart!'), findsOneWidget);
    expect(find.text('Night Shift · 12m'), findsOneWidget);
    expect(find.text('Win'), findsOneWidget);
    expect(find.text('New post'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();
    expect(requests.last.url.path, '/api/posts/p1/like');
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('crew chat groups messages and sends new ones', (tester) async {
    final requests = <http.Request>[];
    final now = DateTime.now().toUtc();
    Map<String, dynamic> msg(String id, String? authorId, String text, int minsAgo, {bool system = false}) => {
          'id': id,
          'kind': system ? 'system' : 'text',
          'text': text,
          'author': authorId == null ? null : {'id': authorId, 'name': authorId == 'u1' ? 'Demo Mobile' : 'Tara Fernandes', 'avatar': ''},
          'createdAt': now.subtract(Duration(minutes: minsAgo)).toIso8601String(),
        };
    final session = Session(
      api: fakeApi({
        'GET /crews/mine/messages': (r) => (200, {
              'messages': r.url.queryParameters.containsKey('after')
                  ? <Object>[]
                  : [msg('m1', 'u2', 'Code is up at the expo hall', 9), msg('m2', null, 'Tara checked the crew in at Stall Hop · +40', 5, system: true)],
            }),
        'POST /crews/mine/messages': (r) => (201, {'message': msg('m3', 'u1', jsonDecode(r.body)['text'] as String, 0)}),
        'POST /auth/login': (_) => (200, {'token': 'jwt', 'user': userJson()}),
      }, log: requests),
      tokens: MemoryTokenStore(),
    );
    await session.signIn('mobile@crewmatch.dev', 'password123');
    await _pump(tester, session, ChatScreen(crew: Crew.fromJson(crewJson())));

    expect(find.text('Night Shift'), findsOneWidget);
    expect(find.text('Code is up at the expo hall'), findsOneWidget);
    expect(find.text('Tara'), findsOneWidget);
    expect(find.text('Tara checked the crew in at Stall Hop · +40'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'On my way');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(requests.last.method, 'POST');
    expect(jsonDecode(requests.last.body), {'text': 'On my way'});
    expect(find.text('On my way'), findsOneWidget);

    // Leave the screen so its poll timer stops.
    await tester.pumpWidget(const SizedBox());
  });
}
