import 'package:material_ui/material_ui.dart';

import 'glyphs.dart';
import 'palette.dart';
import 'type.dart';

/// A card: a Cinzel title (with a close button when [onClose] is set),
/// content, and an optional footer and status line.
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

  /// Shows a close button (dialogs, pushed screens).
  final VoidCallback? onClose;

  /// Wraps [child] in a little padding.
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
        border: Frame.border,
        boxShadow: Frame.windowShadow,
      ),
      clipBehavior: Clip.antiAlias,
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, 12, onClose == null ? 16 : 4, 4),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.title(size: 18),
            ),
          ),
        ),
        if (onClose != null)
          IconButton(
            onPressed: onClose,
            tooltip: 'Close',
            icon: const GlyphIcon(Glyph.close, size: 14, color: Palette.muted),
          ),
      ],
    ),
  );
}

/// The content area of a card. Cards no longer box their content twice, so
/// this only adds breathing room.
class InsetPanel extends StatelessWidget {
  const InsetPanel({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(4, 0, 4, 4),
  });

  final Widget child;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) => Padding(padding: margin, child: child);
}

/// The quiet line along the bottom of a card: "3 reasons · weights are fixed".
class StatusStrip extends StatelessWidget {
  const StatusStrip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: const BoxDecoration(border: Border(top: Frame.side)),
    child: Label(text, size: 16, color: Palette.mutedDark, maxLines: 1),
  );
}

/// The top of a screen: a Cinzel title, an optional subtitle, and an optional
/// action on the right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle, this.trailing, this.leading});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(leading == null ? 20 : 4, 20, 8, 8),
        child: Row(
          children: [
            ?leading,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Semantics(header: true, child: Text(title, style: AppType.title(size: 24))),
                  if (subtitle case final subtitle?) Text(subtitle, style: AppType.body(size: 14, color: Palette.muted)),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      );
}

/// A small tag with an optional icon: gold reasons, navy superpowers.
class InfoTag extends StatelessWidget {
  const InfoTag(this.text, {super.key, this.icon, this.color = Palette.gold, this.textColor = Palette.onGold});

  final String text;
  final IconData? icon;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: Frame.tagRadius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            if (icon != null) Icon(icon, size: 14, color: textColor),
            Flexible(child: Text(text, style: AppType.body(size: 13, weight: FontWeight.w500, height: 1.2, color: textColor))),
          ],
        ),
      );
}
