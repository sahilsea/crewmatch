import '../models/auth_result.dart';
import '../models/crew.dart';
import '../models/deck.dart';
import '../models/hub_event.dart';
import '../models/leaderboard.dart';
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

  /// A crew left with one person is dissolved.
  Future<void> leaveCrew() async {
    await client.delete('/crews/mine');
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

  Future<Leaderboard> leaderboard() async =>
      Leaderboard.fromJson(await client.get('/leaderboard'));

  static User _user(Map<String, dynamic> json) =>
      User.fromJson(json['user'] as Map<String, dynamic>);

  static Crew _crew(Map<String, dynamic> json) =>
      Crew.fromJson(json['crew'] as Map<String, dynamic>);

  static HubEvent _event(Map<String, dynamic> json) =>
      HubEvent.fromJson(json['event'] as Map<String, dynamic>);
}
