import 'package:material_ui/material_ui.dart';

import 'controls.dart';
import 'palette.dart';
import 'type.dart';
import 'window.dart';

/// Shows [builder]'s content in a retro window that pops in. Its ✕ closes it
/// with a null result.
Future<T?> showWindowDialog<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) =>
    showDialog<T>(
      context: context,
      barrierColor: Palette.ink.withValues(alpha: 0.35),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          // Scrolls as a whole when the keyboard leaves too little room. The
          // padding keeps the window's shadow inside the scroll view's clip.
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.88, end: 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: RetroWindow(
                title: title,
                inset: false,
                onClose: () => Navigator.of(context).pop(),
                child: Builder(builder: builder),
              ),
            ),
          ),
        ),
      ),
    );

/// Asks a yes/no question. Resolves to true only when the user confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showWindowDialog<bool>(
    context,
    title: title,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Text(message, style: AppType.body(size: 16)),
        ),
        SegmentRow(
          segments: [
            Segment(label: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
            Segment(
              label: confirmLabel,
              color: Palette.pink,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
