import 'club.dart';
import 'json.dart';

/// Events are things a crew goes to; challenges are tasks a crew takes on.
enum EventKind { event, challenge }

/// Computed by the API on every response.
enum EventState { upcoming, live, ended }

/// `joined` means going (events) or accepted (challenges); `submitted` is a
/// challenge link waiting for review; `completed` means points were awarded.
enum EntryStatus { joined, submitted, completed }

/// `official` events come from organisers. Students host `community` events
/// (no points), or `pending` ones that asked organisers for points.
enum EventStatus { official, community, pending }

/// Who hosts a student event.
class EventHost {
  const EventHost({required this.id, required this.name});

  final String id;
  final String name;
}

/// A crew's entry as organisers see it (`GET /admin/events`).
class AdminEntry {
  const AdminEntry({required this.crewId, required this.crewName, required this.entry});

  factory AdminEntry.fromJson(Map<String, dynamic> json) {
    final crew = json['crew'] as Map<String, dynamic>? ?? const {};
    return AdminEntry(
      crewId: crew['id'] as String? ?? '',
      crewName: crew['name'] as String? ?? '',
      entry: EventEntry.fromJson(json),
    );
  }

  final String crewId;
  final String crewName;
  final EventEntry entry;
}

/// The signed-in user's crew entry on an event or challenge.
class EventEntry {
  const EventEntry({
    required this.status,
    this.submissionUrl,
    this.note,
    this.pointsAwarded = 0,
    this.joinedAt,
    this.completedAt,
  });

  factory EventEntry.fromJson(Map<String, dynamic> json) => EventEntry(
        status: enumByName(EntryStatus.values, json['status'], EntryStatus.joined),
        submissionUrl: json['submissionUrl'] as String?,
        note: json['note'] as String?,
        pointsAwarded: intOr(json['pointsAwarded']),
        joinedAt: dateOrNull(json['joinedAt']),
        completedAt: dateOrNull(json['completedAt']),
      );

  final EntryStatus status;
  final String? submissionUrl;

  /// The crew's note with a submission, or the reviewer's reason after a rejection.
  final String? note;
  final int pointsAwarded;
  final DateTime? joinedAt;
  final DateTime? completedAt;

  /// A reviewer rejected the submission: the entry is back to `joined` but
  /// still carries the old link or the reviewer's note.
  bool get wasSentBack =>
      status == EntryStatus.joined && (submissionUrl != null || note != null);
}

/// One event or challenge from the hackathon hub (`GET /events`).
class HubEvent {
  const HubEvent({
    required this.id,
    required this.kind,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.summary = '',
    this.details = '',
    this.category = '',
    this.location = '',
    this.points = 0,
    this.capacity,
    this.crewCount = 0,
    this.state = EventState.upcoming,
    this.myEntry,
    this.status = EventStatus.official,
    this.askedPoints = 0,
    this.host,
    this.hosting = false,
    this.checkinCode,
    this.entries = const [],
    this.club,
  });

  factory HubEvent.fromJson(Map<String, dynamic> json) {
    final entry = json['myEntry'];
    final host = json['host'];
    return HubEvent(
      id: json['id'] as String,
      kind: enumByName(EventKind.values, json['kind'], EventKind.event),
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      details: json['details'] as String? ?? '',
      category: json['category'] as String? ?? '',
      location: json['location'] as String? ?? '',
      startsAt: dateOrNull(json['startsAt']) ?? DateTime.now(),
      endsAt: dateOrNull(json['endsAt']) ?? DateTime.now(),
      points: intOr(json['points']),
      capacity: intOrNull(json['capacity']),
      crewCount: intOr(json['crewCount']),
      state: enumByName(EventState.values, json['state'], EventState.upcoming),
      myEntry: entry is Map<String, dynamic> ? EventEntry.fromJson(entry) : null,
      status: enumByName(EventStatus.values, json['status'], EventStatus.official),
      askedPoints: intOr(json['askedPoints']),
      host: host is Map<String, dynamic>
          ? EventHost(id: host['id'] as String? ?? '', name: host['name'] as String? ?? '')
          : null,
      hosting: json['hosting'] == true,
      checkinCode: json['checkinCode'] as String?,
      entries: [for (final e in objectList(json['entries'])) AdminEntry.fromJson(e)],
      club: json['club'] is Map<String, dynamic> ? ClubTag.fromJson(json['club'] as Map<String, dynamic>) : null,
    );
  }

  static List<HubEvent> listFrom(Object? json) =>
      [for (final item in objectList(json)) HubEvent.fromJson(item)];

  /// Check-in stays open this long after an event ends.
  static const checkInGrace = Duration(minutes: 30);

  final String id;
  final EventKind kind;
  final String title;
  final String summary;
  final String details;

  /// `workshop | talk | social | expo` or `build | design | pitch | quiz`.
  final String category;
  final String location;

  /// For challenges these are "opens" and "deadline".
  final DateTime startsAt;
  final DateTime endsAt;
  final int points;

  /// Maximum crews, or null for unlimited.
  final int? capacity;
  final int crewCount;
  final EventState state;
  final EventEntry? myEntry;
  final EventStatus status;

  /// Points a student host asked organisers for.
  final int askedPoints;
  final EventHost? host;

  /// The signed-in student hosts this event.
  final bool hosting;

  /// Only for organisers and the event's own host.
  final String? checkinCode;

  /// Every crew's entry. Organisers only.
  final List<AdminEntry> entries;

  /// The club hosting it, if a club lead posted it.
  final ClubTag? club;

  bool get isOfficial => status == EventStatus.official;
  bool get isPending => status == EventStatus.pending;

  bool get isChallenge => kind == EventKind.challenge;
  bool get isFull => capacity != null && crewCount >= capacity!;
  bool get isCompleted => myEntry?.status == EntryStatus.completed;

  /// Whether the check-in button makes sense right now: an event that has
  /// started, has not been checked into, and is at most 30 minutes past its end.
  bool canCheckIn(DateTime now) =>
      !isChallenge &&
      !isCompleted &&
      state != EventState.upcoming &&
      now.isBefore(endsAt.add(checkInGrace));
}

/// `POST /events/:id/checkin`: `{ event, pointsAwarded }`.
class CheckInResult {
  const CheckInResult({required this.event, required this.pointsAwarded});

  factory CheckInResult.fromJson(Map<String, dynamic> json) => CheckInResult(
        event: HubEvent.fromJson(json['event'] as Map<String, dynamic>),
        pointsAwarded: intOr(json['pointsAwarded']),
      );

  final HubEvent event;
  final int pointsAwarded;
}
