import 'json.dart';
import 'user.dart';

/// `GET /leaderboard` (or `/hackathons/:id/leaderboard`): every crew at one
/// hackathon, ranked by the points it has been awarded.
class Leaderboard {
  const Leaderboard({
    required this.title,
    required this.crews,
    this.status = HackathonStatus.live,
    this.startsAt,
    this.updatedAt,
    this.myCrewId,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) => Leaderboard(
        title: json['title'] as String? ?? 'Leaderboard',
        status: HackathonStatus.parse(json['status']),
        startsAt: dateOrNull(json['startsAt']),
        updatedAt: dateOrNull(json['updatedAt']),
        myCrewId: json['myCrewId'] as String?,
        crews: [
          for (final crew in objectList(json['crews'])) RankedCrew.fromJson(crew),
        ],
      );

  /// The hackathon's name, e.g. "MERNOVA X 2026".
  final String title;
  final HackathonStatus status;

  /// When an upcoming hackathon begins; it has no crews until then.
  final DateTime? startsAt;
  final DateTime? updatedAt;
  final String? myCrewId;
  final List<RankedCrew> crews;

  RankedCrew? get myCrew {
    for (final crew in crews) {
      if (crew.id == myCrewId) return crew;
    }
    return null;
  }
}

/// One row of the leaderboard.
class RankedCrew {
  const RankedCrew({
    required this.rank,
    required this.id,
    required this.name,
    this.points = 0,
    this.completed = 0,
    this.events = 0,
    this.challenges = 0,
    this.lastScoredAt,
    this.members = const [],
  });

  factory RankedCrew.fromJson(Map<String, dynamic> json) => RankedCrew(
        rank: intOr(json['rank']),
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        points: intOr(json['points']),
        completed: intOr(json['completed']),
        events: intOr(json['events']),
        challenges: intOr(json['challenges']),
        lastScoredAt: dateOrNull(json['lastScoredAt']),
        members: User.listFrom(json['members']),
      );

  final int rank;
  final String id;
  final String name;
  final int points;

  /// Entries with points awarded, split into [events] and [challenges].
  final int completed;
  final int events;
  final int challenges;
  final DateTime? lastScoredAt;

  /// Members with `id`, `name`, `role` and `avatar` only.
  final List<User> members;
}

enum HackathonStatus {
  live,
  upcoming,
  ended;

  static HackathonStatus parse(Object? value) =>
      values.firstWhere((s) => s.name == value, orElse: () => live);
}

/// One hackathon in the switcher, with your crew's rank there. Each
/// hackathon ranks its own crews; ranks are never combined across them.
class Hackathon {
  const Hackathon({
    required this.id,
    required this.name,
    required this.status,
    this.startsAt,
    this.endedAt,
    this.crewCount = 0,
    this.myRank,
    this.myCrewName,
  });

  factory Hackathon.fromJson(Map<String, dynamic> json) => Hackathon(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        status: HackathonStatus.parse(json['status']),
        startsAt: dateOrNull(json['startsAt']),
        endedAt: dateOrNull(json['endedAt']),
        crewCount: intOr(json['crewCount']),
        myRank: intOrNull(json['myRank']),
        myCrewName: json['myCrewName'] as String?,
      );

  /// The live hackathon this server runs.
  static const currentId = 'current';

  final String id;
  final String name;
  final HackathonStatus status;
  final DateTime? startsAt;
  final DateTime? endedAt;
  final int crewCount;
  final int? myRank;
  final String? myCrewName;
}

/// `GET /hackathons`: every hackathon, and your record across them.
class HackathonList {
  const HackathonList({required this.hackathons, this.attended = 0, this.bestFinish, this.totalPoints = 0});

  factory HackathonList.fromJson(Map<String, dynamic> json) {
    final record = json['record'] as Map<String, dynamic>? ?? const {};
    return HackathonList(
      hackathons: [for (final h in objectList(json['hackathons'])) Hackathon.fromJson(h)],
      attended: intOr(record['hackathons']),
      bestFinish: intOrNull(record['bestFinish']),
      totalPoints: intOr(record['totalPoints']),
    );
  }

  final List<Hackathon> hackathons;

  /// Hackathons you have a rank at.
  final int attended;
  final int? bestFinish;
  final int totalPoints;
}
