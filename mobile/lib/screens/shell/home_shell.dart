import 'package:material_ui/material_ui.dart';

import '../crew/crew_screen.dart';
import '../discover/discover_screen.dart';
import '../posts/posts_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../matches/matches_screen.dart';
import 'app_tab.dart';
import '../../ui/ui.dart';
import 'dock.dart';
import 'side_rail.dart';
import 'top_menu_bar.dart';

/// The signed-in app: menu bar on top, the current tab, the dock below.
///
/// Each visit builds the tab afresh, so it always shows current data
/// (a crew formed on the web shows up as soon as you open Crew).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Remembered across theme switches, which rebuild the whole app.
  static var _lastTab = AppTab.discover;
  var _tab = _lastTab;

  /// Bumped on every dock tap, so tapping the open tab reloads it.
  var _visit = 0;

  void _open(AppTab tab) => setState(() {
        _tab = _lastTab = tab;
        _visit++;
      });

  Widget _screen(bool wide) => KeyedSubtree(
        key: ValueKey((_tab, _visit, wide)),
        child: switch (_tab) {
          AppTab.discover => DiscoverScreen(onOpen: _open, wide: wide),
          AppTab.matches => MatchesScreen(onOpen: _open, wide: wide),
          AppTab.crew => CrewScreen(onOpen: _open, wide: wide),
          AppTab.posts => PostsScreen(onOpen: _open, wide: wide),
          AppTab.ranks => LeaderboardScreen(onOpen: _open, wide: wide),
        },
      );

  @override
  Widget build(BuildContext context) {
    final size = WindowSize.of(context);
    // Tablets and browsers: a side rail instead of the top and bottom bars.
    if (size.hasRail) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SideRail(selected: _tab, onSelected: _open),
              // On very wide monitors the content stays a balanced width,
              // centred, instead of stretching into long empty lines.
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
      bottomNavigationBar: Dock(selected: _tab, onSelected: _open),
    );
  }
}
