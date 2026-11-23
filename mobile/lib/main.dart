import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'api/api_client.dart';
import 'api/crewmatch_api.dart';
import 'app.dart';
import 'config.dart';
import 'state/appearance.dart';
import 'state/session.dart';
import 'state/token_store.dart';
import 'state/update_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Phones stay upright. (No effect on the website.)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Appearance.instance.load();
  final session = Session(
    api: CrewMatchApi(ApiClient(baseUrl: apiUrl)),
    tokens: PrefsTokenStore(),
  );
  runApp(CrewMatchApp(session: session));
  // Android: check for new versions in the background, even when the app is closed.
  UpdateNotifier.start();
}
