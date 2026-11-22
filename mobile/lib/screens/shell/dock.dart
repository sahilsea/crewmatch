import 'package:material_ui/material_ui.dart';

import '../../ui/ui.dart';
import 'app_tab.dart';

/// The Material 3 navigation bar: one destination per [AppTab], with a
/// 64×32 gold pill that grows open under the current one.
class Dock extends StatelessWidget {
  const Dock({super.key, required this.selected, required this.onSelected});

  final AppTab selected;
  final OpenTab onSelected;

  @override
  Widget build(BuildContext context) => Container(
    color: Palette.strip,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 80,
        child: Row(
          children: [
            for (final tab in AppTab.values) ...[
              Expanded(
                child: _DockButton(
                  tab: tab,
                  selected: tab == selected,
                  onTap: () => onSelected(tab),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The indicator grows sideways from the icon, as in M3.
                AnimatedScale(
                  scale: selected ? 1 : 0.4,
                  duration: Motion.of(context, const Duration(milliseconds: 350)),
                  curve: Motion.ease,
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: Motion.of(context, const Duration(milliseconds: 200)),
                    curve: Motion.standard,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(color: Palette.gold, borderRadius: BorderRadius.all(Radius.circular(16))),
                      child: SizedBox(width: 64, height: 32),
                    ),
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(onTap: onTap, child: const SizedBox(width: 64, height: 32)),
                ),
                IgnorePointer(child: Center(
              child: GlyphIcon(
                tab.glyph,
                size: 22,
                color: selected ? Palette.onGold : Palette.muted,
              ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tab.label,
            style: AppType.body(
              size: 12,
              height: 1.2,
              weight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Palette.ink : Palette.muted,
            ),
          ),
        ],
      ),
    ),
  );
}
