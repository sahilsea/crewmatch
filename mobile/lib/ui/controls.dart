import 'package:material_ui/material_ui.dart';

import 'dashed.dart';
import 'glyphs.dart';
import 'motion.dart';
import 'palette.dart';
import 'type.dart';

/// One square button in a [SegmentRow].
class Segment {
  const Segment({
    required this.label,
    required this.onPressed,
    this.glyph,
    this.color = Palette.inset,
  });

  final String label;
  final VoidCallback? onPressed;
  final Glyph? glyph;

  /// Light by default; [Palette.crimson] or [Palette.gold] marks the main action.
  final Color color;
}

/// A full-width row of rounded buttons, used for the action bar along the
/// bottom of a card.
class SegmentRow extends StatelessWidget {
  const SegmentRow({super.key, required this.segments, this.height = 52});

  final List<Segment> segments;
  final double height;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
    child: SizedBox(
      height: height,
      child: Row(
        children: [
          for (final (i, segment) in segments.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _SegmentButton(segment)),
          ],
        ],
      ),
    ),
  );
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton(this.segment);

  final Segment segment;

  @override
  Widget build(BuildContext context) {
    final enabled = segment.onPressed != null;
    // Pink and gold marked the main action in the old look; it is crimson now.
    final main = segment.color == Palette.pink || segment.color == Palette.gold;
    final fill = !enabled
        ? Palette.strip
        : (main ? Palette.crimson : segment.color);
    final strong =
        fill == Palette.crimson || fill == Palette.navy || fill == Palette.ink;
    final color = !enabled
        ? Palette.muted
        : (strong ? Palette.onCrimson : Palette.ink);
    final plain = fill == Palette.inset;
    // container: each segment is its own button for screen readers, rather
    // than merging into whatever card holds the row.
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      child: Material(
        color: plain ? Palette.field : fill,
        shape: StadiumBorder(
          side: plain
              ? const BorderSide(color: Palette.dashed)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: segment.onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (segment.glyph case final glyph?) ...[
                  GlyphIcon(
                    glyph,
                    size: glyph == Glyph.heart ? 18 : 14,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    segment.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(
                      size: 16,
                      weight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Filter chips. The active chip is gold.
class FilterTabs<T> extends StatelessWidget {
  const FilterTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  /// Value to label, in display order.
  final Map<T, String> tabs;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final MapEntry(key: value, value: label) in tabs.entries)
        _FilterTab(
          label: label,
          active: value == selected,
          onTap: () => onChanged(value),
        ),
    ],
  );
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    selected: active,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // 48px tall to tap, 40px to see.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Motion.standard,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? Palette.gold : Colors.transparent,
            border: Border.all(color: active ? Palette.gold : Palette.dashed),
            borderRadius: Frame.chipRadius,
          ),
          // widthFactor 1: as wide as the label, not the whole row.
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: AppType.body(
                size: 14,
                weight: FontWeight.w500,
                color: active ? Palette.onGold : Palette.ink,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A quiet secondary button with a dashed outline ("Leave", "Unmatch").
class DashedButton extends StatelessWidget {
  const DashedButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DashedBorder(
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: Palette.window,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const StadiumBorder(),
        textStyle: AppType.body(weight: FontWeight.w500),
      ),
      child: Text(label),
    ),
  );
}

/// The round send button for chat and comments: crimson with a little pop
/// once there's something to send.
class SendButton extends StatelessWidget {
  const SendButton({super.key, required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: enabled ? 1 : 0.9,
        duration: Motion.of(context, const Duration(milliseconds: 250)),
        curve: Curves.easeOutBack,
        child: IconButton.filled(
          tooltip: 'Send',
          onPressed: enabled ? onPressed : null,
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: Palette.crimson,
            foregroundColor: Palette.onCrimson,
            disabledBackgroundColor: Palette.high,
            disabledForegroundColor: Palette.muted,
          ),
          icon: const Icon(Icons.send_rounded, size: 22),
        ),
      );
}
