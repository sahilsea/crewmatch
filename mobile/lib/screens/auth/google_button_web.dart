import 'package:google_sign_in_web/web_only.dart' as web;
import 'package:material_ui/material_ui.dart';

/// Google's own button. Browsers only allow Google sign-in through it.
Widget googleWebButton({required bool dark, required bool registering, required double width}) => web.renderButton(
      configuration: web.GSIButtonConfiguration(
        theme: dark ? web.GSIButtonTheme.filledBlack : web.GSIButtonTheme.outline,
        shape: web.GSIButtonShape.pill,
        size: web.GSIButtonSize.large,
        text: registering ? web.GSIButtonText.signupWith : web.GSIButtonText.continueWith,
        minimumWidth: width.clamp(200, 400).toDouble(),
      ),
    );
