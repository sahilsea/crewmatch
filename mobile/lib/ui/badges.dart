import 'package:material_ui/material_ui.dart';

import 'glyphs.dart';
import 'palette.dart';
import 'type.dart';

/// A small bordered tag, e.g. a reason on a swipe card.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = Palette.desktop});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color, border: Frame.border),
        child: Text(text, style: AppType.body(size: 13.5, height: 1.3)),
      );
}

/// Black-on-cream marker: "YOU", "FULL", "LIVE".
class InkBadge extends StatelessWidget {
  const InkBadge(this.text, {super.key, this.inverted = false, this.round = false});

  final String text;

  /// Cream with ink text, for dark backgrounds.
  final bool inverted;

  /// Pill-shaped, like the LIVE indicator.
  final bool round;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: round ? 7 : 5),
        decoration: BoxDecoration(
          color: inverted ? Palette.cream : Palette.ink,
          borderRadius: BorderRadius.circular(round ? 9 : 0),
        ),
        child: Label(text, size: 15, color: inverted ? Palette.ink : Palette.cream),
      );
}

/// The small black "LIVE" pill.
class LivePill extends StatelessWidget {
  const LivePill({super.key, this.inverted = false});

  final bool inverted;

  @override
  Widget build(BuildContext context) => InkBadge('Live', inverted: inverted, round: true);
}

/// "92% FIT" in a cream box with an ink border.
class FitBadge extends StatelessWidget {
  const FitBadge(this.score, {super.key, this.size = 20});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: const BoxDecoration(color: Palette.window, border: Frame.border),
        child: Label('$score% fit', size: size, color: Palette.ink),
      );
}

/// A thin bar with an ink fill, for capacity and progress.
class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({super.key, required this.value, this.color = Palette.ink});

  /// 0 to 1.
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFFF6F3EE),
          border: Border.all(color: Palette.ink),
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          heightFactor: 1,
          child: ColoredBox(color: color),
        ),
      );
}

/// A square tick box: blue with a tick when covered, pink with a cross when not.
class TickBox extends StatelessWidget {
  const TickBox({super.key, required this.checked, this.size = 22});

  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: checked ? Palette.blue : Palette.pink,
          border: Frame.border,
        ),
        child: GlyphIcon(checked ? Glyph.check : Glyph.cross, size: size * 0.5),
      );
}
