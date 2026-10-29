import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'palette.dart';

/// The app's little line drawings, ported from the mockups' inline SVGs.
enum Glyph { discover, matches, crew, events, ranks, logo, close, cross, check, heart }

/// Draws a [Glyph] in a square of [size].
///
/// [color] is the line colour; [fill] overrides the fill of single-colour
/// glyphs (the heart).
class GlyphIcon extends StatelessWidget {
  const GlyphIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color = Palette.ink,
    this.fill,
  });

  final Glyph glyph;
  final double size;
  final Color color;
  final Color? fill;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _GlyphPainter(glyph, color, fill)),
        ),
      );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color, this.fill);

  final Glyph glyph;
  final Color color;
  final Color? fill;

  /// The SVG viewBox and stroke width each glyph was drawn with.
  (double, double) get _grid => switch (glyph) {
        Glyph.logo => (32, 2.6),
        Glyph.close => (14, 1.8),
        Glyph.cross || Glyph.check => (14, 2.2),
        Glyph.heart => (24, 1.6),
        _ => (36, 2.2),
      };

  @override
  void paint(Canvas canvas, Size size) {
    final (viewBox, width) = _grid;
    canvas.scale(size.width / viewBox);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    void shape(Path path, Color fill) {
      canvas
        ..drawPath(path, Paint()..color = fill)
        ..drawPath(path, stroke);
    }

    switch (glyph) {
      case Glyph.discover:
        canvas
          ..save()
          ..translate(20, 17)
          ..rotate(8 * math.pi / 180)
          ..translate(-20, -17);
        shape(_rect(10, 4, 20, 26), Palette.desktop);
        canvas.restore();
        shape(_rect(6, 6, 20, 26), Palette.window);
        shape(_circle(16, 15, 4), Palette.blue);
        canvas.drawPath(
          Path()
            ..moveTo(10, 27)
            ..cubicTo(11, 24, 13.5, 22.5, 16, 22.5)
            ..cubicTo(18.5, 22.5, 21, 24, 22, 27),
          stroke,
        );
      case Glyph.matches:
        shape(_bigHeart(), Palette.pink);
      case Glyph.crew:
        shape(_circle(12, 12, 5), Palette.blue);
        shape(_circle(24, 12, 5), Palette.desktop);
        shape(_shoulders(3), Palette.blue);
        shape(_shoulders(15), Palette.desktop);
      case Glyph.events:
        shape(_rect(4, 8, 28, 24), Palette.window);
        shape(
          Path()
            ..addRRect(RRect.fromRectAndCorners(
              const Rect.fromLTWH(4, 8, 28, 7),
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3),
            )),
          Palette.pink,
        );
        canvas
          ..drawLine(const Offset(11, 5), const Offset(11, 11), stroke)
          ..drawLine(const Offset(25, 5), const Offset(25, 11), stroke);
        shape(Path()..addRect(const Rect.fromLTWH(9, 19, 8, 8)), Palette.blue);
        canvas
          ..drawLine(const Offset(21, 21), const Offset(27, 21), stroke)
          ..drawLine(const Offset(21, 26), const Offset(25, 26), stroke);
      case Glyph.ranks:
        shape(Path()..addRect(const Rect.fromLTRB(13, 13, 23, 32)), Palette.pink);
        shape(Path()..addRect(const Rect.fromLTRB(3, 20, 13, 32)), Palette.blue);
        shape(Path()..addRect(const Rect.fromLTRB(23, 24, 33, 32)), Palette.window);
        shape(_star(18, 6.5, 4.6, 2), Palette.window);
      case Glyph.logo:
        canvas
          ..drawCircle(const Offset(11, 11), 4, stroke)
          ..drawCircle(const Offset(21, 11), 4, stroke)
          ..drawPath(
            Path()
              ..moveTo(4, 26)
              ..cubicTo(5.2, 21, 8, 18.5, 11, 18.5)
              ..cubicTo(14, 18.5, 16.8, 21, 18, 26)
              ..moveTo(14, 26)
              ..cubicTo(15.2, 21, 18, 18.5, 21, 18.5)
              ..cubicTo(24, 18.5, 26.8, 21, 28, 26),
            stroke,
          );
      case Glyph.close || Glyph.cross:
        canvas
          ..drawLine(const Offset(2, 2), const Offset(12, 12), stroke)
          ..drawLine(const Offset(12, 2), const Offset(2, 12), stroke);
      case Glyph.check:
        canvas.drawPath(
          Path()
            ..moveTo(2, 7.5)
            ..lineTo(5.5, 11)
            ..lineTo(12, 3),
          stroke,
        );
      case Glyph.heart:
        final heart = _smallHeart();
        canvas.drawPath(heart, Paint()..color = fill ?? color);
        if (fill != null) canvas.drawPath(heart, stroke);
    }
  }

  static Path _rect(double x, double y, double w, double h) => Path()
    ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(3)));

  static Path _circle(double x, double y, double r) =>
      Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

  static Path _shoulders(double x) => Path()
    ..moveTo(x, 31)
    ..cubicTo(x + 1.5, 25, x + 5, 22, x + 9, 22)
    ..cubicTo(x + 13, 22, x + 16.5, 25, x + 18, 31)
    ..close();

  static Path _star(double cx, double cy, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final (x, y) = (cx + r * math.cos(a), cy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  static Path _bigHeart() => Path()
    ..moveTo(18, 31)
    ..cubicTo(18, 31, 6, 23.6, 3, 16.2)
    ..cubicTo(1, 11, 4.4, 5.5, 9.6, 5.5)
    ..cubicTo(12.8, 5.5, 15.1, 7.3, 16.2, 9.4)
    ..lineTo(18, 12)
    ..lineTo(19.8, 9.4)
    ..cubicTo(20.9, 7.3, 23.2, 5.5, 26.4, 5.5)
    ..cubicTo(31.6, 5.5, 35, 11, 33, 16.2)
    ..cubicTo(30, 23.6, 18, 31, 18, 31)
    ..close();

  static Path _smallHeart() => Path()
    ..moveTo(12, 21)
    ..cubicTo(12, 21, 4.5, 16.4, 2.5, 11.7)
    ..cubicTo(1.2, 8.4, 3.3, 5, 6.6, 5)
    ..cubicTo(8.6, 5, 10, 6.1, 10.7, 7.4)
    ..lineTo(12, 9.3)
    ..lineTo(13.3, 7.4)
    ..cubicTo(14, 6.1, 15.4, 5, 17.4, 5)
    ..cubicTo(20.7, 5, 22.8, 8.4, 21.5, 11.7)
    ..cubicTo(19.5, 16.4, 12, 21, 12, 21)
    ..close();

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.fill != fill;
}
