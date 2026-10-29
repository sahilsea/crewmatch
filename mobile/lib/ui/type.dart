import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'palette.dart';

/// The four typefaces of the retro desktop look, from Google Fonts.
abstract final class AppType {
  /// Fonts are fetched from Google Fonts at runtime and cached on the device.
  /// Widget tests switch this off so they never touch the network.
  static bool fetchFonts = true;

  /// Window titles: Anton, set in uppercase.
  static TextStyle title({double size = 20, Color color = Palette.ink}) => _font(
        GoogleFonts.anton,
        'Anton',
        TextStyle(fontSize: size, letterSpacing: 0.6, height: 1.15, color: color),
      );

  /// Big serif headlines and names: Old Standard TT bold.
  static TextStyle headline({double size = 30, Color color = Palette.ink}) => _font(
        GoogleFonts.oldStandardTt,
        'Old Standard TT',
        TextStyle(fontSize: size, fontWeight: FontWeight.w700, height: 1.05, color: color),
      );

  /// Body copy and buttons: Pixelify Sans.
  static TextStyle body({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color color = Palette.ink,
    double height = 1.4,
  }) =>
      _font(
        GoogleFonts.pixelifySans,
        'Pixelify Sans',
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color,
          fontFeatures: _noLigatures,
        ),
      );

  /// Pixelify Sans draws a broken glyph for its "fi" ligature ("fits first"
  /// comes out wrong), so ligatures stay off wherever it is used.
  static const _noLigatures = [FontFeature.disable('liga'), FontFeature.disable('calt')];

  /// Labels, meta, numbers and status lines: VT323, set in uppercase.
  static TextStyle label({double size = 17, Color color = Palette.muted}) => _font(
        GoogleFonts.vt323,
        'VT323',
        TextStyle(fontSize: size, letterSpacing: 0.9, height: 1.1, color: color),
      );

  /// Material's text theme in Pixelify Sans, without ligatures.
  static TextTheme textTheme(TextTheme base) {
    final theme = fetchFonts
        ? GoogleFonts.pixelifySansTextTheme(base)
        : base.apply(fontFamily: 'Pixelify Sans');
    TextStyle? plain(TextStyle? style) => style?.copyWith(fontFeatures: _noLigatures);
    return theme.copyWith(
      displayLarge: plain(theme.displayLarge),
      displayMedium: plain(theme.displayMedium),
      displaySmall: plain(theme.displaySmall),
      headlineLarge: plain(theme.headlineLarge),
      headlineMedium: plain(theme.headlineMedium),
      headlineSmall: plain(theme.headlineSmall),
      titleLarge: plain(theme.titleLarge),
      titleMedium: plain(theme.titleMedium),
      titleSmall: plain(theme.titleSmall),
      bodyLarge: plain(theme.bodyLarge),
      bodyMedium: plain(theme.bodyMedium),
      bodySmall: plain(theme.bodySmall),
      labelLarge: plain(theme.labelLarge),
      labelMedium: plain(theme.labelMedium),
      labelSmall: plain(theme.labelSmall),
    );
  }

  static TextStyle _font(
    TextStyle Function({TextStyle? textStyle}) googleFont,
    String family,
    TextStyle style,
  ) =>
      fetchFonts ? googleFont(textStyle: style) : style.copyWith(fontFamily: family);
}

/// A VT323 label, always uppercase: meta lines, counters, status text.
class Label extends StatelessWidget {
  const Label(
    this.text, {
    super.key,
    this.size = 17,
    this.color = Palette.muted,
    this.maxLines,
    this.textAlign,
  });

  final String text;
  final double size;
  final Color color;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppType.label(size: size, color: color),
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        textAlign: textAlign,
      );
}
