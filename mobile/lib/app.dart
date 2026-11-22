import 'package:material_ui/material_ui.dart';

import 'screens/admin/admin_shell.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/shell/home_shell.dart';
import 'state/appearance.dart';
import 'state/session.dart';
import 'ui/ui.dart';
import 'ui/theme.dart';

class CrewMatchApp extends StatefulWidget {
  const CrewMatchApp({super.key, required this.session});

  final Session session;

  @override
  State<CrewMatchApp> createState() => _CrewMatchAppState();
}

class _CrewMatchAppState extends State<CrewMatchApp> with WidgetsBindingObserver {
  var _navigator = GlobalKey<NavigatorState>();

  /// Bumped when the theme flips. The whole app is rebuilt under a new key
  /// so every colour is read again (see [Tone]); the open tab is kept.
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Appearance.instance.addListener(_onAppearanceChanged);
    Palette.isDark = _wantsDark();
    widget.session
      ..addListener(_onSessionChanged)
      ..restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Appearance.instance.removeListener(_onAppearanceChanged);
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  bool _wantsDark() => switch (Appearance.instance.value) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
      };

  void _onAppearanceChanged() {
    final dark = _wantsDark();
    if (dark == Palette.isDark) return;
    setState(() {
      Palette.isDark = dark;
      _generation++;
      _navigator = GlobalKey<NavigatorState>();
    });
  }

  @override
  void didChangePlatformBrightness() => _onAppearanceChanged();

  /// Signed out (or the token expired) on a pushed screen: back to the root,
  /// where [_RootGate] now shows sign-in.
  void _onSessionChanged() {
    if (widget.session.user == null) {
      _navigator.currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) => SessionScope(
        session: widget.session,
        child: MaterialApp(
          key: ValueKey(_generation),
          title: 'CrewMatch',
          navigatorKey: _navigator,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          scrollBehavior: const AppScrollBehavior(),
          // Screens adapt to the window themselves (see WindowSize).
          builder: (context, child) => ColoredBox(color: Palette.desktop, child: child),
          home: const _RootGate(),
        ),
      );
}

/// Picks the first screen from the session: sign in, finish your profile, or the app.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.watch(context);
    final user = session.user;
    if (session.restoring) return const Scaffold(body: LoadingView(message: 'Starting up…'));
    if (user == null) return const SignInScreen();
    if (user.isAdmin) return const AdminShell();
    if (!user.emailVerified) return const VerifyEmailScreen();
    if (!user.profileComplete) return const ProfileScreen(firstTime: true);
    return const HomeShell();
  }
}
