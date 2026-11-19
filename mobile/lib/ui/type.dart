import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'palette.dart';

/// The two typefaces of the wizarding-school look, from Google Fonts:
/// Cinzel for titles and headlines, Roboto for everything you read.
abstract final class AppType {
  /// Fonts are fetched from Google Fonts at runtime and cached on the device.
  /// Widget tests switch this off so they never touch the network.
  static bool fetchFonts = true;

  /// Card and screen titles: Cinzel bold.
  static TextStyle title({double size = 20, Color color = Palette.ink}) =>
      _font(
        GoogleFonts.cinzel,
        'Cinzel',
        TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1.08,
          color: color,
        ),
      );

  /// Big headlines and names: Cinzel bold, a little smaller than the old
  /// serif because its capitals run wide.
  static TextStyle headline({double size = 30, Color color = Palette.ink}) =>
      _font(
        GoogleFonts.cinzel,
        'Cinzel',
        TextStyle(
          fontSize: size * 0.82,
          fontWeight: FontWeight.w700,
          height: 1.08,
          color: color,
        ),
      );

  /// Body copy and buttons: Roboto.
  static TextStyle body({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color color = Palette.ink,
    double height = 1.4,
  }) => _font(
    GoogleFonts.roboto,
    'Roboto',
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      fontFeatures: _noLigatures,
    ),
  );

  /// Kept off from the pixel-font days; harmless with Roboto.
  static const _noLigatures = <FontFeature>[];

  /// Labels, meta, numbers and status lines: small Roboto caps. Callers
  /// still pass the old terminal-font sizes, which ran small, so they are
  /// scaled down to match.
  static TextStyle label({double size = 17, Color color = Palette.muted}) =>
      _font(
        GoogleFonts.roboto,
        'Roboto',
        TextStyle(
          fontSize: size * 0.72,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6,
          height: 1.25,
          color: color,
        ),
      );

  /// Material's text theme in Roboto.
  static TextTheme textTheme(TextTheme base) {
    final theme = fetchFonts
        ? GoogleFonts.robotoTextTheme(base)
        : base.apply(fontFamily: 'Roboto');
    TextStyle? plain(TextStyle? style) =>
        style?.copyWith(fontFeatures: _noLigatures);
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
  ) => fetchFonts
      ? googleFont(textStyle: style)
      : style.copyWith(fontFamily: family);
}

/// A small-caps label, always uppercase: meta lines, counters, status text.
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
