import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/club.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import 'club_screen.dart';
import 'club_ui.dart';

/// Every campus club: yours first, then the rest, with join and leave.
class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const ClubsScreen());

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  List<Club>? _clubs;
  Object? _error;
  String? _category;
  final _query = TextEditingController();
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final clubs = await context.api.clubs();
      if (mounted) setState(() => (_clubs = clubs, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _toggle(Club c) async {
    setState(() => _busy.add(c.id));
    final session = context.session;
    try {
      final user = c.joined ? await session.api.leaveClub(c.id) : await session.api.joinClub(c.id);
      session.updateUser(user);
      if (!mounted) return;
      setState(() {
        _clubs = [
          for (final x in _clubs!) x.id == c.id ? x.copyWith(joined: !c.joined, memberCount: x.memberCount + (c.joined ? -1 : 1)) : x,
        ];
      });
      showNotice(context, c.joined ? 'Left ${c.name}' : 'Joined ${c.name}');
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(c.id));
    }
  }

  void _open(Club c) => Navigator.of(context).push(ClubScreen.route(c.id)).then((_) => _load());

  @override
  Widget build(BuildContext context) {
    final clubs = _clubs;
    final q = _query.text.trim().toLowerCase();
    final filtering = q.isNotEmpty || _category != null;
    final shown = [
      for (final c in clubs ?? <Club>[])
        if ((q.isEmpty || c.name.toLowerCase().contains(q)) && (_category == null || c.category == _category)) c,
    ];
    final mine = [for (final c in clubs ?? <Club>[]) if (c.joined) c];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeader(
                  title: 'Clubs',
                  leading: IconButton(tooltip: 'Back', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
                  trailing: TextButton(onPressed: () => showClubPicker(context).then((_) => _load()), child: const Text('Your clubs')),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _query,
                    decoration: const InputDecoration(
                      hintText: 'Search clubs',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(999))),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    children: [
                      for (final cat in [null, ...Club.categories]) ...[
                        FilterChip(
                          label: Text(cat == null ? 'All' : clubCategoryLabel(cat)),
                          selected: _category == cat,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _category = cat),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: switch (clubs) {
                    null when _error != null => ErrorView(error: _error!, onRetry: _load),
                    null => const LoadingView(),
                    _ => RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          children: [
                            if (!filtering && mine.isNotEmpty) ...[
                              _SectionTitle('Your clubs'),
                              SizedBox(
                                height: 160,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: mine.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                                  itemBuilder: (context, i) => _MineCard(club: mine[i], onTap: () => _open(mine[i])),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            _SectionTitle(filtering ? plural(shown.length, 'club') : 'All clubs'),
                            if (shown.isEmpty) const EmptyState(title: 'No clubs match', message: 'Try another name or category.'),
                            for (final (i, c) in shown.indexed)
                              SlideIn(
                                key: ValueKey(c.id),
                                delay: Motion.stagger(i.clamp(0, 8)),
                                child: _ClubRow(club: c, busy: _busy.contains(c.id), onTap: () => _open(c), onToggle: () => _toggle(c)),
                              ),
                          ],
                        ),
                      ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Text(text, style: AppType.body(size: 14, weight: FontWeight.w700, color: Palette.muted)),
      );
}

class _MineCard extends StatelessWidget {
  const _MineCard({required this.club, required this.onTap});

  final Club club;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Palette.window,
        shape: RoundedRectangleBorder(borderRadius: Frame.radius, side: Frame.side),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                ClubLogo(club),
                Text(club.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.body(size: 15, weight: FontWeight.w700, height: 1.25)),
                Text(
                  club.weekEvents == 0 ? 'Nothing this week' : '${plural(club.weekEvents, 'event')} this week',
                  style: AppType.body(size: 12, color: Palette.muted),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ClubRow extends StatelessWidget {
  const _ClubRow({required this.club, required this.busy, required this.onTap, required this.onToggle});

  final Club club;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: Frame.radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            spacing: 12,
            children: [
              ClubLogo(club, size: 48),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Row(
                      spacing: 5,
                      children: [
                        Flexible(child: Text(club.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 15.5, weight: FontWeight.w500))),
                        if (club.verified) const VerifiedBadge(),
                      ],
                    ),
                    Text(
                      '${clubCategoryLabel(club.category)} · ${plural(club.memberCount, 'member')}',
                      style: AppType.body(size: 12.5, color: Palette.muted),
                    ),
                  ],
                ),
              ),
              club.joined
                  ? FilledButton.icon(
                      onPressed: busy ? null : onToggle,
                      style: FilledButton.styleFrom(backgroundColor: Palette.navy, foregroundColor: Palette.cream),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Joined'),
                    )
                  : OutlinedButton(onPressed: busy ? null : onToggle, child: const Text('Join')),
            ],
          ),
        ),
      );
}
