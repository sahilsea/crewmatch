import 'package:flutter/widgets.dart';

import 'palette.dart';

/// A horizontal dashed rule, like the dividers on a profile card.
class DashedLine extends StatelessWidget {
  const DashedLine({super.key, this.color = Palette.dashed});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: Frame.line,
        width: double.infinity,
        child: CustomPaint(painter: _DashPainter(color: color)),
      );
}

/// Draws a dashed rounded rectangle on top of [child].
class DashedBorder extends StatelessWidget {
  const DashedBorder({super.key, required this.child, this.radius = 6, this.color = Palette.ink});

  final Widget child;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: _DashPainter(color: color, radius: radius, outline: true),
        child: child,
      );
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color, this.radius = 0, this.outline = false});

  static const _dash = 4.5;
  static const _gap = 3.0;

  final Color color;
  final double radius;
  final bool outline;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = Frame.line;
    const inset = Frame.line / 2;
    final path = outline
        ? (Path()
          ..addRRect(RRect.fromRectAndRadius(
            (Offset.zero & size).deflate(inset),
            Radius.circular(radius),
          )))
        : (Path()
          ..moveTo(0, inset)
          ..lineTo(size.width, inset));

    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.radius != radius || old.outline != outline;
}
