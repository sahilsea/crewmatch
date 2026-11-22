/// Base URL of the CrewMatch API, including the `/api` prefix.
///
/// Set it at build time, for example on the Android emulator:
/// `flutter run --dart-define=API_URL=http://10.0.2.2:5050/api`
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:5050/api',
);

/// Where the web app lives. Profile links and QR codes point here, e.g.
/// `https://crewmatch.netlify.app/u/tara-fernandes`. In the browser it's just
/// the page's own address.
const webUrl = String.fromEnvironment('WEB_URL', defaultValue: 'https://crewmatch.netlify.app');
