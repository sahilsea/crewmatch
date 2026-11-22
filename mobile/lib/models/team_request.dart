import 'json.dart';
import 'user.dart';

/// How someone found you, shown on their request.
enum RequestSource { discover, search, profile, link, qr }

extension RequestSourceLabel on RequestSource {
  String get label => switch (this) {
        RequestSource.discover => 'Discover',
        RequestSource.search => 'Search',
        RequestSource.profile => 'Profile',
        RequestSource.link => 'Link',
        RequestSource.qr => 'QR code',
      };
}

/// "Request to team up": accepting it makes a match.
class TeamRequest {
  const TeamRequest({required this.id, required this.user, this.note = '', this.source = RequestSource.profile, this.createdAt});

  factory TeamRequest.fromJson(Map<String, dynamic> json) => TeamRequest(
        id: json['id'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        note: json['note'] as String? ?? '',
        source: enumByName(RequestSource.values, json['source'], RequestSource.profile),
        createdAt: dateOrNull(json['createdAt']),
      );

  final String id;

  /// The other person: who sent it (incoming) or who it's to (sent).
  final User user;
  final String note;
  final RequestSource source;
  final DateTime? createdAt;
}

/// `GET /requests`: requests waiting for you, and the ones you've sent.
class RequestLists {
  const RequestLists({this.incoming = const [], this.sent = const []});

  factory RequestLists.fromJson(Map<String, dynamic> json) => RequestLists(
        incoming: [for (final r in objectList(json['incoming'])) TeamRequest.fromJson(r)],
        sent: [for (final r in objectList(json['sent'])) TeamRequest.fromJson(r)],
      );

  final List<TeamRequest> incoming;
  final List<TeamRequest> sent;
}

/// Sending a request either waits for them, or matches straight away when
/// they had already asked you.
typedef SendResult = ({bool match, User? user});
