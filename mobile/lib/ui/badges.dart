import 'package:material_ui/material_ui.dart';

import 'glyphs.dart';
import 'motion.dart';
import 'palette.dart';
import 'type.dart';

/// A small bordered tag, e.g. a reason on a swipe card.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = Palette.desktop});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color == Palette.desktop ? Palette.gold : color,
      borderRadius: Frame.tagRadius,
    ),
    child: Text(
      text,
      style: AppType.body(
        size: 13,
        weight: FontWeight.w500,
        height: 1.3,
        color: color == Palette.desktop ? Palette.onGold : Palette.ink,
      ),
    ),
  );
}

/// A crimson pill with a count, next to a screen title.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) => PopIn(
        child: Container(
          constraints: const BoxConstraints(minWidth: 24),
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Palette.crimson, borderRadius: Frame.pill),
          child: Text('$count', style: AppType.body(size: 13, weight: FontWeight.w700, height: 1, color: Palette.onCrimson)),
        ),
      );
}

/// Small marker: "YOU", "FULL", "LIVE".
class InkBadge extends StatelessWidget {
  const InkBadge(
    this.text, {
    super.key,
    this.inverted = false,
    this.round = false,
  });

  final String text;

  /// Cream with ink text, for dark backgrounds.
  final bool inverted;

  /// Pill-shaped, like the LIVE indicator.
  final bool round;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: inverted
          ? Palette.cream
          : (round ? Palette.crimson : Palette.navy),
      borderRadius: Frame.tagRadius,
    ),
    child: Label(text, size: 15, color: inverted ? Palette.ink : Palette.cream),
  );
}

/// The crimson "LIVE" tag, with a gently pulsing dot.
class LivePill extends StatelessWidget {
  const LivePill({super.key, this.inverted = false});

  final bool inverted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: inverted ? Palette.cream : Palette.crimson,
      borderRadius: Frame.tagRadius,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Pulse(
          child: SizedBox.square(
            dimension: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.gold,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Label(
          'Live',
          size: 15,
          color: inverted ? Palette.ink : Palette.onCrimson,
        ),
      ],
    ),
  );
}

/// "92% fit" on a crimson tag.
class FitBadge extends StatelessWidget {
  const FitBadge(this.score, {super.key, this.size = 20});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: const BoxDecoration(
      color: Palette.crimson,
      borderRadius: Frame.chipRadius,
    ),
    child: Text(
      '$score% fit',
      style: AppType.body(
        size: size * 0.7,
        weight: FontWeight.w700,
        color: Palette.onCrimson,
      ),
    ),
  );
}

/// A thin rounded bar that fills in when it appears, for capacity and progress.
class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({
    super.key,
    required this.value,
    this.color = Palette.crimson,
  });

  /// 0 to 1.
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 6,
    decoration: const BoxDecoration(
      color: Palette.strip,
      borderRadius: BorderRadius.all(Radius.circular(3)),
    ),
    clipBehavior: Clip.antiAlias,
    alignment: Alignment.centerLeft,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: Motion.of(context, const Duration(milliseconds: 800)),
      curve: Motion.ease,
      builder: (context, v, _) => FractionallySizedBox(
        widthFactor: v,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
        ),
      ),
    ),
  );
}

/// A small tick box: gold with a tick when covered, light with a cross when not.
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
      color: checked ? Palette.gold : Palette.field,
      border: checked ? null : Border.all(color: Palette.dashed),
      borderRadius: Frame.tagRadius,
    ),
    child: GlyphIcon(checked ? Glyph.check : Glyph.cross, size: size * 0.5),
  );
}

/// Marks sample people and clubs from the demo data, so nobody mistakes them for real.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Sample from the demo data, not a real student',
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 1 : 2),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            border: Border.all(color: Palette.dashed),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 3,
            children: [
              Icon(Icons.science_outlined, size: small ? 11 : 13, color: Palette.muted),
              Text('Demo', style: AppType.body(size: small ? 10.5 : 12, weight: FontWeight.w500, color: Palette.muted)),
            ],
          ),
        ),
      );
}
