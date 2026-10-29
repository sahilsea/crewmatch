import 'dart:ui' show PointMode;

import 'package:flutter/widgets.dart';

import 'palette.dart';

/// A flat fill with a halftone dot screen printed over it, like an old
/// photocopy. Used behind profile photos and in coloured header bands.
class Halftone extends StatelessWidget {
  const Halftone({super.key, required this.color, this.child, this.opacity = 0.28});

  final Color color;
  final Widget? child;

  /// Strength of the ink dots.
  final double opacity;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: color),
        child: CustomPaint(
          painter: HalftonePainter(color: Palette.ink.withValues(alpha: opacity)),
          child: child,
        ),
      );
}

/// Paints 1px dots on a 4px grid.
class HalftonePainter extends CustomPainter {
  const HalftonePainter({required this.color, this.spacing = 4, this.dotSize = 2});

  final Color color;
  final double spacing;
  final double dotSize;

  @override
  void paint(Canvas canvas, Size size) {
    final dots = <Offset>[
      for (var y = spacing / 2; y < size.height; y += spacing)
        for (var x = spacing / 2; x < size.width; x += spacing) Offset(x, y),
    ];
    canvas.drawPoints(
      PointMode.points,
      dots,
      Paint()
        ..color = color
        ..strokeWidth = dotSize
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(HalftonePainter old) =>
      old.color != color || old.spacing != spacing || old.dotSize != dotSize;
}
