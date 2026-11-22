import 'package:flutter/painting.dart';

/// A colour with a light and a dark value. It reads as whichever one
/// [Palette.isDark] picks, so `const` widgets keep working in both themes.
/// The app rebuilds from scratch when the theme changes (see `app.dart`), so
/// nothing keeps a stale value.
class Tone extends Color {
  const Tone(super.light, this.dark);

  final Color dark;

  @override
  double get a => Palette.isDark ? dark.a : super.a;
  @override
  double get r => Palette.isDark ? dark.r : super.r;
  @override
  double get g => Palette.isDark ? dark.g : super.g;
  @override
  double get b => Palette.isDark ? dark.b : super.b;
}

/// Colours of the wizarding-school look: parchment pages, ink text,
/// crimson actions, gold highlights and a midnight-navy accent. At night the
/// parchment turns to dark oak and the ink to cream.
abstract final class Palette {
  /// Which set of values every [Tone] reads. Set by the app before it builds.
  static bool isDark = false;

  /// The page behind every screen.
  static const desktop = Tone(0xFFF7EEDC, Color(0xFF15100C));

  /// Body text and strong lines.
  static const ink = Tone(0xFF2A1A12, Color(0xFFF3E9D2));

  /// Cards and sheets, a shade off the page.
  static const window = Tone(0xFFF3E6CD, Color(0xFF1F1812));

  /// Raised surfaces inside cards: stat tiles, list rows.
  static const inset = Tone(0xFFFBF5E8, Color(0xFF2A2119));

  /// Input and chip fill.
  static const field = Tone(0xFFFFFBF2, Color(0xFF1A140F));

  /// Navigation bar, tonal panels and inactive tabs.
  static const strip = Tone(0xFFEEDFC1, Color(0xFF241C15));

  /// The hover and pressed layer on [strip].
  static const high = Tone(0xFFE6D1A9, Color(0xFF2E241B));
  static const muted = Tone(0xFF5E4A3A, Color(0xFFC9B79A));
  static const mutedDark = muted;
  static const border = Tone(0xFFD6C09B, Color(0xFF4A3B2C));
  static const divider = Tone(0xFFE2D2B2, Color(0xFF3A2E22));
  static const dashed = Tone(0xFF8C7660, Color(0xFF8C7A62));

  /// Highlights: selected chips, points, the active tab.
  static const blue = gold;

  /// Soft accent panels with ink text (photo areas, tags).
  static const pink = Tone(0xFFF2DDB1, Color(0xFF3A2A1C));

  /// Text on [pink].
  static const onPink = Tone(0xFF4A2A06, Color(0xFFF2DDB1));

  /// Midnight-navy panels and the light text on them.
  static const dark = navy;
  static const cream = Tone(0xFFF3E9D2, Color(0xFFE6ECFF));
  static const darkMuted = Color(0xFFC6BFD6);

  static const danger = Tone(0xFFA4262C, Color(0xFFF2726B));

  /// Text links and text buttons: crimson by day, gold by night (crimson
  /// text is too dim on the dark page).
  static const link = Tone(0xFF7A1C1C, Color(0xFFE8C25E));

  static const crimson = Tone(0xFF7A1C1C, Color(0xFFA8312E));
  static const onCrimson = Tone(0xFFFFF6E0, Color(0xFFFFF1DA));
  static const gold = Color(0xFFE8C25E);
  static const onGold = Tone(0xFF3A2900, Color(0xFF2A1D00));
  static const navy = Tone(0xFF22305A, Color(0xFF2C3E70));
}

/// Material 3 shapes: 16px cards, fully rounded buttons, 12px fields and
/// tiles, 8px chips and tags, 28px sheets.
abstract final class Frame {
  static const line = 1.0;
  static const radius = BorderRadius.all(Radius.circular(16));
  static const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

  /// Text fields, stat tiles and other small containers.
  static const buttonRadius = BorderRadius.all(Radius.circular(12));

  /// Buttons and anything you tap: a full pill.
  static const pill = BorderRadius.all(Radius.circular(999));
  static const chipRadius = BorderRadius.all(Radius.circular(8));
  static const tagRadius = BorderRadius.all(Radius.circular(8));
  static const side = BorderSide(color: Palette.border, width: line);
  static const border = Border.fromBorderSide(side);
  static const windowShadow = [
    BoxShadow(color: Color(0x142A1A12), blurRadius: 14, offset: Offset(0, 4)),
  ];
}
