import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import 'palette.dart';
import 'type.dart';

/// Material 3 theme for the wizarding-school look: parchment, crimson, gold.
/// Light or dark follows [Palette.isDark], so set that first.
ThemeData buildTheme() {
  OutlineInputBorder inputBorder(Color color, [double width = Frame.line]) =>
      OutlineInputBorder(
        borderRadius: Frame.buttonRadius,
        borderSide: BorderSide(color: color, width: width),
      );

  final dark = Palette.isDark;
  final base = ThemeData(useMaterial3: true, brightness: dark ? Brightness.dark : Brightness.light);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.desktop,
    colorScheme: ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: Palette.crimson,
      onPrimary: Palette.onCrimson,
      secondary: Palette.gold,
      onSecondary: Palette.onGold,
      surface: Palette.window,
      onSurface: Palette.ink,
      error: Palette.danger,
      onError: Palette.onCrimson,
      outline: Palette.dashed,
      outlineVariant: Palette.border,
      surfaceContainerLow: Palette.window,
      surfaceContainer: Palette.strip,
      surfaceContainerHigh: Palette.high,
      secondaryContainer: Palette.gold,
      onSecondaryContainer: Palette.onGold,
    ),
    // M3 page motion: the new screen fades forward over the old one.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.desktop,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Palette.dashed,
      shape: RoundedRectangleBorder(borderRadius: Frame.sheetRadius),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Palette.desktop,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
    ),
    textTheme: AppType.textTheme(base.textTheme)
        .apply(bodyColor: Palette.ink, displayColor: Palette.ink),
    splashFactory: InkSparkle.splashFactory,
    highlightColor: Palette.ink.withValues(alpha: 0.08),
    hoverColor: Palette.ink.withValues(alpha: 0.04),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: AppType.body(size: 16, color: Palette.muted),
      errorStyle: AppType.body(size: 13.5, color: Palette.danger),
      border: inputBorder(Palette.dashed),
      enabledBorder: inputBorder(Palette.dashed),
      focusedBorder: inputBorder(Palette.link, 2),
      disabledBorder: inputBorder(Palette.dashed),
      errorBorder: inputBorder(Palette.danger),
      focusedErrorBorder: inputBorder(Palette.danger, 2.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.crimson,
        foregroundColor: Palette.onCrimson,
        disabledBackgroundColor: Palette.strip,
        disabledForegroundColor: Palette.muted,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
        textStyle: AppType.body(size: 16, weight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Palette.ink,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: const BorderSide(color: Palette.dashed),
        shape: const StadiumBorder(),
        textStyle: AppType.body(weight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.link,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: const StadiumBorder(),
        textStyle: AppType.body(weight: FontWeight.w500),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.navy,
      contentTextStyle: AppType.body(size: 14.5, color: Palette.cream),
      shape: const RoundedRectangleBorder(borderRadius: Frame.buttonRadius),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(shape: const CircleBorder()),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Palette.window,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      labelTextStyle: WidgetStatePropertyAll(
        AppType.body(size: 15, color: Palette.ink),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.crimson,
      linearTrackColor: Palette.strip,
      refreshBackgroundColor: Palette.window,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Palette.link,
      selectionColor: Color(0x66E8C25E),
      selectionHandleColor: Palette.link,
    ),
    checkboxTheme: CheckboxThemeData(
      side: Frame.side,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Palette.blue
            : Palette.inset,
      ),
      checkColor: const WidgetStatePropertyAll(Palette.ink),
    ),
    dividerTheme: const DividerThemeData(
      color: Palette.divider,
      thickness: 1,
      space: 1,
    ),
  );
}

/// Lets a mouse drag lists and pull to refresh too, so the web build behaves
/// like the phone.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}
