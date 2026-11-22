import 'package:crewmatch/models/post.dart';
import 'package:crewmatch/models/user.dart';
import 'package:crewmatch/screens/discover/profile_card.dart';
import 'package:crewmatch/ui/motion.dart';
import 'package:crewmatch/ui/theme.dart';
import 'package:crewmatch/ui/type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fixtures.dart';

void main() {
  setUpAll(() {
    AppType.fetchFonts = false;
    Motion.enabled = false;
  });

  testWidgets('a swipe card shows the headline and only the details its owner chose', (tester) async {
    final person = User.fromJson({
      ...cardJson('u2', 'Tara Fernandes', score: 92),
      'headline': 'APIs that never go down',
      'cover': 'gold',
      'accent': 'teal',
      'cardFields': ['skills'],
      'superpowers': ['pitching'],
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: Center(child: SizedBox(width: 358, height: 560, child: ProfileCard(person: person)))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('APIs that never go down'), findsOneWidget);
    expect(find.text('92% fit'), findsOneWidget);
    expect(find.text('React'), findsOneWidget, reason: 'skills are switched on');
    expect(find.text('Pitching'), findsNothing, reason: 'superpowers are switched off');
    expect(find.text('Frontend'), findsOneWidget, reason: 'the role always shows');
  });

  test('chat attachments read their kind, link and size', () {
    final m = ChatMessage.fromJson({
      'id': 'm1',
      'kind': 'text',
      'text': '',
      'author': {'id': 'u1', 'name': 'Demo'},
      'attachment': {'kind': 'file', 'url': '/api/crews/mine/files/abc', 'name': 'Pitch deck.pdf', 'type': 'application/pdf', 'size': 2516582},
      'createdAt': '2026-11-20T10:00:00.000Z',
    });
    expect(m.attachment!.photo, isFalse);
    expect(m.attachment!.summary, 'PDF · 2.4 MB');
    final a = ActivityItem.fromJson({'kind': 'match', 'text': 'Matched with you', 'at': null});
    expect((a.kind, a.at), ('match', null));
  });
}
