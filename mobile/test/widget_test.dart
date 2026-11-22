import 'package:crewmatch/app.dart';
import 'package:crewmatch/models/hub_event.dart';
import 'package:crewmatch/screens/events/event_card.dart';
import 'package:crewmatch/state/session.dart';
import 'package:crewmatch/state/token_store.dart';
import 'package:crewmatch/ui/motion.dart';
import 'package:crewmatch/ui/theme.dart';
import 'package:crewmatch/ui/type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_api.dart';
import 'support/fixtures.dart';

/// Pumps the whole app on a phone-sized screen and lets the session restore.
Future<void> pumpApp(WidgetTester tester, Session session) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(CrewMatchApp(session: session));
  await tester.pumpAndSettle();
}

Widget _card(HubEvent event) => MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: EventCard(
            event: event,
            hasCrew: true,
            busy: false,
            onJoin: () {},
            onLeave: () {},
            onCheckIn: () {},
            onSubmit: () {},
          ),
        ),
      ),
    );

void main() {
  // Tests never fetch Google Fonts; text falls back to the test font.
  setUpAll(() {
    AppType.fetchFonts = false;
    Motion.enabled = false;
  });

  testWidgets('signing in lands on the ranked Discover deck', (tester) async {
    final session = Session(
      api: fakeApi({
        'POST /auth/login': (_) => (200, {'token': 'jwt', 'user': userJson()}),
        'GET /deck': (_) => (200, {
              'scoredAgainst': 'you',
              'count': 1,
              'deck': [cardJson('u2', 'Tara Fernandes', score: 92)],
            }),
      }),
      tokens: MemoryTokenStore(),
    );
    await pumpApp(tester, session);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'mobile@crewmatch.dev');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // "Discover" is both the window title and the tab label.
    expect(find.text('Discover'), findsWidgets);
    expect(find.text('Tara Fernandes'), findsOneWidget);
    expect(find.text('92% fit'), findsOneWidget);
    expect(find.text('Fills your frontend gap'), findsOneWidget);
    expect(find.bySemanticsLabel('Like'), findsOneWidget);
  });

  testWidgets('sign-in shows the API field errors under the inputs', (tester) async {
    final session = Session(
      api: fakeApi({
        'POST /auth/login': (_) => (400, {
              'error': 'Validation failed',
              'details': [
                {'field': 'email', 'message': 'Invalid email address'},
              ],
            }),
      }),
      tokens: MemoryTokenStore(),
    );
    await pumpApp(tester, session);

    await tester.enterText(find.byType(TextField).at(0), 'taken@college.edu');
    await tester.enterText(find.byType(TextField).at(1), 'whatever1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email address'), findsOneWidget);
    expect(session.user, isNull);
  });

  testWidgets('sign-up checks the fields before sending anything', (tester) async {
    var calls = 0;
    final session = Session(
      api: fakeApi({
        'POST /auth/register': (_) {
          calls++;
          return (201, <String, Object?>{});
        },
      }),
      tokens: MemoryTokenStore(),
    );
    await pumpApp(tester, session);
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'R2');
    await tester.enterText(find.byType(TextField).at(1), 'nope');
    await tester.enterText(find.byType(TextField).at(2), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Use letters only in your name'), findsOneWidget);
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(calls, 0, reason: 'nothing is sent while a field is wrong');
  });

  testWidgets('a new account lands on the verify screen until the code is right', (tester) async {
    final session = Session(
      api: fakeApi({
        'POST /auth/register': (_) => (201, {'token': 'jwt', 'user': {...userJson(), 'emailVerified': false}, 'devCode': '424242'}),
        'POST /auth/verify': (r) => r.body.contains('424242')
            ? (200, {'user': {...userJson(), 'emailVerified': true}})
            : (400, {'error': 'Wrong code. 4 tries left'}),
        'GET /deck': (_) => (200, {'scoredAgainst': 'you', 'count': 0, 'deck': <Object>[]}),
      }),
      tokens: MemoryTokenStore(),
    );
    await pumpApp(tester, session);
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Demo Mobile');
    await tester.enterText(find.byType(TextField).at(1), 'demo@college.edu');
    await tester.enterText(find.byType(TextField).at(2), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('Your code is 424242'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '111111');
    await tester.pumpAndSettle();
    expect(find.text('Wrong code. 4 tries left'), findsOneWidget);

    await tester.tap(find.text('Use it'));
    await tester.pumpAndSettle();
    expect(find.text('Check your email'), findsNothing);
    expect(session.user!.emailVerified, isTrue);
  });

  testWidgets('a sent-back challenge shows the reviewer note and lets the crew resubmit',
      (tester) async {
    await tester.pumpWidget(_card(HubEvent.fromJson(eventJson(
      kind: 'challenge',
      myEntry: entryJson('joined', submissionUrl: 'https://x.dev/v', note: 'Video is private'),
    ))));

    expect(find.textContaining('Sent back', findRichText: true), findsOneWidget);
    expect(find.textContaining('Video is private', findRichText: true), findsOneWidget);
    expect(find.text('Submit link'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
  });

  testWidgets('a checked-in event shows its points and offers nothing more', (tester) async {
    await tester.pumpWidget(_card(HubEvent.fromJson(eventJson(
      myEntry: entryJson('completed', pointsAwarded: 50),
    ))));

    expect(find.textContaining('Checked in · +50', findRichText: true), findsOneWidget);
    expect(find.text('Check in'), findsNothing);
    expect(find.text('Join'), findsNothing);
  });

  testWidgets('a live event without an RSVP offers join and check-in', (tester) async {
    await tester.pumpWidget(_card(HubEvent.fromJson(eventJson())));

    expect(find.text('Join'), findsOneWidget);
    expect(find.text('Check in'), findsOneWidget);

    // Capacity sits behind "More", like the summary and details.
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('5 / 12 CREWS'), findsOneWidget);
  });
}
