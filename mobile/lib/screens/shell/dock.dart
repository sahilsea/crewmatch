import 'package:material_ui/material_ui.dart';

import '../../ui/ui.dart';
import 'app_tab.dart';

/// The bottom dock with one button per [AppTab].
class Dock extends StatelessWidget {
  const Dock({super.key, required this.selected, required this.onSelected});

  final AppTab selected;
  final OpenTab onSelected;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Palette.window,
          border: Border(top: Frame.side),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (final tab in AppTab.values) ...[
                  if (tab.index > 0)
                    const VerticalDivider(width: Frame.line, thickness: Frame.line, color: Palette.ink),
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
  const _DockButton({required this.tab, required this.selected, required this.onTap});

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        selected: selected,
        child: Material(
          color: selected ? Palette.strip : Palette.window,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GlyphIcon(tab.glyph, size: 28),
                const SizedBox(height: 3),
                Text(
                  tab.label,
                  style: AppType.body(
                    size: 12.5,
                    height: 1.2,
                    weight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
