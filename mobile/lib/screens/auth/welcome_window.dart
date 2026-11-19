import 'package:material_ui/material_ui.dart';

import '../../ui/ui.dart';

/// The top of the sign-in screen: three faces that pop in and float, and a
/// one-line pitch.
class WelcomeWindow extends StatelessWidget {
  const WelcomeWindow({super.key, this.registering = false});

  /// Swaps the headline for the create-account one.
  final bool registering;

  static String _face(String seed) =>
      'https://api.dicebear.com/9.x/notionists/png?seed=${Uri.encodeComponent(seed)}';

  @override
  Widget build(BuildContext context) {
    Widget face(String name, double size, Color background, int i) => PopIn(
          delay: Duration(milliseconds: 120 * i),
          child: Bob(
            delay: Duration(milliseconds: 600 * i),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Palette.desktop, shape: BoxShape.circle),
              child: Avatar(url: _face(name), name: name, size: size, background: background),
            ),
          ),
        );
    return Column(
      spacing: 20,
      children: [
        SizedBox(
          height: 104,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.translate(offset: const Offset(16, 0), child: face('Tara Fernandes', 72, Palette.pink, 0)),
              face('Aarav Sharma', 88, Palette.gold, 1),
              Transform.translate(offset: const Offset(-16, 0), child: face('Aisha Siddiqui', 72, Palette.navy, 2)),
            ],
          ),
        ),
        Rise(
          delay: const Duration(milliseconds: 150),
          child: AnimatedSwitcher(
            duration: Motion.of(context, const Duration(milliseconds: 250)),
            child: Text(
              registering ? 'Create account' : 'Find your missing teammates',
              key: ValueKey(registering),
              textAlign: TextAlign.center,
              style: AppType.title(size: 28).copyWith(height: 1.08),
            ),
          ),
        ),
      ],
    );
  }
}
