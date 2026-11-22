import 'package:material_ui/material_ui.dart';

import '../../ui/ui.dart';

/// The top of the sign-in screen: three faces that pop in and float, and a
/// one-line pitch.
class WelcomeWindow extends StatelessWidget {
  const WelcomeWindow({super.key, this.registering = false, this.onDark = false});

  /// Swaps the headline for the create-account one.
  final bool registering;

  /// On the wide sign-in's coloured panel: bigger, cream headline.
  final bool onDark;

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
              style: AppType.title(size: onDark ? 48 : 28, color: onDark ? const Color(0xFFF3E9D2) : Palette.ink).copyWith(height: 1.08),
            ),
          ),
        ),
      ],
    );
  }
}

/// The left half of the wide sign-in: logo, the three faces, a big headline
/// and what the app does, on the navy-to-crimson panel.
class WideWelcome extends StatelessWidget {
  const WideWelcome({super.key, this.registering = false});

  final bool registering;

  static const _cream = Color(0xFFF3E9D2);

  @override
  Widget build(BuildContext context) {
    Widget face(String name, double size, Color background, int i) => PopIn(
          delay: Duration(milliseconds: 120 * i),
          child: Bob(
            delay: Duration(milliseconds: 600 * i),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Color(0x26FFFFFF), shape: BoxShape.circle),
              child: Avatar(url: WelcomeWindow._face(name), name: name, size: size, background: background),
            ),
          ),
        );
    Widget chip(IconData icon, String label) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(color: Color(0x1FFFFFFF), borderRadius: Frame.pill),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Icon(icon, size: 16, color: _cream),
              Text(label, style: AppType.body(size: 14, color: _cream)),
            ],
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 28,
      children: [
        Row(
          spacing: 12,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: _cream, borderRadius: Frame.buttonRadius),
              child: const Center(child: BrandMark(size: 32, style: MarkStyle.brand)),
            ),
            Text('CrewMatch', style: AppType.title(size: 24, color: _cream)),
          ],
        ),
        SizedBox(
          height: 132,
          child: Row(
            children: [
              face('Tara Fernandes', 104, const Color(0xFFF2DDB1), 0),
              Transform.translate(offset: const Offset(-20, 0), child: face('Aarav Sharma', 124, const Color(0xFFE8C25E), 1)),
              Transform.translate(offset: const Offset(-40, 0), child: face('Aisha Siddiqui', 104, _cream, 2)),
            ],
          ),
        ),
        Rise(
          delay: const Duration(milliseconds: 150),
          child: Text(
            'Find your missing teammates',
            style: AppType.title(size: 52, color: _cream).copyWith(height: 1.05),
          ),
        ),
        Rise(
          delay: const Duration(milliseconds: 250),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              chip(Icons.bolt_rounded, 'Ranked by fit'),
              chip(Icons.groups_outlined, 'Form a crew'),
              chip(Icons.emoji_events_outlined, 'Climb the board'),
            ],
          ),
        ),
      ],
    );
  }
}
