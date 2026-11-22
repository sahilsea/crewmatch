import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/user.dart';
import '../../ui/ui.dart';

/// "It's a match!" as a full screen. Resolves to true when the user wants to
/// go to their matches (where they add people to the crew).
Future<bool> showMatchDialog(BuildContext context, {required User me, required User them}) async {
  final seeMatches = await Navigator.of(context).push<bool>(
    PageRouteBuilder(
      fullscreenDialog: true,
      transitionDuration: Motion.of(context, const Duration(milliseconds: 300)),
      pageBuilder: (context, _, _) => _MatchScreen(me: me, them: them),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );
  return seeMatches ?? false;
}

class _MatchScreen extends StatelessWidget {
  const _MatchScreen({required this.me, required this.them});

  final User me;
  final User them;

  @override
  Widget build(BuildContext context) {
    final first = them.name.split(' ').first;
    final email = them.email;
    final page = SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(false),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.close_rounded, color: Palette.muted),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    spacing: 22,
                    children: [
                      _Pair(me: me, them: them),
                      Rise(
                        delay: const Duration(milliseconds: 550),
                        child: Column(
                          spacing: 8,
                          children: [
                            Text("It's a match!", textAlign: TextAlign.center, style: AppType.title(size: 30)),
                            Text(
                              'You both want to team up.',
                              textAlign: TextAlign.center,
                              style: AppType.body(size: 16, height: 1.5, color: Palette.muted),
                            ),
                          ],
                        ),
                      ),
                      Rise(
                        delay: const Duration(milliseconds: 850),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Add to crew'),
                            ),
                            if (email != null)
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: email));
                                  showNotice(context, "$first's email is copied. Say hi!");
                                },
                                child: const Text('Say hi'),
                              ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Keep swiping'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    // Wide windows: the celebration sits in a card on the brand gradient,
    // instead of a phone-width column lost in empty space.
    if (WindowSize.of(context).hasRail) {
      return Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF22305A), Color(0xFF7A1C1C)]),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: PopIn(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480, maxHeight: 590),
                  child: Material(
                    color: Palette.desktop,
                    elevation: 12,
                    shadowColor: const Color(0x66140C06),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
                    clipBehavior: Clip.antiAlias,
                    child: page,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(backgroundColor: Palette.desktop, body: page);
  }
}

/// Both avatars slide in from the sides, the crimson heart pops in under
/// them, and a few sparkles twinkle around.
class _Pair extends StatelessWidget {
  const _Pair({required this.me, required this.them});

  final User me;
  final User them;

  @override
  Widget build(BuildContext context) {
    Widget face(User user, Color background) => Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: Palette.desktop, shape: BoxShape.circle),
          child: Avatar(url: user.avatar, name: user.name, size: 108, background: background),
        );
    Widget spark(double size, Color color, {Duration delay = Duration.zero}) => PopIn(
          delay: delay,
          child: Pulse(minScale: 0.4, period: const Duration(milliseconds: 1100), child: Icon(Icons.auto_awesome, size: size, color: color)),
        );
    return SizedBox(
      width: 300,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: 6, left: 30, child: spark(18, Palette.gold)),
          Positioned(top: 30, right: 22, child: spark(12, Palette.crimson, delay: const Duration(milliseconds: 400))),
          Positioned(bottom: 16, left: 8, child: spark(14, Palette.gold, delay: const Duration(milliseconds: 800))),
          Positioned(bottom: 4, right: 40, child: spark(20, Palette.gold, delay: const Duration(milliseconds: 1200))),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SlideIn(fromLeft: true, child: face(me, Palette.gold)),
              Transform.translate(offset: const Offset(-36, 0), child: _SlideIn(fromLeft: false, child: face(them, Palette.pink))),
            ],
          ),
          Positioned(
            bottom: 14,
            child: PopIn(
              delay: const Duration(milliseconds: 350),
              child: Pulse(
                minScale: 0.9,
                period: const Duration(milliseconds: 800),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(color: Palette.crimson, shape: BoxShape.circle),
                  child: const Icon(Icons.favorite_rounded, size: 28, color: Palette.onCrimson),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideIn extends StatelessWidget {
  const _SlideIn({required this.fromLeft, required this.child});

  final bool fromLeft;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.of(context, const Duration(milliseconds: 600)),
        curve: Motion.ease,
        child: child,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset((fromLeft ? -60 : 60) * (1 - t), 0),
            child: Transform.rotate(angle: (fromLeft ? -0.14 : 0.14) * (1 - t), child: child),
          ),
        ),
      );
}
