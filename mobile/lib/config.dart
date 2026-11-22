/// Base URL of the CrewMatch API, including the `/api` prefix.
///
/// Set it at build time, for example on the Android emulator:
/// `flutter run --dart-define=API_URL=http://10.0.2.2:5050/api`
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:5050/api',
);
