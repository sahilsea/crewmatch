import 'package:material_ui/material_ui.dart';

import '../crew/crew_screen.dart';
import '../discover/discover_screen.dart';
import '../events/events_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../matches/matches_screen.dart';
import 'app_tab.dart';
import 'dock.dart';
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
  var _tab = AppTab.discover;

  /// Bumped on every dock tap, so tapping the open tab reloads it.
  var _visit = 0;

  void _open(AppTab tab) => setState(() {
        _tab = tab;
        _visit++;
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const TopMenuBar(trailing: AccountMenu()),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey((_tab, _visit)),
                  child: switch (_tab) {
                    AppTab.discover => DiscoverScreen(onOpen: _open),
                    AppTab.matches => MatchesScreen(onOpen: _open),
                    AppTab.crew => CrewScreen(onOpen: _open),
                    AppTab.events => EventsScreen(onOpen: _open),
                    AppTab.ranks => LeaderboardScreen(onOpen: _open),
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Dock(selected: _tab, onSelected: _open),
      );
}
