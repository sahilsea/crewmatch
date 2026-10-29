import 'package:flutter/painting.dart';

/// Colours of the retro desktop look.
abstract final class Palette {
  /// The pink desktop behind every window.
  static const desktop = Color(0xFFF3CFCD);
  static const ink = Color(0xFF1A1A1A);
  static const window = Color(0xFFFBF8F3);
  static const inset = Color(0xFFFFFFFF);

  /// Input and chip fill, a touch warmer than [inset].
  static const field = Color(0xFFFFFDF9);

  /// Status strips and inactive tabs.
  static const strip = Color(0xFFECE8E1);
  static const muted = Color(0xFF6B665F);
  static const mutedDark = Color(0xFF5C5752);
  static const border = Color(0xFFC9C4BA);
  static const divider = Color(0xFFD9D4CB);
  static const dashed = Color(0xFFA8A29A);
  static const blue = Color(0xFFA6D9E7);
  static const pink = Color(0xFFF5B8C4);

  /// The dark masthead panel and its text.
  static const dark = Color(0xFF1F1D1B);
  static const cream = Color(0xFFFBF8F3);
  static const darkMuted = Color(0xFFB9B3AA);

  static const danger = Color(0xFFA4262C);
}

/// Shared shapes and shadows.
abstract final class Frame {
  static const line = 1.5;
  static const radius = BorderRadius.all(Radius.circular(6));
  static const side = BorderSide(color: Palette.ink, width: line);
  static const border = Border.fromBorderSide(side);
  static const windowShadow = [
    BoxShadow(color: Color(0x241A1A1A), blurRadius: 26, offset: Offset(0, 10)),
  ];
}
