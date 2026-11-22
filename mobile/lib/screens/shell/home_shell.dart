import '../../models/team_request.dart';
import '../../state/incoming_link.dart';
import '../people/person_screen.dart';
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
/// Each tab is built the first time you open it and then kept, so switching
/// back is instant and keeps your place. A tab loads fresh when you tap it
/// while it's open, or when another screen sends you there (e.g. "Form a
/// crew" opens Crew with the new crew in it).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Remembered across theme switches, which rebuild the whole app.
  static var _lastTab = AppTab.discover;
  var _tab = _lastTab;

  /// Tabs opened so far; the others aren't built until you visit them.
  late final _opened = <AppTab>{_tab};

  @override
  void initState() {
    super.initState();
    // Opened from a profile link: show that person once you're in.
    final handle = IncomingLink.take();
    if (handle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).push(PersonScreen.route(handle, source: RequestSource.link));
      });
    }
  }

  /// Bumped to rebuild one tab from scratch.
  final _generation = {for (final tab in AppTab.values) tab: 0};

  /// The dock or rail: switch, or reload the tab that's already open.
  void _select(AppTab tab) => setState(() {
        if (tab == _tab) _generation[tab] = _generation[tab]! + 1;
        _tab = _lastTab = tab;
        _opened.add(tab);
      });

  /// Another screen sending you here: show it with current data.
  void _open(AppTab tab) => setState(() {
        if (_opened.contains(tab)) _generation[tab] = _generation[tab]! + 1;
        _tab = _lastTab = tab;
        _opened.add(tab);
      });

  Widget _build(AppTab tab, bool wide) => switch (tab) {
        AppTab.discover => DiscoverScreen(onOpen: _open, wide: wide),
        AppTab.matches => MatchesScreen(onOpen: _open, wide: wide),
        AppTab.crew => CrewScreen(onOpen: _open, wide: wide),
        AppTab.posts => PostsScreen(onOpen: _open, wide: wide),
        AppTab.ranks => LeaderboardScreen(onOpen: _open, wide: wide),
      };

  /// Every opened tab stays alive; only the current one shows and animates.
  Widget _screen(bool wide) => IndexedStack(
        index: _tab.index,
        sizing: StackFit.expand,
        children: [
          for (final tab in AppTab.values)
            _opened.contains(tab)
                ? TickerMode(
                    enabled: tab == _tab,
                    child: KeyedSubtree(key: ValueKey((tab, _generation[tab], wide)), child: _build(tab, wide)),
                  )
                : const SizedBox.shrink(),
        ],
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
              SideRail(selected: _tab, onSelected: _select),
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
      bottomNavigationBar: Dock(selected: _tab, onSelected: _select),
    );
  }
}
