import '../models/auth_result.dart';
import '../models/crew.dart';
import '../models/deck.dart';
import '../models/admin_stats.dart';
import '../models/hub_event.dart';
import '../models/json.dart';
import '../models/leaderboard.dart';
import '../models/post.dart';
import '../models/team_request.dart';
import '../models/profile_options.dart';
import '../models/user.dart';
import 'api_client.dart';

/// Every endpoint the app uses, returning typed models.
/// The shapes are documented in server/README.md and docs/hackathon-api.md.
class CrewMatchApi {
  CrewMatchApi(this.client);

  final ApiClient client;

  // Auth and profile

  Future<AuthResult> login(String email, String password) async =>
      AuthResult.fromJson(
        await client.post('/auth/login', {'email': email, 'password': password}),
      );

  /// "Continue with Google" with the ID token Google gave the app.
  Future<AuthResult> googleSignIn(String idToken) async =>
      AuthResult.fromJson(await client.post('/auth/google', {'idToken': idToken}));

  Future<User> verifyEmail(String code) async => _user(await client.post('/auth/verify', {'code': code}));

  /// Sends a fresh code. Returns it when the server has no email set up.
  Future<String?> resendCode() async => (await client.post('/auth/resend'))['devCode'] as String?;

  Future<AuthResult> register(String name, String email, String password) async =>
      AuthResult.fromJson(
        await client.post(
          '/auth/register',
          {'name': name, 'email': email, 'password': password},
        ),
      );

  Future<User> me() async => _user(await client.get('/auth/me'));

  Future<ProfileOptions> options() async =>
      ProfileOptions.fromJson(await client.get('/options'));

  /// Partial update: send only the fields that changed or were filled in.
  Future<User> updateProfile(Map<String, Object?> changes) async =>
      _user(await client.put('/users/me', changes));

  /// [photo] is a `data:image/…;base64,` URL.
  Future<User> uploadAvatar(String photo) async =>
      _user(await client.post('/users/me/avatar', {'photo': photo}, const Duration(seconds: 60)));

  Future<User> removeAvatar() async => _user(await client.delete('/users/me/avatar'));

  /// Also switches the card's cover to the photo.
  Future<User> uploadCover(String photo) async =>
      _user(await client.post('/users/me/cover', {'photo': photo}, const Duration(seconds: 60)));

  Future<User> removeCover() async => _user(await client.delete('/users/me/cover'));

  Future<List<Post>> userPosts(String userId) async =>
      PostPage.fromJson(await client.get('/users/${Uri.encodeComponent(userId)}/posts')).posts;

  Future<List<ActivityItem>> activity(String userId) async => [
        for (final a in objectList((await client.get('/users/${Uri.encodeComponent(userId)}/activity'))['activity']))
          ActivityItem.fromJson(a),
      ];

  // Deck and matches

  Future<Deck> deck({int limit = 20}) async =>
      Deck.fromJson(await client.get('/deck?limit=$limit'));

  Future<SwipeResult> swipe(String targetId, SwipeDirection direction) async =>
      SwipeResult.fromJson(
        await client.post(
          '/swipe',
          {'targetId': targetId, 'direction': direction.name},
        ),
      );

  /// Brings back everyone you passed on.
  Future<void> resetPasses() async {
    await client.post('/swipe/reset');
  }

  Future<List<User>> matches() async =>
      User.listFrom((await client.get('/matches'))['matches']);

  Future<void> unmatch(String userId) async {
    await client.delete('/matches/$userId');
  }

  // Crew

  Future<Crew?> myCrew() async =>
      Crew.maybeFromJson((await client.get('/crews/mine'))['crew']);

  Future<Crew> createCrew(String name, List<String> memberIds) async =>
      _crew(await client.post('/crews', {'name': name, 'memberIds': memberIds}));

  Future<Crew> renameCrew(String name) async =>
      _crew(await client.patch('/crews/mine', {'name': name}));

  Future<Crew> addCrewMember(String userId) async =>
      _crew(await client.post('/crews/mine/members', {'userId': userId}));

  /// Takes someone else out of your crew. The API refuses the last other
  /// member (leave the crew instead).
  Future<Crew> removeCrewMember(String userId) async =>
      _crew(await client.delete('/crews/mine/members/${Uri.encodeComponent(userId)}'));

  /// A crew left with one person is dissolved.
  Future<void> leaveCrew() async {
    await client.delete('/crews/mine');
  }

  // Finding people: search, profile links and team-up requests

  Future<List<User>> searchPeople({String query = '', bool noCrew = false, String? role}) async {
    final params = {if (query.trim().isNotEmpty) 'q': query.trim(), if (noCrew) 'free': '1', 'role': ?role};
    final path = params.isEmpty ? '/users/search' : '/users/search?${Uri(queryParameters: params).query}';
    return User.listFrom((await client.get(path))['results']);
  }

  /// Someone's profile from their link handle. [isMe] when it's your own.
  Future<({User user, bool isMe})> personByHandle(String handle) async {
    final json = await client.get('/users/handle/${Uri.encodeComponent(handle)}');
    return (user: User.fromJson(json['user'] as Map<String, dynamic>), isMe: json['isMe'] == true);
  }

  /// What anyone sees from a profile link, signed in or not.
  Future<User> publicProfile(String handle) async {
    final json = (await client.get('/public/u/${Uri.encodeComponent(handle)}'))['user'] as Map<String, dynamic>;
    return User.fromJson({'id': json['handle'], ...json});
  }

  Future<SendResult> sendRequest(String userId, {String note = '', RequestSource source = RequestSource.profile}) async {
    final json = await client.post('/requests', {'to': userId, if (note.trim().isNotEmpty) 'note': note.trim(), 'source': source.name});
    final user = json['user'];
    return (match: json['match'] == true, user: user is Map<String, dynamic> ? User.fromJson(user) : null);
  }

  Future<RequestLists> requests() async => RequestLists.fromJson(await client.get('/requests'));

  /// Accepting matches you; returns the new match.
  Future<User> acceptRequest(String id) async =>
      User.fromJson((await client.post('/requests/$id/accept'))['user'] as Map<String, dynamic>);

  Future<void> declineRequest(String id) async {
    await client.post('/requests/$id/decline');
  }

  Future<void> withdrawRequest(String id) async {
    await client.delete('/requests/$id');
  }

  // Hackathon hub

  Future<List<HubEvent>> events({EventKind? kind}) async => HubEvent.listFrom(
        (await client.get(kind == null ? '/events' : '/events?kind=${kind.name}'))['events'],
      );

  Future<HubEvent> joinEvent(String id) async =>
      _event(await client.post('/events/$id/join'));

  Future<HubEvent> leaveEvent(String id) async =>
      _event(await client.delete('/events/$id/join'));

  Future<CheckInResult> checkIn(String id, String code) async =>
      CheckInResult.fromJson(
        await client.post('/events/$id/checkin', {'code': code}),
      );

  Future<HubEvent> submitChallenge(String id, {required String url, String? note}) async =>
      _event(
        await client.post('/events/$id/submit', {
          'url': url,
          if (note != null && note.isNotEmpty) 'note': note,
        }),
      );

  /// Hosts a student event. `askPoints > 0` sends it to organisers for review.
  Future<HubEvent> hostEvent(Map<String, Object?> fields) async => _event(await client.post('/events', fields));

  Future<void> cancelHostedEvent(String id) async {
    await client.delete('/events/$id');
  }

  // Organisers

  Future<AdminStats> adminStats() async => AdminStats.fromJson(await client.get('/admin/stats'));

  Future<List<HubEvent>> adminEvents() async => HubEvent.listFrom((await client.get('/admin/events'))['events']);

  Future<HubEvent> createEvent(Map<String, Object?> fields) async => _event(await client.post('/admin/events', fields));

  Future<HubEvent> updateEvent(String id, Map<String, Object?> fields) async =>
      _event(await client.patch('/admin/events/$id', fields));

  Future<void> deleteEvent(String id) async {
    await client.delete('/admin/events/$id');
  }

  /// Approves a student's event; it starts awarding [points].
  Future<HubEvent> makeOfficial(String id, {int? points}) async =>
      _event(await client.post('/admin/events/$id/official', {'points': ?points}));

  /// Keeps a student's event up, without points.
  Future<HubEvent> keepCommunity(String id) async => _event(await client.post('/admin/events/$id/community'));

  Future<HubEvent> approveEntry(String eventId, String crewId, {int? points}) async =>
      _event(await client.post('/admin/events/$eventId/entries/$crewId/approve', {'points': ?points}));

  Future<HubEvent> rejectEntry(String eventId, String crewId, {String? note}) async => _event(
        await client.post('/admin/events/$eventId/entries/$crewId/reject', {if (note != null && note.isNotEmpty) 'note': note}),
      );

  /// The live leaderboard, or another hackathon's with [hackathonId].
  Future<Leaderboard> leaderboard([String? hackathonId]) async => Leaderboard.fromJson(
        await client.get(
          hackathonId == null || hackathonId == Hackathon.currentId
              ? '/leaderboard'
              : '/hackathons/${Uri.encodeComponent(hackathonId)}/leaderboard',
        ),
      );

  Future<HackathonList> hackathons() async =>
      HackathonList.fromJson(await client.get('/hackathons'));

  // Hackathon feed

  /// Newest first; pass the oldest post's time as [before] for the next page.
  Future<PostPage> posts({DateTime? before}) async => PostPage.fromJson(
        await client.get('/posts${before == null ? '' : '?before=${Uri.encodeQueryComponent(before.toUtc().toIso8601String())}'}'),
      );

  /// [photo] is a `data:image/…;base64,` URL.
  Future<Post> createPost(String text, {PostTag? tag, String? photo}) async => _post(
        await client.post('/posts', {
          'text': text,
          if (tag != null) 'tag': tag.name,
          'photo': ?photo,
        }),
      );

  Future<void> deletePost(String id) async {
    await client.delete('/posts/${Uri.encodeComponent(id)}');
  }

  Future<Post> toggleLike(String id) async => _post(await client.post('/posts/${Uri.encodeComponent(id)}/like'));

  Future<List<PostComment>> comments(String postId) async => [
        for (final c in objectList((await client.get('/posts/${Uri.encodeComponent(postId)}/comments'))['comments']))
          PostComment.fromJson(c),
      ];

  Future<Post> addComment(String postId, String text) async =>
      _post(await client.post('/posts/${Uri.encodeComponent(postId)}/comments', {'text': text}));

  /// A photo path from a post as a full URL.
  String photoUrl(String path) => client.resolve(path);

  // Crew chat

  /// The latest messages, oldest first; with [after], only newer ones.
  Future<List<ChatMessage>> messages({DateTime? after}) async => [
        for (final m in objectList((await client.get(
          '/crews/mine/messages${after == null ? '' : '?after=${Uri.encodeQueryComponent(after.toUtc().toIso8601String())}'}',
        ))['messages']))
          ChatMessage.fromJson(m),
      ];

  /// Text, and optionally a photo or a file as `data:` URLs.
  Future<ChatMessage> sendMessage(String text, {String? photo, ({String name, String data})? file}) async =>
      ChatMessage.fromJson((await client.post(
        '/crews/mine/messages',
        {
          'text': text,
          'photo': ?photo,
          if (file != null) 'file': {'name': file.name, 'data': file.data},
        },
        const Duration(seconds: 90),
      ))['message'] as Map<String, dynamic>);

  /// A document from the crew chat, downloaded with your sign-in.
  Future<List<int>> downloadFile(String url) => client.getBytes(url);

  static Post _post(Map<String, dynamic> json) => Post.fromJson(json['post'] as Map<String, dynamic>);

  static User _user(Map<String, dynamic> json) =>
      User.fromJson(json['user'] as Map<String, dynamic>);

  static Crew _crew(Map<String, dynamic> json) =>
      Crew.fromJson(json['crew'] as Map<String, dynamic>);

  static HubEvent _event(Map<String, dynamic> json) =>
      HubEvent.fromJson(json['event'] as Map<String, dynamic>);
}
