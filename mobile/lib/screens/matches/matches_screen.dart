import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/crew.dart';
import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/parallel.dart';
import '../shell/app_tab.dart';
import 'match_tile.dart';

/// People who swiped right on you too, with unmatch and add-to-crew.
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key, required this.onOpen, this.wide = false});

  final OpenTab onOpen;

  /// Wide windows: the list with the selected match's details beside it.
  final bool wide;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<User>? _matches;
  Crew? _crew;
  String? _selectedId;
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
          for (final m in _matches!)
            m.id == person.id ? m.copyWith(inCrew: true) : m,
        ];
      });
      showNotice(context, 'Added ${person.name} to ${crew.name}');
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    }
  }

  Future<void> _removeFromCrew(User person) async {
    final crew = _crew;
    if (crew == null) return;
    if (crew.members.length <= 2) {
      return showNotice(context, 'A crew needs two people. Leave it from the Crew tab instead.');
    }
    final confirmed = await confirmAction(
      context,
      title: 'Remove from crew',
      message: 'Take ${person.name} out of ${crew.name}?',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;
    try {
      final updated = await context.api.removeCrewMember(person.id);
      if (!mounted) return;
      setState(() {
        _crew = updated;
        _matches = [
          for (final m in _matches!)
            m.id == person.id ? m.copyWith(inCrew: false) : m,
        ];
      });
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Matches',
          trailing: matches == null || matches.isEmpty ? null : Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CountBadge(matches.length),
          ),
        ),
        Expanded(
          child: switch (matches) {
            null when _error != null => ErrorView(error: _error!, onRetry: _retry),
            null => const LoadingView(),
            [] => Center(
                child: SingleChildScrollView(
                  child: EmptyState(
                    title: 'No matches yet',
                    message: 'Likes that go both ways land here.',
                    actions: [
                      FilledButton(
                        onPressed: () => widget.onOpen(AppTab.discover),
                        child: const Text('Start swiping'),
                      ),
                    ],
                  ),
                ),
              ),
            final List<User> list when widget.wide => _wideLayout(list),
            final List<User> list => RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final person = list[i];
                    return SlideIn(
                      key: ValueKey(person.id),
                      delay: Motion.stagger(i, stepMs: 70),
                      child: MatchTile(
                        person: person,
                        crew: _crew,
                        onAddToCrew: switch (_crew) {
                          null => () => widget.onOpen(AppTab.crew),
                          final crew when crew.spotsLeft == 0 => () =>
                              showNotice(context, 'Your crew is full. Tap “Added” on someone to make room.'),
                          _ => () => _addToCrew(person),
                        },
                        onRemoveFromCrew: () => _removeFromCrew(person),
                        onUnmatch: () => _unmatch(person),
                      ),
                    );
                  },
                ),
              ),
          },
        ),
      ],
    );
  }

  VoidCallback _addAction(User person) => switch (_crew) {
        null => () => widget.onOpen(AppTab.crew),
        final crew when crew.spotsLeft == 0 => () => showNotice(context, 'Your crew is full. Tap “Added” on someone to make room.'),
        _ => () => _addToCrew(person),
      };

  /// ↑ and ↓ move through the list, like a mail inbox.
  void _step(List<User> list, int by) {
    final i = list.indexWhere((m) => m.id == _selectedId);
    final next = (i + by).clamp(0, list.length - 1);
    setState(() => _selectedId = list[next].id);
  }

  Widget _wideLayout(List<User> list) {
    final selected = list.firstWhere((m) => m.id == _selectedId, orElse: () => list.first);
    final inCrew = _crew?.hasMember(selected.id) ?? false;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 400,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () => _step(list, 1),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () => _step(list, -1),
            },
            child: Focus(
              autofocus: true,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final person = list[i];
                  return SlideIn(
                    key: ValueKey(person.id),
                    delay: Motion.stagger(i, stepMs: 70),
                    child: MatchTile(
                      person: person,
                      crew: _crew,
                      selected: person.id == selected.id,
                      onSelect: () => setState(() => _selectedId = person.id),
                      onAddToCrew: _addAction(person),
                      onRemoveFromCrew: () => _removeFromCrew(person),
                      onUnmatch: () => _unmatch(person),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: AnimatedSwitcher(
                duration: Motion.of(context, const Duration(milliseconds: 300)),
                switchInCurve: Motion.ease,
                child: SingleChildScrollView(
                  key: ValueKey(selected.id),
                  padding: const EdgeInsets.fromLTRB(48, 24, 48, 32),
                  child: MatchDetails(
                    person: selected,
                    large: true,
                    onUnmatch: () => _unmatch(selected),
                    actions: [
                      inCrew
                          ? FilledButton(
                              onPressed: () => _removeFromCrew(selected),
                              style: FilledButton.styleFrom(backgroundColor: Palette.navy, foregroundColor: Palette.cream),
                              child: const Text('✓ In your crew'),
                            )
                          : FilledButton(onPressed: _addAction(selected), child: const Text('Add to crew')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _retry() {
    setState(() => _error = null);
    _load();
  }
}
