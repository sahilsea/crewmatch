import 'package:shared_preferences/shared_preferences.dart';

/// When you last read your crew's chat, per crew, so the Crew tab can show
/// how many messages are new. Kept on the device.
abstract final class ChatRead {
  static String _key(String crewId) => 'crewmatch_chat_read_$crewId';

  static Future<DateTime?> lastRead(String crewId) async {
    try {
      final value = await SharedPreferencesAsync().getString(_key(crewId));
      return value == null ? null : DateTime.tryParse(value);
    } catch (_) {
      return null;
    }
  }

  static Future<void> markRead(String crewId, DateTime at) async {
    try {
      await SharedPreferencesAsync().setString(_key(crewId), at.toUtc().toIso8601String());
    } catch (_) {}
  }
}
