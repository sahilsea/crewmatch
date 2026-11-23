import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'app_update.dart';

const _task = 'crewmatch.checkForUpdate';

/// Runs in the background (a separate isolate started by Android's WorkManager),
/// even when the app is closed.
@pragma('vm:entry-point')
void updateCallbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      await UpdateNotifier.notifyIfNew();
    } catch (_) {
      // A failed check just waits for the next one.
    }
    return true;
  });
}

/// Android only: checks GitHub for a new version every few hours in the
/// background and posts a notification once per new version. Tapping it opens
/// the app, which shows the "New version available" dialog.
class UpdateNotifier {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _notifiedKey = 'update.notifiedVersion';
  static const _askedKey = 'update.askedPermission';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'updates',
      'App updates',
      channelDescription: 'When a new version of CrewMatch is out',
    ),
  );

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> _init() => _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );

  /// Schedules the background check. Safe to call on every launch: an existing
  /// schedule is kept as it is.
  static Future<void> start() async {
    if (!supported) return;
    try {
      await _init();
      await Workmanager().initialize(updateCallbackDispatcher);
      await Workmanager().registerPeriodicTask(
        _task,
        _task,
        frequency: const Duration(hours: 6),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {
      // Without background work the app still checks each time it opens.
    }
  }

  /// Android 13+ needs permission to show notifications. Asked once, after sign-in.
  static Future<void> askPermissionOnce() async {
    if (!supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) ?? false) return;
      await prefs.setBool(_askedKey, true);
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } catch (_) {
      // Not asked: the in-app dialog still works.
    }
  }

  /// Posts "CrewMatch X is available" if there's a newer version we haven't
  /// already announced.
  static Future<void> notifyIfNew() async {
    final update = await UpdateChecker.check();
    if (update == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_notifiedKey) == update.version) return;
    await _init();
    await _plugin.show(
      id: 1,
      title: 'CrewMatch ${update.version} is available',
      body: "Tap to see what's new and update.",
      notificationDetails: _details,
    );
    await prefs.setString(_notifiedKey, update.version);
  }
}
