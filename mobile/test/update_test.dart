import 'dart:convert';

import 'package:crewmatch/screens/shell/update_dialog.dart';
import 'package:crewmatch/state/app_update.dart';
import 'package:crewmatch/ui/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('version comparison', () {
    expect(UpdateChecker.isNewer('1.1.0', '1.0.0'), isTrue);
    expect(UpdateChecker.isNewer('1.10.0', '1.9.2'), isTrue);
    expect(UpdateChecker.isNewer('2.0.0', '1.99.99'), isTrue);
    expect(UpdateChecker.isNewer('1.0.0', '1.0.0'), isFalse);
    expect(UpdateChecker.isNewer('1.0.0', '1.1.0'), isFalse);
    expect(UpdateChecker.isNewer('1.1', '1.0.9'), isTrue);
    expect(UpdateChecker.isNewer('1.1.0+5', '1.1.0'), isFalse);
  });

  http.Client github(String tag, {bool apk = true}) => MockClient((req) async {
        expect(req.url.toString(), 'https://api.github.com/repos/sahilsea/crewmatch/releases/latest');
        return http.Response(
          jsonEncode({
            'tag_name': tag,
            'body': 'Easier skills entry',
            'assets': [
              if (apk) {'name': 'CrewMatch.apk', 'browser_download_url': 'https://example.test/CrewMatch.apk'},
            ],
          }),
          200,
        );
      });

  test('a newer release is offered with its APK and notes', () async {
    final update = await UpdateChecker.check(client: github('v1.1.0'), currentVersion: '1.0.0');
    expect(update, isNotNull);
    expect(update!.version, '1.1.0');
    expect(update.current, '1.0.0');
    expect(update.url, 'https://example.test/CrewMatch.apk');
    expect(update.notes, 'Easier skills entry');
  });

  test('nothing when up to date, without an APK, or offline', () async {
    expect(await UpdateChecker.check(client: github('v1.1.0'), currentVersion: '1.1.0'), isNull);
    expect(await UpdateChecker.check(client: github('v1.2.0', apk: false), currentVersion: '1.1.0'), isNull);
    final offline = MockClient((_) async => throw Exception('offline'));
    expect(await UpdateChecker.check(client: offline, currentVersion: '1.0.0'), isNull);
  });

  testWidgets('the update dialog shows both versions and the notes on a phone', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 1920)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showUpdateDialog(
                context,
                const AppUpdate(version: '1.1.0', current: '1.0.0', url: 'https://example.test/a.apk', notes: 'Easier skills entry'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('New version available'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.text('v1.1.0'), findsOneWidget);
    expect(find.text('Easier skills entry'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('New version available'), findsNothing);
  });
}
