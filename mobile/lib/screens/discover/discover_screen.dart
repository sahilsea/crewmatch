import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/deck.dart';
import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../shell/app_tab.dart';
import 'match_dialog.dart';
import 'swipe_stack.dart';

/// The ranked swipe deck. Two right swipes make a match.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.onOpen});

  final OpenTab onOpen;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _stack = GlobalKey<SwipeStackState>();
  List<User>? _cards;
  var _crewMode = false;
  var _seen = 0;
  var _total = 0;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final deck = await context.api.deck();
      if (!mounted) return;
      setState(() {
        _cards = [...deck.cards];
        _crewMode = deck.scoredAgainstCrew;
        _seen = 0;
        _total = deck.cards.length;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _onSwiped(User person, SwipeDirection direction) async {
    setState(() {
      _cards!.removeAt(0);
      _seen++;
    });
    final session = context.session;
    try {
      final result = await session.api.swipe(person.id, direction);
      if (result.match && mounted) {
        final me = session.user!;
        session.updateUser(me.copyWith(matchCount: me.matchCount + 1));
        final seeMatches = await showMatchDialog(context, me: me, them: result.user ?? person);
        if (seeMatches) widget.onOpen(AppTab.matches);
      }
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    }
    if (mounted && _cards!.isEmpty) _load();
  }

  Future<void> _showPassedAgain() async {
    setState(() => _cards = null);
    try {
      await context.api.resetPasses();
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    }
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    final hasCards = cards != null && cards.isNotEmpty;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _stack.currentState?.swipe(SwipeDirection.left),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _stack.currentState?.swipe(SwipeDirection.right),
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: RetroWindow(
            title: 'Discover',
            inset: false,
            fill: true,
            footer: hasCards
                ? SegmentRow(
                    segments: [
                      Segment(
                        label: 'Pass',
                        glyph: Glyph.cross,
                        color: Palette.window,
                        onPressed: () => _stack.currentState?.swipe(SwipeDirection.left),
                      ),
                      Segment(
                        label: 'Like',
                        glyph: Glyph.heart,
                        color: Palette.pink,
                        onPressed: () => _stack.currentState?.swipe(SwipeDirection.right),
                      ),
                    ],
                  )
                : null,
            status: hasCards
                ? (_crewMode ? 'Ranked for your crew · best fits first' : 'Best fits first · drag or tap')
                : null,
            child: switch (cards) {
              null when _error != null => ErrorView(error: _error!, onRetry: _retry),
              null => const LoadingView(message: 'Ranking your best fits…'),
              [] => _EmptyDeck(
                  onShowPassed: _showPassedAgain,
                  onSeeMatches: () => widget.onOpen(AppTab.matches),
                ),
              final List<User> deck => Padding(
                  padding: const EdgeInsets.all(10),
                  child: SwipeStack(
                    key: _stack,
                    cards: deck,
                    seen: _seen,
                    total: _total,
                    onSwiped: _onSwiped,
                  ),
                ),
            },
          ),
        ),
      ),
    );
  }

  void _retry() {
    setState(() => _error = null);
    _load();
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck({required this.onShowPassed, required this.onSeeMatches});

  final VoidCallback onShowPassed;
  final VoidCallback onSeeMatches;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: EmptyState(
            title: "You've seen everyone for now",
            message: 'New students join all the time. Check back soon, '
                'or give the people you passed another look.',
            actions: [
              FilledButton(onPressed: onShowPassed, child: const Text('Show passed people')),
              OutlinedButton(onPressed: onSeeMatches, child: const Text('See matches')),
            ],
          ),
        ),
      );
}
