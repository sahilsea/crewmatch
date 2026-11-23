import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../shell/top_menu_bar.dart';
import 'admin_clubs_screen.dart';
import 'admin_common.dart';
import 'admin_events_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_review_screen.dart';

/// The organiser's app: overview, events, review and ranks. A side rail in
/// wide windows, a bottom bar on phones.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static var _lastTab = AdminTab.overview;
  var _tab = _lastTab;
  var _visit = 0;

  /// Opens the events tab straight into a blank form.
  var _startNew = false;

  /// Crew links and student events waiting for review, for the badge.
  var _waiting = 0;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    try {
      final stats = await context.api.adminStats();
      if (mounted) setState(() => _waiting = stats.waiting);
    } on ApiException {
      // The badge keeps its old number.
    }
  }

  void _open(AdminTab tab, {bool startNew = false}) {
    setState(() {
      _tab = _lastTab = tab;
      _startNew = startNew;
      _visit++;
    });
    _refreshCount();
  }

  Widget _screen(bool wide) => KeyedSubtree(
        key: ValueKey((_tab, _visit, wide)),
        child: switch (_tab) {
          AdminTab.overview => AdminOverviewScreen(
              wide: wide,
              onOpen: _open,
              onNewEvent: () => _open(AdminTab.events, startNew: true),
              onChanged: _refreshCount,
            ),
          AdminTab.events => AdminEventsScreen(wide: wide, startNew: _startNew, onOpen: _open, onChanged: _refreshCount),
          AdminTab.review => AdminReviewScreen(wide: wide, onChanged: _refreshCount),
          AdminTab.clubs => AdminClubsScreen(wide: wide),
          AdminTab.ranks => LeaderboardScreen(onOpen: (_) {}, wide: wide),
        },
      );

  Widget _icon(AdminTab tab, Color color) {
    final icon = Icon(tab.icon, size: 22, color: color);
    if (tab != AdminTab.review || _waiting == 0) return icon;
    return Badge(
      label: Text('$_waiting'),
      backgroundColor: Palette.crimson,
      textColor: Palette.onCrimson,
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = WindowSize.of(context);
    if (size.hasRail) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AdminRail(selected: _tab, onSelected: _open, icon: _icon),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => Center(
                    child: SizedBox(
                      width: c.maxWidth.clamp(0, size.twoPane ? 1320 : c.maxWidth).toDouble(),
                      height: c.maxHeight,
                      child: _screen(size.twoPane),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TopMenuBar(trailing: AccountMenu()),
            Expanded(child: _screen(false)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => _open(AdminTab.values[i]),
        destinations: [
          for (final tab in AdminTab.values)
            NavigationDestination(icon: _icon(tab, Palette.muted), selectedIcon: _icon(tab, Palette.onGold), label: tab.label),
        ],
      ),
    );
  }
}

class _AdminRail extends StatelessWidget {
  const _AdminRail({required this.selected, required this.onSelected, required this.icon});

  final AdminTab selected;
  final void Function(AdminTab) onSelected;
  final Widget Function(AdminTab, Color) icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 88,
        color: Palette.strip,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const BrandMark(size: 44),
            const SizedBox(height: 30),
            for (final tab in AdminTab.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _RailItem(tab: tab, selected: tab == selected, onTap: () => onSelected(tab), icon: icon),
              ),
            const Spacer(),
            const AccountMenu(),
          ],
        ),
      );
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.tab, required this.selected, required this.onTap, required this.icon});

  final AdminTab tab;
  final bool selected;
  final VoidCallback onTap;
  final Widget Function(AdminTab, Color) icon;

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
                  decoration: BoxDecoration(
                    color: selected ? Palette.gold : Colors.transparent,
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Center(child: icon(tab, selected ? Palette.onGold : Palette.muted)),
                ),
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
        ),
      );
}
