import 'package:material_ui/material_ui.dart';

import 'glyphs.dart';
import 'palette.dart';
import 'type.dart';

/// A retro desktop window: title bar with a close mark, content, and an
/// optional footer and grey status strip.
///
/// With [fill] the content stretches to the window's height (the window must
/// get a bounded height, e.g. inside [Expanded]); without it the window sizes
/// itself to its content, for windows stacked in a scroll view.
class RetroWindow extends StatelessWidget {
  const RetroWindow({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
    this.inset = true,
    this.fill = false,
    this.footer,
    this.status,
  });

  final String title;
  final Widget child;

  /// Makes the ✕ a real button (dialogs, pushed screens). Without it the ✕ is decoration.
  final VoidCallback? onClose;

  /// Wraps [child] in the white inset panel with a 10px margin.
  final bool inset;
  final bool fill;

  /// Pinned under the content, e.g. a [SegmentRow].
  final Widget? footer;

  /// Text for the strip along the bottom, e.g. "17 items · sorted by fit".
  final String? status;

  @override
  Widget build(BuildContext context) {
    final content = inset ? InsetPanel(child: child) : child;
    return Container(
      decoration: const BoxDecoration(
        color: Palette.window,
        borderRadius: Frame.radius,
        boxShadow: Frame.windowShadow,
      ),
      foregroundDecoration: const BoxDecoration(
        border: Frame.border,
        borderRadius: Frame.radius,
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(Frame.line),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TitleBar(title: title, onClose: onClose),
          if (fill) Expanded(child: content) else content,
          ?footer,
          if (status != null) StatusStrip(status!),
        ],
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title, this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    const mark = GlyphIcon(Glyph.close, size: 12);
    return Container(
      height: 34,
      padding: const EdgeInsets.only(right: 12),
      decoration: const BoxDecoration(border: Border(bottom: Frame.side)),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: onClose == null
                ? const Center(child: mark)
                : Semantics(
                    button: true,
                    label: 'Close',
                    child: InkWell(onTap: onClose, child: const Center(child: mark)),
                  ),
          ),
          Expanded(
            child: Text(
              title.toUpperCase(),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.title(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The white, ink-bordered panel that holds a window's content.
class InsetPanel extends StatelessWidget {
  const InsetPanel({super.key, required this.child, this.margin = const EdgeInsets.all(10)});

  final Widget child;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        decoration: const BoxDecoration(color: Palette.inset, border: Frame.border),
        clipBehavior: Clip.hardEdge,
        child: child,
      );
}

/// The grey strip along the bottom of a window: "3 reasons · weights are fixed".
class StatusStrip extends StatelessWidget {
  const StatusStrip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: const BoxDecoration(
          color: Palette.strip,
          border: Border(top: Frame.side),
        ),
        child: Label(text, size: 16, color: Palette.mutedDark, maxLines: 1),
      );
}
