import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/crew.dart';
import '../../models/hub_event.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/parallel.dart';
import '../shell/app_tab.dart';
import 'check_in_dialog.dart';
import 'create_event_screen.dart';
import 'event_card.dart';
import 'submit_dialog.dart';

/// The hackathon hub: events to go to and challenges to take on, as a crew.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.onOpen, this.onBack});

  final OpenTab onOpen;

  /// Shows a back arrow, when opened from the Posts tab.
  final VoidCallback? onBack;

  /// All events and challenges as a page of its own, over the Posts tab.
  static Route<void> route(OpenTab onOpen) => MaterialPageRoute(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: EventsScreen(
              onBack: () => Navigator.of(context).pop(),
              onOpen: (tab) {
                Navigator.of(context).pop();
                onOpen(tab);
              },
            ),
          ),
        ),
      );

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<HubEvent>? _events;
  Crew? _crew;
  var _kind = EventKind.event;
  Object? _error;

  /// The card with a request in flight.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.api;
    try {
      final (events, crew) = await waitBoth(api.events(), api.myCrew());
      if (!mounted) return;
      setState(() {
        _events = events;
        _crew = crew;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _replace(HubEvent updated) => setState(() {
    _events = [for (final e in _events!) e.id == updated.id ? updated : e];
  });

  /// Runs a join or leave, swaps in the updated card and says what happened.
  Future<void> _run(
    HubEvent event,
    Future<HubEvent> Function() request,
    String done,
  ) async {
    setState(() => _busyId = event.id);
    try {
      final updated = await request();
      if (!mounted) return;
      _replace(updated);
      showNotice(context, done);
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _join(HubEvent e) => _run(
    e,
    () => context.api.joinEvent(e.id),
    e.isChallenge ? 'Challenge accepted' : 'Your crew is going',
  );

  void _leave(HubEvent e) =>
      _run(e, () => context.api.leaveEvent(e.id), 'Left ${e.title}');

  Future<void> _checkIn(HubEvent e) async {
    final result = await showCheckInDialog(context, e);
    if (!mounted) return;
    // Swiped away after a successful check-in: reload to pick it up.
    if (result == null) return _load();
    _replace(result.event);
    showNotice(
      context,
      'Checked in · +${result.pointsAwarded} pts for ${_crew?.name ?? 'your crew'}',
    );
    _refreshCrew();
  }

  /// Picks up the crew's new points and rank after a check-in.
  Future<void> _refreshCrew() async {
    try {
      final crew = await context.api.myCrew();
      if (mounted) setState(() => _crew = crew);
    } on ApiException {
      // The strip just keeps the old score until the next refresh.
    }
  }

  Future<void> _submit(HubEvent e) async {
    final updated = await showSubmitDialog(context, e);
    if (updated == null || !mounted) return;
    _replace(updated);
    showNotice(context, 'Sent for review');
  }

  Future<void> _create() async {
    final made = await Navigator.of(context).push(CreateEventScreen.route());
    if (!mounted) return;
    if (made != null) setState(() => _kind = made.kind);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    final shown = [
      for (final e in events ?? const <HubEvent>[])
        if (e.kind == _kind) e,
    ];
    final live = shown.where((e) => e.state == EventState.live).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Events & challenges',
          leading: widget.onBack == null
              ? null
              : IconButton(
                  tooltip: 'Back',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded, color: Palette.ink),
                ),
          subtitle: live > 0 ? '$live live now' : null,
          trailing: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Create'),
            ),
          ),
        ),
        Expanded(
          child: events == null
            ? (_error == null
                  ? const LoadingView()
                  : ErrorView(error: _error!, onRetry: _retry))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                    child: FilterTabs<EventKind>(
                      tabs: {
                        EventKind.event:
                            'Events ${_count(events, EventKind.event)}',
                        EventKind.challenge:
                            'Challenges ${_count(events, EventKind.challenge)}',
                      },
                      selected: _kind,
                      onChanged: (kind) => setState(() => _kind = kind),
                    ),
                  ),
                  if (_crew case final crew?)
                    _CrewStrip(
                      crew: crew,
                      onTap: () => widget.onOpen(AppTab.ranks),
                    )
                  else
                    _NoCrewBanner(onTap: () => widget.onOpen(AppTab.crew)),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: shown.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                EmptyState(
                                  title: 'Nothing here yet',
                                  message: 'Pull to refresh.',
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: shown.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final e = shown[i];
                                return Rise(
                                  key: ValueKey(e.id),
                                  delay: Motion.stagger(i),
                                  child: EventCard(
                                    event: e,
                                    hasCrew: _crew != null,
                                    busy: _busyId == e.id,
                                    onJoin: () => _join(e),
                                    onLeave: () => _leave(e),
                                    onCheckIn: () => _checkIn(e),
                                    onSubmit: () => _submit(e),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
        ),
      ],
    );
  }

  static int _count(List<HubEvent> events, EventKind kind) =>
      events.where((e) => e.kind == kind).length;

  void _retry() {
    setState(() => _error = null);
    _load();
  }
}

/// Your crew's name, points and rank, linking to the leaderboard.
class _CrewStrip extends StatelessWidget {
  const _CrewStrip({required this.crew, required this.onTap});

  final Crew crew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
    child: Material(
      color: Palette.strip,
      shape: const RoundedRectangleBorder(borderRadius: Frame.buttonRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            spacing: 10,
            children: [
              const Icon(Icons.groups_outlined, size: 20, color: Palette.muted),
              Expanded(
                child: Text(
                  '${crew.name} · ${crew.points} pts${crew.rank == null ? '' : ' · #${crew.rank}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(size: 14, weight: FontWeight.w500),
                ),
              ),
              Text('Rank', style: AppType.body(size: 14, weight: FontWeight.w500, color: Palette.link)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Events are for crews: explains that and links to the Crew tab.
class _NoCrewBanner extends StatelessWidget {
  const _NoCrewBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    decoration: const BoxDecoration(color: Palette.dark, borderRadius: Frame.radius),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        const Label('No crew yet', color: Palette.darkMuted),
        Text('Events are for crews.', style: AppType.body(size: 15, color: Palette.cream)),
        FilledButton(onPressed: onTap, child: const Text('Form a crew')),
      ],
    ),
  );
}
