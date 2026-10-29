import 'json.dart';
import 'user.dart';

/// `GET /leaderboard`: every crew ranked by the points it has been awarded.
class Leaderboard {
  const Leaderboard({
    required this.title,
    required this.crews,
    this.updatedAt,
    this.myCrewId,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) => Leaderboard(
        title: json['title'] as String? ?? 'Leaderboard',
        updatedAt: dateOrNull(json['updatedAt']),
        myCrewId: json['myCrewId'] as String?,
        crews: [
          for (final crew in objectList(json['crews'])) RankedCrew.fromJson(crew),
        ],
      );

  /// The hackathon's name, e.g. "MERNOVA X 2026".
  final String title;
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
