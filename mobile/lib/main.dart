import 'package:material_ui/material_ui.dart';

import 'api/api_client.dart';
import 'api/crewmatch_api.dart';
import 'app.dart';
import 'config.dart';
import 'state/session.dart';
import 'state/token_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session(
    api: CrewMatchApi(ApiClient(baseUrl: apiUrl)),
    tokens: PrefsTokenStore(),
  );
  runApp(CrewMatchApp(session: session));
}
