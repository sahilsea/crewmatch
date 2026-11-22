import 'package:crewmatch/models/auth_result.dart';
import 'package:crewmatch/models/crew.dart';
import 'package:crewmatch/models/deck.dart';
import 'package:crewmatch/models/hub_event.dart';
import 'package:crewmatch/models/leaderboard.dart';
import 'package:crewmatch/models/profile_options.dart';
import 'package:crewmatch/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  test('auth result: token and the signed-in user', () {
    final result = AuthResult.fromJson({'token': 'jwt', 'user': userJson(profileComplete: false)});
    expect(result.token, 'jwt');
    expect(result.user.email, 'mobile@crewmatch.dev');
    expect(result.user.profileComplete, isFalse);
    expect(result.user.crewId, isNull);
    expect(result.user.superpowers, ['ui_design', 'pitching']);
    expect(result.user.matchCount, 2);
  });

  test('a new user without chips yet parses with empty defaults', () {
    final user = User.fromJson({
      'id': 'u3',
      'name': 'New Student',
      'avatar': '',
      'bio': '',
      'interests': <String>[],
      'superpowers': <String>[],
      'skills': <String>[],
      'email': 'new@college.edu',
      'profileComplete': false,
      'crewId': null,
      'isAdmin': false,
      'matchCount': 0,
    });
    expect(user.role, isNull);
    expect(user.interests, isEmpty);
    expect(user.score, isNull);
  });

  test('options: chip values per field and the superpower limit', () {
    final options = ProfileOptions.fromJson({
      'role': ['frontend', 'backend'],
      'interests': ['ai', 'climate'],
      'maxSuperpowers': 2,
    });
    expect(options['role'], ['frontend', 'backend']);
    expect(options['unknown'], isEmpty);
    expect(options.maxSuperpowers, 2);
  });

  test('deck: cards with fit and reasons, scored against the crew', () {
    final deck = Deck.fromJson({
      'scoredAgainst': 'crew',
      'count': 1,
      'deck': [cardJson('u2', 'Tara Fernandes', score: 92)],
    });
    expect(deck.scoredAgainstCrew, isTrue);
    expect(deck.cards.single.score, 92);
    expect(deck.cards.single.tags, contains('Fellow night owl'));
  });

  test('swipe: a match carries the other person with their email', () {
    final match = SwipeResult.fromJson({
      'match': true,
      'user': {...cardJson('u2', 'Tara Fernandes'), 'email': 'tara@x.dev'},
    });
    expect(match.match, isTrue);
    expect(match.user!.email, 'tara@x.dev');
    expect(SwipeResult.fromJson({'match': false}).user, isNull);
  });

  test('crew: members, checklist, spots, points and rank', () {
    final crew = Crew.maybeFromJson(crewJson())!;
    expect(crew.members.map((m) => m.name), ['Demo Mobile', 'Tara Fernandes']);
    expect(crew.missing, ['backend']);
    expect(crew.spotsLeft, 2);
    expect(crew.points, 120);
    expect(crew.rank, 3);
    expect(crew.hasMember('u2'), isTrue);
    expect(Crew.maybeFromJson(null), isNull);
  });

  test('event: kind, state, capacity and the crew entry', () {
    final event = HubEvent.fromJson(eventJson(myEntry: entryJson('joined')));
    expect(event.kind, EventKind.event);
    expect(event.state, EventState.live);
    expect(event.isFull, isFalse);
    expect(event.myEntry!.status, EntryStatus.joined);
    expect(event.myEntry!.wasSentBack, isFalse);
    expect(event.canCheckIn(DateTime.now()), isTrue);

    final full = HubEvent.fromJson(eventJson(capacity: 5, crewCount: 5));
    expect(full.isFull, isTrue);
    expect(HubEvent.fromJson(eventJson(capacity: null)).isFull, isFalse);
  });

  test('event: check-in closes 30 minutes after the end', () {
    final ended = HubEvent.fromJson(eventJson(
      state: 'ended',
      startedAgo: const Duration(hours: 2),
      endsIn: const Duration(minutes: -20),
    ));
    expect(ended.canCheckIn(DateTime.now()), isTrue);
    expect(ended.canCheckIn(DateTime.now().add(const Duration(minutes: 15))), isFalse);
  });

  test('challenge: a rejected entry keeps the reviewer note', () {
    final challenge = HubEvent.fromJson(eventJson(
      kind: 'challenge',
      myEntry: entryJson('joined', submissionUrl: 'https://x.dev/v', note: 'Video is private'),
    ));
    expect(challenge.isChallenge, isTrue);
    expect(challenge.canCheckIn(DateTime.now()), isFalse);
    expect(challenge.myEntry!.wasSentBack, isTrue);
    expect(challenge.myEntry!.note, 'Video is private');

    final done = HubEvent.fromJson(eventJson(myEntry: entryJson('completed', pointsAwarded: 50)));
    expect(done.isCompleted, isTrue);
    expect(done.myEntry!.pointsAwarded, 50);
    expect(done.myEntry!.completedAt, isNotNull);
  });

  test('check-in result: the event and the points', () {
    final result = CheckInResult.fromJson({
      'event': eventJson(myEntry: entryJson('completed', pointsAwarded: 50)),
      'pointsAwarded': 50,
    });
    expect(result.pointsAwarded, 50);
    expect(result.event.isCompleted, isTrue);
  });

  test('leaderboard: ranked crews and which one is mine', () {
    final board = Leaderboard.fromJson(leaderboardJson());
    expect(board.title, 'MERNOVA X 2026');
    expect(board.crews.map((c) => c.rank), [1, 2]);
    expect(board.crews.first.members.single.role, 'designer');
    expect(board.crews.last.lastScoredAt, isNull);
    expect(board.myCrew!.name, 'Pixel Pushers');
  });

  test('unknown enum values fall back instead of throwing', () {
    final event = HubEvent.fromJson({...eventJson(), 'kind': 'hackathon', 'state': 'paused'});
    expect(event.kind, EventKind.event);
    expect(event.state, EventState.upcoming);
  });
}
