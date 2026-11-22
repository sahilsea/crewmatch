// JSON shaped like real API responses (server/models/User.js toSelf/toPublic,
// docs/hackathon-api.md), shared by the tests.

Map<String, dynamic> userJson({
  String id = 'u1',
  String name = 'Demo Mobile',
  bool profileComplete = true,
  String? crewId,
}) =>
    {
      'id': id,
      'name': name,
      'avatar': '',
      'bio': 'Designer who can pitch.',
      'role': 'designer',
      'experienceLevel': 'intermediate',
      'schedule': 'night_owl',
      'commitment': 'here_to_win',
      'communication': 'chat',
      'interests': ['ai', 'health'],
      'superpowers': ['ui_design', 'pitching'],
      'skills': ['Figma', 'Flutter'],
      'email': 'mobile@crewmatch.dev',
      'profileComplete': profileComplete,
      'crewId': crewId,
      'isAdmin': false,
      'matchCount': 2,
    };

Map<String, dynamic> cardJson(String id, String name, {int score = 80}) => {
      'id': id,
      'name': name,
      'avatar': '',
      'bio': 'I turn rough ideas into screens people enjoy.',
      'role': 'frontend',
      'experienceLevel': 'advanced',
      'schedule': 'night_owl',
      'commitment': 'committed',
      'communication': 'chat',
      'interests': ['ai'],
      'superpowers': <String>[],
      'skills': ['React', 'TypeScript'],
      'score': score,
      'tags': ['Fills your frontend gap', 'Fellow night owl'],
    };

Map<String, dynamic> crewJson({int points = 120, int? rank = 3}) => {
      'id': 'crew1',
      'name': 'Night Shift',
      'createdBy': 'u1',
      'members': [
        {...userJson(), 'crewId': null},
        {...cardJson('u2', 'Tara Fernandes'), 'email': 'tara@students.crewmatch.dev'},
      ],
      'checklist': {'frontend': true, 'backend': false, 'designer': true, 'pitching': true},
      'ideas': <Object>[],
      'spotsLeft': 2,
      'points': points,
      'rank': rank,
    };

Map<String, dynamic> eventJson({
  String id = 'e1',
  String kind = 'event',
  String state = 'live',
  Map<String, dynamic>? myEntry,
  int? capacity = 12,
  int crewCount = 5,
  Duration startedAgo = const Duration(minutes: 30),
  Duration endsIn = const Duration(hours: 1),
}) {
  final now = DateTime.now();
  return {
    'id': id,
    'kind': kind,
    'title': kind == 'event' ? 'Figma to Flutter Workshop' : 'One-Minute Pitch',
    'summary': 'One line for cards',
    'details': '',
    'category': kind == 'event' ? 'workshop' : 'pitch',
    'location': kind == 'event' ? 'Lab 3, Block B' : 'Online',
    'startsAt': now.subtract(startedAgo).toUtc().toIso8601String(),
    'endsAt': now.add(endsIn).toUtc().toIso8601String(),
    'points': 50,
    'capacity': capacity,
    'crewCount': crewCount,
    'state': state,
    'myEntry': myEntry,
  };
}

Map<String, dynamic> entryJson(
  String status, {
  String? submissionUrl,
  String? note,
  int pointsAwarded = 0,
}) =>
    {
      'status': status,
      'submissionUrl': submissionUrl,
      'note': note,
      'pointsAwarded': pointsAwarded,
      'joinedAt': '2026-10-28T08:00:00.000Z',
      'completedAt': status == 'completed' ? '2026-10-28T09:00:00.000Z' : null,
    };

Map<String, dynamic> leaderboardJson() => {
      'title': 'MERNOVA X 2026',
      'updatedAt': '2026-10-28T10:15:00.000Z',
      'myCrewId': 'crew2',
      'crews': [
        {
          'rank': 1,
          'id': 'crew1',
          'name': 'Night Shift',
          'points': 320,
          'completed': 6,
          'events': 3,
          'challenges': 3,
          'lastScoredAt': '2026-10-28T09:50:00.000Z',
          'members': [
            {'id': 'u9', 'name': 'Tara Fernandes', 'role': 'designer', 'avatar': ''},
          ],
        },
        {
          'rank': 2,
          'id': 'crew2',
          'name': 'Pixel Pushers',
          'points': 0,
          'completed': 0,
          'events': 0,
          'challenges': 0,
          'lastScoredAt': null,
          'members': <Object>[],
        },
      ],
    };
