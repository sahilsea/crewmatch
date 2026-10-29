import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import 'palette.dart';
import 'type.dart';

/// Material theme tuned to the retro desktop look: flat, square, inked.
ThemeData buildTheme() {
  const square = BorderRadius.zero;
  OutlineInputBorder inputBorder(Color color, [double width = Frame.line]) =>
      OutlineInputBorder(borderRadius: square, borderSide: BorderSide(color: color, width: width));

  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.desktop,
    colorScheme: const ColorScheme.light(
      primary: Palette.ink,
      onPrimary: Palette.cream,
      secondary: Palette.pink,
      onSecondary: Palette.ink,
      surface: Palette.window,
      onSurface: Palette.ink,
      error: Palette.danger,
      outline: Palette.ink,
    ),
    textTheme: AppType.textTheme(base.textTheme)
        .apply(bodyColor: Palette.ink, displayColor: Palette.ink),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Palette.ink.withValues(alpha: 0.08),
    hoverColor: Palette.ink.withValues(alpha: 0.04),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: AppType.body(size: 16, color: Palette.muted),
      errorStyle: AppType.body(size: 13.5, color: Palette.danger),
      border: inputBorder(Palette.ink),
      enabledBorder: inputBorder(Palette.ink),
      focusedBorder: inputBorder(Palette.ink, 2.5),
      disabledBorder: inputBorder(Palette.dashed),
      errorBorder: inputBorder(Palette.danger),
      focusedErrorBorder: inputBorder(Palette.danger, 2.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.pink,
        foregroundColor: Palette.ink,
        disabledBackgroundColor: Palette.strip,
        disabledForegroundColor: Palette.muted,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const RoundedRectangleBorder(borderRadius: Frame.radius, side: Frame.side),
        textStyle: AppType.body(size: 16.5, weight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Palette.inset,
        foregroundColor: Palette.ink,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: Frame.side,
        shape: const RoundedRectangleBorder(borderRadius: Frame.radius),
        textStyle: AppType.body(weight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.ink,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: AppType.body(weight: FontWeight.w500).copyWith(
          decoration: TextDecoration.underline,
          decorationThickness: 1.5,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.ink,
      contentTextStyle: AppType.label(size: 19, color: Palette.cream),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Palette.window,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        side: Frame.side,
      ),
      labelTextStyle: WidgetStatePropertyAll(AppType.label(size: 20, color: Palette.ink)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.ink,
      linearTrackColor: Palette.strip,
      refreshBackgroundColor: Palette.window,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Palette.ink,
      selectionColor: Palette.blue,
      selectionHandleColor: Palette.ink,
    ),
    checkboxTheme: CheckboxThemeData(
      side: Frame.side,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Palette.blue : Palette.inset,
      ),
      checkColor: const WidgetStatePropertyAll(Palette.ink),
    ),
    dividerTheme: const DividerThemeData(color: Palette.divider, thickness: 1, space: 1),
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
