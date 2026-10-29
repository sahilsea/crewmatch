import 'json.dart';
import 'user.dart';

/// `GET /crews/mine` and the other crew endpoints: `{ crew }`.
class Crew {
  const Crew({
    required this.id,
    required this.name,
    required this.members,
    this.createdBy = '',
    this.checklist = const {},
    this.spotsLeft = 0,
    this.points = 0,
    this.rank,
  });

  factory Crew.fromJson(Map<String, dynamic> json) {
    final checklist = json['checklist'];
    return Crew(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      members: User.listFrom(json['members']),
      checklist: {
        if (checklist is Map<String, dynamic>)
          for (final entry in checklist.entries) entry.key: entry.value == true,
      },
      spotsLeft: intOr(json['spotsLeft']),
      points: intOr(json['points']),
      rank: intOrNull(json['rank']),
    );
  }

  /// `{ crew: null }` means the user has no crew.
  static Crew? maybeFromJson(Object? json) =>
      json is Map<String, dynamic> ? Crew.fromJson(json) : null;

  static const maxSize = 4;

  final String id;
  final String name;
  final String createdBy;
  final List<User> members;

  /// What the crew covers: `frontend`, `backend`, `designer`, `pitching`.
  final Map<String, bool> checklist;
  final int spotsLeft;

  /// Hackathon points and leaderboard position (1-based), when the API sends them.
  final int points;
  final int? rank;

  List<String> get missing => [
        for (final entry in checklist.entries)
          if (!entry.value) entry.key,
      ];

  bool hasMember(String userId) => members.any((m) => m.id == userId);
}
