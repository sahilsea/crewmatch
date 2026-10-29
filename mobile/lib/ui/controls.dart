import 'package:material_ui/material_ui.dart';

import 'dashed.dart';
import 'glyphs.dart';
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

  /// White by default; [Palette.blue] marks the primary segment.
  final Color color;
}

/// A full-width row of square buttons split by ink dividers, used for the
/// action bar along the bottom of a window or card.
class SegmentRow extends StatelessWidget {
  const SegmentRow({super.key, required this.segments, this.height = 52});

  final List<Segment> segments;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: const BoxDecoration(border: Border(top: Frame.side)),
        child: Row(
          children: [
            for (final (i, segment) in segments.indexed) ...[
              if (i > 0) const VerticalDivider(width: Frame.line, thickness: Frame.line, color: Palette.ink),
              Expanded(child: _SegmentButton(segment)),
            ],
          ],
        ),
      );
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton(this.segment);

  final Segment segment;

  @override
  Widget build(BuildContext context) {
    final enabled = segment.onPressed != null;
    final color = enabled ? Palette.ink : Palette.muted;
    // container: each segment is its own button for screen readers, rather
    // than merging into whatever card holds the row.
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled ? segment.color : Palette.strip,
        child: InkWell(
          onTap: segment.onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (segment.glyph case final glyph?) ...[
                  GlyphIcon(glyph, size: glyph == Glyph.heart ? 16 : 13, color: color),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    segment.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(size: 16, weight: FontWeight.w600, color: color),
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

/// VT323 filter tabs. The active tab is ink with cream text.
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
        spacing: 6,
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
  const _FilterTab({required this.label, required this.active, required this.onTap});

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
          // 44px tall to tap, 34px to see.
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active ? Palette.ink : Palette.strip,
                border: Border.all(color: active ? Palette.ink : Palette.border, width: Frame.line),
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
              // widthFactor 1: as wide as the label, not the whole row.
              child: Center(
                widthFactor: 1,
                child: Label(label, size: 18, color: active ? Palette.cream : Palette.mutedDark),
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
            shape: const RoundedRectangleBorder(borderRadius: Frame.radius),
            textStyle: AppType.body(weight: FontWeight.w500),
          ),
          child: Text(label),
        ),
      );
}
