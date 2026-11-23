import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/club.dart';
import '../../models/hub_event.dart';
import '../../models/team_request.dart';
import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import '../../util/when.dart';
import '../people/people_ui.dart';
import '../people/person_screen.dart';
import '../people/search_screen.dart';
import 'club_ui.dart';

/// One club: about, join, its upcoming events and its members.
class ClubScreen extends StatefulWidget {
  const ClubScreen({super.key, required this.clubId});

  final String clubId;

  static Route<void> route(String id) => MaterialPageRoute(builder: (_) => ClubScreen(clubId: id));

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  ClubPage? _page;
  Object? _error;
  var _members = false;
  var _busy = false;
  final _requested = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await context.api.club(widget.clubId);
      if (mounted) setState(() => (_page = page, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _toggleJoin(Club c) async {
    setState(() => _busy = true);
    final session = context.session;
    try {
      session.updateUser(c.joined ? await session.api.leaveClub(c.id) : await session.api.joinClub(c.id));
      if (!mounted) return;
      showNotice(context, c.joined ? 'Left ${c.name}' : 'Joined ${c.name}');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request(User p) async {
    try {
      final result = await context.api.sendRequest(p.id, source: RequestSource.search);
      if (!mounted) return;
      setState(() => _requested.add(p.id));
      announceSent(context, p, result);
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    if (page == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error == null ? const LoadingView() : ErrorView(error: _error!, onRetry: _load),
      );
    }
    final wide = WindowSize.of(context).twoPane;
    final c = page.club;
    final events = _Events(events: page.events);
    final members = _Members(members: page.members, requested: _requested, onRequest: _request);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Cover(club: c, onBack: () => Navigator.of(context).pop()),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Transform.translate(
                    offset: const Offset(0, -44),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 14,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            spacing: 14,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: Palette.desktop, borderRadius: BorderRadius.circular(28)),
                                child: ClubLogo(c, size: wide ? 100 : 80),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    spacing: 2,
                                    children: [
                                      Row(
                                        spacing: 6,
                                        children: [
                                          Flexible(child: Text(c.name, style: AppType.title(size: wide ? 30 : 22))),
                                          if (c.verified) VerifiedBadge(size: wide ? 22 : 18),
                                        ],
                                      ),
                                      Text(
                                        '${clubCategoryLabel(c.category)} · ${plural(c.memberCount, 'member')}',
                                        style: AppType.body(size: 13.5, color: Palette.muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (c.description.isNotEmpty) Text(c.description, style: AppType.body(size: 15, height: 1.5)),
                          Row(
                            spacing: 10,
                            children: [
                              Expanded(
                                flex: 2,
                                child: c.joined
                                    ? OutlinedButton.icon(
                                        onPressed: _busy ? null : () => _toggleJoin(c),
                                        icon: const Icon(Icons.check_rounded, size: 16),
                                        label: const Text('Joined'),
                                      )
                                    : FilledButton.tonal(onPressed: _busy ? null : () => _toggleJoin(c), child: const Text('Join club')),
                              ),
                              Expanded(
                                flex: 3,
                                child: FilledButton.icon(
                                  onPressed: () => Navigator.of(context).push(SearchScreen.route(club: c)),
                                  icon: const Icon(Icons.search_rounded, size: 18),
                                  label: const Text('Find teammates', maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                          ),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 24,
                              children: [Expanded(flex: 6, child: events), Expanded(flex: 5, child: members)],
                            )
                          else ...[
                            SegmentedButton<bool>(
                              segments: [
                                ButtonSegment(value: false, label: Text('Events · ${page.events.length}')),
                                ButtonSegment(value: true, label: Text('Members · ${page.members.length}')),
                              ],
                              selected: {_members},
                              showSelectedIcon: false,
                              onSelectionChanged: (s) => setState(() => _members = s.first),
                            ),
                            _members ? members : events,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.club, required this.onBack});

  final Club club;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = clubColors(club.tone);
    return Container(
      height: 130,
      color: fill,
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.all(4),
      child: IconButton(tooltip: 'Back', onPressed: onBack, icon: Icon(Icons.arrow_back_rounded, color: ink)),
    );
  }
}

class _Events extends StatelessWidget {
  const _Events({required this.events});

  final List<HubEvent> events;

  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text('Upcoming events', style: AppType.body(size: 16, weight: FontWeight.w700)),
        if (events.isEmpty) Text('Nothing planned yet.', style: AppType.body(size: 14, color: Palette.muted)),
        for (final (i, e) in events.indexed)
          Rise(
            delay: Motion.stagger(i),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Palette.window, borderRadius: Frame.radius, border: Frame.border),
              child: Row(
                spacing: 12,
                children: [
                  Container(
                    width: 50,
                    height: 54,
                    decoration: const BoxDecoration(color: Palette.high, borderRadius: Frame.buttonRadius),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_days[e.startsAt.toLocal().weekday - 1], style: AppType.body(size: 10, weight: FontWeight.w500)),
                        Text('${e.startsAt.toLocal().day}', style: AppType.body(size: 19, weight: FontWeight.w700, height: 1.1)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 3,
                      children: [
                        Text(e.title, style: AppType.body(size: 15, weight: FontWeight.w700)),
                        Text('${e.location} · ${scheduleLine(e, now)}', style: AppType.body(size: 12.5, color: Palette.muted)),
                      ],
                    ),
                  ),
                  if (e.isOfficial && e.points > 0) InfoTag('+${e.points}') else if (!e.isOfficial) const InfoTag('Community', color: Palette.high, textColor: Palette.ink),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Members extends StatelessWidget {
  const _Members({required this.members, required this.requested, required this.onRequest});

  final List<User> members;
  final Set<String> requested;
  final ValueChanged<User> onRequest;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 2,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: Text('Members', style: AppType.body(size: 16, weight: FontWeight.w700))),
                Text('Best fit first', style: AppType.body(size: 12.5, color: Palette.muted)),
              ],
            ),
          ),
          if (members.isEmpty) Text('No members yet.', style: AppType.body(size: 14, color: Palette.muted)),
          for (final m in members)
            PersonRow(
              key: ValueKey(m.id),
              person: m,
              onTap: () {
                if (m.handle case final h?) Navigator.of(context).push(PersonScreen.route(h, preview: m));
              },
              trailing: switch (m.relation) {
                Relation.matched => const InfoTag('Matched', color: Palette.navy, textColor: Palette.cream),
                _ when requested.contains(m.id) || m.relation == Relation.sent => const InfoTag('Sent', color: Palette.strip, textColor: Palette.ink),
                _ => OutlinedButton(
                    onPressed: () => onRequest(m),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12)),
                    child: Text(m.isLead ? 'Request · lead' : 'Request'),
                  ),
              },
            ),
        ],
      );
}
