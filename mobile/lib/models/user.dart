import 'club.dart';
import 'json.dart';

/// Where you stand with someone: nothing yet, a request either way, or matched.
enum Relation { none, sent, received, matched }

/// A student as the API returns them.
///
/// One shape serves several endpoints. Everyone has the public profile
/// fields. `/auth/me` adds the self-only fields (email, profileComplete,
/// crewId, isAdmin, matchCount), deck cards add [score] and [tags], and
/// matches add [email], [inCrew], [score] and [tags].
class User {
  const User({
    required this.id,
    required this.name,
    this.avatar = '',
    this.bio = '',
    this.role,
    this.experienceLevel,
    this.schedule,
    this.commitment,
    this.communication,
    this.interests = const [],
    this.superpowers = const [],
    this.skills = const [],
    this.email,
    this.profileComplete = false,
    this.crewId,
    this.isAdmin = false,
    this.matchCount = 0,
    this.score,
    this.tags = const [],
    this.inCrew = false,
    this.emailVerified = true,
    this.headline = '',
    this.cover = 'dusk',
    this.coverUrl,
    this.accent = 'crimson',
    this.cardFields = const ['superpowers', 'skills', 'experience'],
    this.handle,
    this.crewName,
    this.relation,
    this.requestId,
    this.clubs = const [],
    this.clubIds = const [],
    this.isLead = false,
    this.breakdown,
    this.record,
    this.demo = false,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        avatar: json['avatar'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        role: json['role'] as String?,
        experienceLevel: json['experienceLevel'] as String?,
        schedule: json['schedule'] as String?,
        commitment: json['commitment'] as String?,
        communication: json['communication'] as String?,
        interests: stringList(json['interests']),
        superpowers: stringList(json['superpowers']),
        skills: stringList(json['skills']),
        email: json['email'] as String?,
        profileComplete: json['profileComplete'] as bool? ?? false,
        crewId: json['crewId'] as String?,
        isAdmin: json['isAdmin'] as bool? ?? false,
        matchCount: intOr(json['matchCount']),
        score: intOrNull(json['score']),
        tags: stringList(json['tags']),
        inCrew: json['inCrew'] as bool? ?? false,
        emailVerified: json['emailVerified'] as bool? ?? true,
        headline: json['headline'] as String? ?? '',
        cover: json['cover'] as String? ?? 'dusk',
        coverUrl: json['coverUrl'] as String?,
        accent: json['accent'] as String? ?? 'crimson',
        cardFields: json['cardFields'] == null ? const ['superpowers', 'skills', 'experience'] : stringList(json['cardFields']),
        handle: json['handle'] as String?,
        crewName: json['crewName'] as String?,
        relation: enumByName(Relation.values, json['relation'], Relation.none),
        requestId: json['requestId'] as String?,
        clubs: ClubTag.listFrom(json['clubs']),
        clubIds: stringList(json['clubIds']),
        isLead: json['isLead'] == true,
        breakdown: FitBreakdown.from(json['breakdown']),
        record: HackRecord.from(json['record']),
        demo: json['demo'] == true,
      );

  static List<User> listFrom(Object? json) =>
      [for (final item in objectList(json)) User.fromJson(item)];

  final String id;
  final String name;
  final String avatar;
  final String bio;
  final String? role;
  final String? experienceLevel;
  final String? schedule;
  final String? commitment;
  final String? communication;
  final List<String> interests;
  final List<String> superpowers;
  final List<String> skills;

  final String? email;
  final bool profileComplete;
  final String? crewId;
  final bool isAdmin;
  final int matchCount;

  /// Fit with you (or your crew), 0 to 100.
  final int? score;

  /// Short reasons for the fit, e.g. "Fills your design gap".
  final List<String> tags;

  /// Already in some crew (matches only).
  final bool inCrew;

  /// Your own account only: new accounts confirm their email with a code.
  final bool emailVerified;

  /// The swipe card: a line over the cover, which cover, the accent colour
  /// and which details show. See `ui/card_style.dart`.
  final String headline;
  final String cover;

  /// The uploaded cover photo, when [cover] is `photo`.
  final String? coverUrl;
  final String accent;
  final List<String> cardFields;

  /// The short name in their profile link, e.g. `tara-fernandes`.
  final String? handle;

  /// Search and profiles: the crew they're in, if any.
  final String? crewName;

  /// Search and profiles: where you stand with them.
  final Relation? relation;

  /// The pending request between you, when [relation] is sent or received.
  final String? requestId;

  /// Their campus clubs (search, profiles, club pages).
  final List<ClubTag> clubs;

  /// Your own account: the clubs you're in.
  final List<String> clubIds;

  /// On a club page: they lead the club.
  final bool isLead;

  /// Deck cards: how the fit score splits up.
  final FitBreakdown? breakdown;

  /// Deck cards: what their crew has finished.
  final HackRecord? record;

  /// A sample account from the demo data.
  final bool demo;

  User copyWith({
    Relation? relation,
    bool? inCrew,
    int? matchCount,
    String? headline,
    String? cover,
    String? accent,
    List<String>? cardFields,
  }) =>
      User(
        id: id,
        name: name,
        avatar: avatar,
        bio: bio,
        role: role,
        experienceLevel: experienceLevel,
        schedule: schedule,
        commitment: commitment,
        communication: communication,
        interests: interests,
        superpowers: superpowers,
        skills: skills,
        email: email,
        profileComplete: profileComplete,
        crewId: crewId,
        isAdmin: isAdmin,
        matchCount: matchCount ?? this.matchCount,
        score: score,
        tags: tags,
        inCrew: inCrew ?? this.inCrew,
        emailVerified: emailVerified,
        headline: headline ?? this.headline,
        cover: cover ?? this.cover,
        coverUrl: coverUrl,
        accent: accent ?? this.accent,
        cardFields: cardFields ?? this.cardFields,
        handle: handle,
        crewName: crewName,
        relation: relation ?? this.relation,
        requestId: requestId,
        clubs: clubs,
        clubIds: clubIds,
        isLead: isLead,
        breakdown: breakdown,
        record: record,
        demo: demo,
      );
}

/// The parts of a fit score: skills out of 50, style out of 30, interests out of 20, plus a club bonus.
class FitBreakdown {
  const FitBreakdown({required this.skills, required this.style, required this.interests, this.clubs = 0});

  final int skills;
  final int style;
  final int interests;
  final int clubs;

  static FitBreakdown? from(Object? json) => json is Map<String, dynamic>
      ? FitBreakdown(
          skills: intOr(json['skills']),
          style: intOr(json['style']),
          interests: intOr(json['interests']),
          clubs: intOr(json['clubs']),
        )
      : null;
}

/// Events, challenges and points their crew has completed, and the latest one.
class HackRecord {
  const HackRecord({this.events = 0, this.challenges = 0, this.points = 0, this.lastTitle, this.lastAt});

  final int events;
  final int challenges;
  final int points;
  final String? lastTitle;
  final DateTime? lastAt;

  bool get isEmpty => events == 0 && challenges == 0;

  static HackRecord? from(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final last = json['last'];
    return HackRecord(
      events: intOr(json['events']),
      challenges: intOr(json['challenges']),
      points: intOr(json['points']),
      lastTitle: last is Map<String, dynamic> ? last['title'] as String? : null,
      lastAt: last is Map<String, dynamic> ? dateOrNull(last['at']) : null,
    );
  }
}
