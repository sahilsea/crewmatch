import 'package:material_ui/material_ui.dart';

import '../../ui/ui.dart';
import 'app_tab.dart';
import 'top_menu_bar.dart';

/// The Material 3 navigation rail for wide windows: logo on top, the five
/// tabs, and your account menu at the bottom.
class SideRail extends StatelessWidget {
  const SideRail({super.key, required this.selected, required this.onSelected});

  final AppTab selected;
  final OpenTab onSelected;

  @override
  Widget build(BuildContext context) => Container(
        width: 88,
        color: Palette.strip,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const BrandMark(size: 44),
            const SizedBox(height: 30),
            for (final tab in AppTab.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _RailItem(tab: tab, selected: tab == selected, onTap: () => onSelected(tab)),
              ),
            const Spacer(),
            const AccountMenu(),
          ],
        ),
      );
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.tab, required this.selected, required this.onTap});

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: tab.label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: Frame.radius,
          child: SizedBox(
            width: 80,
            child: Column(
              spacing: 4,
              children: [
                AnimatedContainer(
                  duration: Motion.of(context, const Duration(milliseconds: 300)),
                  curve: Motion.ease,
                  width: selected ? 56 : 32,
                  height: 32,
                  decoration: BoxDecoration(color: selected ? Palette.gold : Colors.transparent, borderRadius: const BorderRadius.all(Radius.circular(16))),
                  child: Center(child: GlyphIcon(tab.glyph, size: 22, color: selected ? Palette.onGold : Palette.muted)),
                ),
                Text(
                  tab.label,
                  style: AppType.body(size: 12, height: 1.2, weight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? Palette.ink : Palette.muted),
                ),
              ],
            ),
          ),
        ),
      );
}
