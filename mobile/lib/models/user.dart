import 'json.dart';

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

  User copyWith({bool? inCrew, int? matchCount}) => User(
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
      );
}
