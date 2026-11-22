import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'palette.dart';

/// Colour schemes for the logo.
enum MarkStyle {
  /// Crimson, gold and navy on a light background.
  brand,

  /// For dark backgrounds: the navy tile turns cream and the outline gold.
  night,

  /// One colour: dark ink, for print.
  ink,

  /// One colour: cream, on crimson.
  cream,
}

/// The CrewMatch logo, "Crew of four": three teammates on filled tiles and a
/// fourth, outlined and tilted, snapping into place.
///
/// Drawn on a 100 × 100 grid, the same as the design sheet. [style] defaults to
/// [MarkStyle.brand] in the light theme and [MarkStyle.night] in the dark one.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.style});

  final double size;
  final MarkStyle? style;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'CrewMatch',
        image: true,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: BrandMarkPainter(style ?? (Palette.isDark ? MarkStyle.night : MarkStyle.brand))),
        ),
      );
}

/// Paints the logo into any square. Also used to render the app icons.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter(this.style);

  final MarkStyle style;

  /// Tile and person colours: top left, top right, bottom left, then the
  /// fourth teammate's outline and figure.
  static const _schemes = {
    MarkStyle.brand: [Color(0xFF7A1C1C), Color(0xFFF7EEDC), Color(0xFFE8C25E), Color(0xFF3A2900), Color(0xFF22305A), Color(0xFFF3E9D2), Color(0xFF7A1C1C), Color(0xFF7A1C1C)],
    MarkStyle.night: [Color(0xFFA8312E), Color(0xFFFFF1DA), Color(0xFFE8C25E), Color(0xFF2A1D00), Color(0xFFF3E9D2), Color(0xFF22305A), Color(0xFFE8C25E), Color(0xFFE8C25E)],
    MarkStyle.ink: [Color(0xFF2A1A12), Color(0xFFF7EEDC), Color(0xFF2A1A12), Color(0xFFF7EEDC), Color(0xFF2A1A12), Color(0xFFF7EEDC), Color(0xFF2A1A12), Color(0xFF2A1A12)],
    MarkStyle.cream: [Color(0xFFFFF6E0), Color(0xFF7A1C1C), Color(0xFFFFF6E0), Color(0xFF7A1C1C), Color(0xFFFFF6E0), Color(0xFF7A1C1C), Color(0xFFFFF6E0), Color(0xFFFFF6E0)],
  };

  static void _person(Canvas canvas, double x, double y, Color color) {
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(x + 22, y + 17), 7, paint);
    canvas.drawPath(
      Path()
        ..moveTo(x + 9, y + 38)
        ..cubicTo(x + 11, y + 26, x + 33, y + 26, x + 35, y + 38)
        ..close(),
      paint,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = _schemes[style]!;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    for (final (i, (x, y)) in [(2.0, 2.0), (52.0, 2.0), (2.0, 52.0)].indexed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 44, 44), const Radius.circular(11)),
        Paint()..color = c[i * 2],
      );
      _person(canvas, x, y, c[i * 2 + 1]);
    }
    // The fourth teammate, tilted 12°, snapping into place.
    canvas.translate(76, 76);
    canvas.rotate(12 * math.pi / 180);
    canvas.translate(-76, -76);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(56, 56, 40, 40), const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = c[6],
    );
    _person(canvas, 54, 53, c[7]);
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) => old.style != style;
}
