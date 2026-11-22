// Renders the app icons from the same painter the app uses for its logo.
// Run from mobile/:  flutter test tool/render_icons_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crewmatch/ui/brand_mark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _cream = Color(0xFFF7EEDC);

/// A full square: the mark at [scale] of the size on [background] (or
/// transparent), with corners of [radius] × size.
Future<void> _render(String path, int size, {MarkStyle style = MarkStyle.brand, Color? background, double radius = 0, double scale = 0.66}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();
  if (background != null) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s, s), Radius.circular(s * radius)),
      Paint()
        ..color = background
        ..isAntiAlias = true,
    );
  }
  final mark = s * scale;
  canvas.translate((s - mark) / 2, (s - mark) / 2);
  BrandMarkPainter(style).paint(canvas, Size.square(mark));
  final image = await recorder.endRecording().toImage(size, size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('render app icons', (tester) async {
    await tester.runAsync(() async {
      const res = 'android/app/src/main/res';
      const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
      for (final MapEntry(key: d, value: k) in densities.entries) {
        // Older Android: a cream rounded square.
        await _render('$res/mipmap-$d/ic_launcher.png', (48 * k).round(), background: _cream, radius: 0.22);
        // Android 8+: adaptive icon layers, 108dp with a 66dp safe zone.
        await _render('$res/mipmap-$d/ic_launcher_foreground.png', (108 * k).round(), scale: 0.5);
        // Android 13+ themed icons: one colour, tinted by the system.
        await _render('$res/mipmap-$d/ic_launcher_monochrome.png', (108 * k).round(), style: MarkStyle.ink, scale: 0.5);
      }
      // Web: favicon, PWA icons, and maskable ones that fill the square.
      await _render('web/favicon.png', 64, background: _cream, radius: 0.22, scale: 0.72);
      for (final size in [192, 512]) {
        await _render('web/icons/Icon-$size.png', size, background: _cream, radius: 0.22);
        await _render('web/icons/Icon-maskable-$size.png', size, background: _cream, scale: 0.56);
      }
    });
  });
}
