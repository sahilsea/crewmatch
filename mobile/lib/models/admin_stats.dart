import 'json.dart';

/// `GET /admin/stats`: the numbers on the organiser overview.
class AdminStats {
  const AdminStats({
    this.students = 0,
    this.crews = 0,
    this.events = 0,
    this.challenges = 0,
    this.liveEvents = 0,
    this.pendingSubmissions = 0,
    this.pendingEvents = 0,
    this.byRole = const [],
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        students: intOr(json['totalUsers']),
        crews: intOr(json['crews']),
        events: intOr(json['events']),
        challenges: intOr(json['challenges']),
        liveEvents: intOr(json['liveEvents']),
        pendingSubmissions: intOr(json['pendingSubmissions']),
        pendingEvents: intOr(json['pendingEvents']),
        byRole: [
          for (final r in objectList(json['byRole'])) (role: r['role'] as String? ?? '', count: intOr(r['count'])),
        ],
      );

  final int students;
  final int crews;
  final int events;
  final int challenges;
  final int liveEvents;
  final int pendingSubmissions;
  final int pendingEvents;
  final List<({String role, int count})> byRole;

  int get waiting => pendingSubmissions + pendingEvents;
}
