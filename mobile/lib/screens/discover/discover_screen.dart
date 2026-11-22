import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/deck.dart';
import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import '../shell/app_tab.dart';
import '../matches/person_activity.dart';
import 'match_dialog.dart';
import 'swipe_stack.dart';

/// The ranked swipe deck. Two right swipes make a match.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.onOpen, this.wide = false});

  final OpenTab onOpen;

  /// Wide windows: the card with the full profile beside it.
  final bool wide;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _stack = GlobalKey<SwipeStackState>();
  List<User>? _cards;
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
        final seeMatches = await showMatchDialog(
          context,
          me: me,
          them: result.user ?? person,
        );
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
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _stack.currentState?.swipe(SwipeDirection.left),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _stack.currentState?.swipe(SwipeDirection.right),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'Discover',
              trailing: IconButton(
                tooltip: 'How ranking works',
                onPressed: () => showRankingSheet(context),
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.info_outline_rounded, color: Palette.muted),
              ),
            ),
            Expanded(
              child: Padding(
                padding: widget.wide
                    ? const EdgeInsets.fromLTRB(24, 4, 32, 24)
                    : const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: switch (cards) {
                  null when _error != null => ErrorView(
                    error: _error!,
                    onRetry: _retry,
                  ),
                  null => const LoadingView(message: 'Ranking your best fits…'),
                  [] => _EmptyDeck(
                    onShowPassed: _showPassedAgain,
                    onSeeMatches: () => widget.onOpen(AppTab.matches),
                  ),
                  final List<User> deck =>
                    widget.wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: 440, child: _deckColumn(deck)),
                              const SizedBox(width: 28),
                              Expanded(
                                child: _FitPanel(
                                  key: ValueKey(deck.first.id),
                                  person: deck.first,
                                ),
                              ),
                            ],
                          )
                        : _deckColumn(deck),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deckColumn(List<User> deck) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 14,
    children: [
      Expanded(
        child: SwipeStack(
          key: _stack,
          cards: deck,
          seen: _seen,
          total: _total,
          onSwiped: _onSwiped,
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 28,
        children: [
          _ActionButton(
            label: 'Pass',
            size: 64,
            onPressed: () => _stack.currentState?.swipe(SwipeDirection.left),
            child: const Icon(
              Icons.close_rounded,
              size: 28,
              color: Palette.muted,
            ),
          ),
          Pulse(
            minScale: 0.94,
            period: const Duration(milliseconds: 1200),
            child: _ActionButton(
              label: 'Like',
              size: 72,
              primary: true,
              onPressed: () => _stack.currentState?.swipe(SwipeDirection.right),
              child: const Icon(
                Icons.favorite_rounded,
                size: 32,
                color: Palette.onCrimson,
              ),
            ),
          ),
        ],
      ),
    ],
  );

  void _retry() {
    setState(() => _error = null);
    _load();
  }
}

/// The round Pass and Like buttons under the card.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.size,
    required this.onPressed,
    required this.child,
    this.primary = false,
  });

  final String label;
  final double size;
  final VoidCallback onPressed;
  final Widget child;
  final bool primary;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: primary ? Palette.crimson : Palette.desktop,
      shape: CircleBorder(
        side: primary
            ? BorderSide.none
            : const BorderSide(color: Palette.dashed, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: Center(child: child),
        ),
      ),
    ),
  );
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck({required this.onShowPassed, required this.onSeeMatches});

  final VoidCallback onShowPassed;
  final VoidCallback onSeeMatches;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: EmptyState(
        title: "You've seen everyone",
        message: 'Check back soon.',
        actions: [
          FilledButton(
            onPressed: onShowPassed,
            child: const Text('Show passed people'),
          ),
          OutlinedButton(
            onPressed: onSeeMatches,
            child: const Text('See matches'),
          ),
        ],
      ),
    ),
  );
}

/// Beside the card on wide screens: everything about the person on top, so
/// you can decide without flipping anything.
class _FitPanel extends StatelessWidget {
  const _FitPanel({super.key, required this.person});

  final User person;

  @override
  Widget build(BuildContext context) {
    Widget section(String title, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Text(title, style: AppType.body(size: 16, weight: FontWeight.w700)),
        ...children,
      ],
    );
    Widget chips(List<String> items, Color color, Color text) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final i in items)
          InfoTag(optionLabel(i), color: color, textColor: text),
      ],
    );
    return Rise(
      child: Container(
        decoration: const BoxDecoration(
          color: Palette.window,
          borderRadius: Frame.radius,
          border: Frame.border,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 22,
            children: [
              if (person.tags.isNotEmpty)
                section('Why they fit', [
                  for (final tag in person.tags)
                    Row(
                      spacing: 8,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Palette.gold,
                        ),
                        Expanded(
                          child: Text(tag, style: AppType.body(size: 15)),
                        ),
                      ],
                    ),
                ]),
              if (person.bio.isNotEmpty)
                section('About', [
                  Text(person.bio, style: AppType.body(size: 16, height: 1.55)),
                ]),
              if (person.superpowers.isNotEmpty)
                section('Superpowers', [
                  chips(person.superpowers, Palette.navy, Palette.cream),
                ]),
              if (person.skills.isNotEmpty)
                section('Skills', [
                  chips(person.skills, Palette.strip, Palette.ink),
                ]),
              if (person.interests.isNotEmpty)
                section('Interests', [
                  chips(person.interests, Palette.pink, Palette.onPink),
                ]),
              PersonActivity(userId: person.id),
            ],
          ),
        ),
      ),
    );
  }
}

/// Why people are in this order: the three parts of the fit score.
Future<void> showRankingSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 18,
            children: [
              Text('How we rank', style: AppType.title(size: 22)),
              for (final (i, (label, share, hint)) in const [
                ('Complementary skills', 50, 'They cover what your crew is missing'),
                ('Work style', 30, 'Same schedule, commitment and way of talking'),
                ('Shared interests', 20, 'You care about the same problems'),
              ].indexed)
                Rise(
                  delay: Motion.stagger(i),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(label, style: AppType.body(size: 15, weight: FontWeight.w500))),
                          Text('$share%', style: AppType.body(size: 15, weight: FontWeight.w700)),
                        ],
                      ),
                      ThinProgressBar(value: share / 50),
                      Text(hint, style: AppType.body(size: 13, color: Palette.muted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
