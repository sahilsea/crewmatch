import 'hub_event.dart';
import 'json.dart';
import 'user.dart';

/// The small club badge on cards, profiles and events.
class ClubTag {
  const ClubTag({required this.id, required this.name, required this.short, this.tone = 'navy', this.verified = false, this.demo = false});

  factory ClubTag.fromJson(Map<String, dynamic> json) => ClubTag(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        short: json['short'] as String? ?? '',
        tone: json['tone'] as String? ?? 'navy',
        verified: json['verified'] == true,
        demo: json['demo'] == true,
      );

  static List<ClubTag> listFrom(Object? json) => [for (final c in objectList(json)) ClubTag.fromJson(c)];

  final String id;
  final String name;

  /// Two or three letters for the logo tile.
  final String short;

  /// `crimson | navy | gold | cream`.
  final String tone;

  /// Its events count for points without review.
  final bool verified;

  /// A sample club from the demo data.
  final bool demo;
}

/// A campus club (`GET /clubs`).
class Club extends ClubTag {
  const Club({
    required super.id,
    required super.name,
    required super.short,
    super.tone,
    super.verified,
    super.demo,
    this.category = 'tech',
    this.description = '',
    this.memberCount = 0,
    this.weekEvents = 0,
    this.joined = false,
    this.isLead = false,
    this.leads = const [],
  });

  factory Club.fromJson(Map<String, dynamic> json) => Club(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        short: json['short'] as String? ?? '',
        tone: json['tone'] as String? ?? 'navy',
        verified: json['verified'] == true,
        demo: json['demo'] == true,
        category: json['category'] as String? ?? 'tech',
        description: json['description'] as String? ?? '',
        memberCount: intOr(json['memberCount']),
        weekEvents: intOr(json['weekEvents']),
        joined: json['joined'] == true,
        isLead: json['isLead'] == true,
        leads: stringList(json['leads']),
      );

  static List<Club> listFrom(Object? json) => [for (final c in objectList(json)) Club.fromJson(c)];

  static const categories = ['tech', 'design', 'business', 'culture', 'sports'];
  static const tones = ['crimson', 'navy', 'gold', 'cream'];

  /// `tech | design | business | culture | sports`.
  final String category;
  final String description;
  final int memberCount;

  /// Events in the coming week.
  final int weekEvents;
  final bool joined;

  /// You can post events for this club.
  final bool isLead;

  /// Organisers only: the leads' emails.
  final List<String> leads;

  Club copyWith({bool? joined, int? memberCount}) => Club(
        id: id,
        name: name,
        short: short,
        tone: tone,
        verified: verified,
        demo: demo,
        category: category,
        description: description,
        memberCount: memberCount ?? this.memberCount,
        weekEvents: weekEvents,
        joined: joined ?? this.joined,
        isLead: isLead,
        leads: leads,
      );
}

/// `GET /clubs/:id`: the club, its upcoming events and its members.
class ClubPage {
  const ClubPage({required this.club, this.events = const [], this.members = const []});

  factory ClubPage.fromJson(Map<String, dynamic> json) => ClubPage(
        club: Club.fromJson(json['club'] as Map<String, dynamic>),
        events: HubEvent.listFrom(json['events']),
        members: User.listFrom(json['members']),
      );

  final Club club;
  final List<HubEvent> events;
  final List<User> members;
}
