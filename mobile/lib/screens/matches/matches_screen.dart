import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/crew.dart';
import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import '../../util/parallel.dart';
import '../shell/app_tab.dart';
import 'match_tile.dart';

/// People who swiped right on you too, with unmatch and add-to-crew.
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key, required this.onOpen});

  final OpenTab onOpen;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<User>? _matches;
  Crew? _crew;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.api;
    try {
      final (matches, crew) = await waitBoth(api.matches(), api.myCrew());
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _crew = crew;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _unmatch(User person) async {
    final confirmed = await confirmAction(
      context,
      title: 'Unmatch',
      message: "Unmatch ${person.name}? They won't show up in your deck again.",
      confirmLabel: 'Unmatch',
    );
    if (!confirmed || !mounted) return;
    final session = context.session;
    try {
      await session.api.unmatch(person.id);
      setState(() => _matches!.removeWhere((m) => m.id == person.id));
      await session.refreshUser();
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    }
  }

  Future<void> _addToCrew(User person) async {
    try {
      final crew = await context.api.addCrewMember(person.id);
      if (!mounted) return;
      setState(() {
        _crew = crew;
        _matches = [
          for (final m in _matches!) m.id == person.id ? m.copyWith(inCrew: true) : m,
        ];
      });
      showNotice(context, 'Added ${person.name} to ${crew.name}');
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: RetroWindow(
        title: 'Matches',
        fill: true,
        status: matches == null || matches.isEmpty
            ? null
            : '${plural(matches.length, 'match', 'matches')} · newest first',
        child: switch (matches) {
          null when _error != null => ErrorView(error: _error!, onRetry: _retry),
          null => const LoadingView(),
          [] => Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  title: 'No matches yet',
                  message: "Swipe right on people you'd team up with. "
                      'When they like you back, they show up here.',
                  actions: [
                    FilledButton(
                      onPressed: () => widget.onOpen(AppTab.discover),
                      child: const Text('Start swiping'),
                    ),
                  ],
                ),
              ),
            ),
          final List<User> list => RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: list.length + (_crew == null ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, i) {
                  if (_crew == null && i == 0) {
                    return _StartCrewBanner(onTap: () => widget.onOpen(AppTab.crew));
                  }
                  final person = list[_crew == null ? i - 1 : i];
                  return MatchTile(
                    person: person,
                    crew: _crew,
                    onAddToCrew: () => _addToCrew(person),
                    onUnmatch: () => _unmatch(person),
                  );
                },
              ),
            ),
        },
      ),
    );
  }

  void _retry() {
    setState(() => _error = null);
    _load();
  }
}

class _StartCrewBanner extends StatelessWidget {
  const _StartCrewBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        color: Palette.strip,
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            const Expanded(
              child: Label('No crew yet · start one from your matches', color: Palette.ink, maxLines: 2),
            ),
            TextButton(onPressed: onTap, child: const Text('Start a crew')),
          ],
        ),
      );
}
