import 'package:material_ui/material_ui.dart';

import '../../models/leaderboard.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../shell/app_tab.dart';

/// Crews ranked by hackathon points, with yours highlighted.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.onOpen, this.wide = false});

  final OpenTab onOpen;

  /// Wide windows: hackathons as tabs, the table beside the podium.
  final bool wide;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  var _hackathonId = Hackathon.currentId;
  Leaderboard? _board;
  HackathonList? _hackathons;
  Object? _error;

  /// Bumped on every switch so the podium and rows animate in again.
  var _run = 0;

  /// Rows below the podium start collapsed to four; your crew stays pinned.
  var _showAll = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadHackathons();
  }

  Future<void> _load() async {
    final id = _hackathonId;
    try {
      final board = await context.api.leaderboard(id);
      if (mounted && id == _hackathonId) {
        setState(() {
          _board = board;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && id == _hackathonId) setState(() => _error = e);
    }
  }

  /// The switcher's list. Quietly skipped if it fails; the sheet retries.
  Future<void> _loadHackathons() async {
    try {
      final list = await context.api.hackathons();
      if (mounted) setState(() => _hackathons = list);
    } catch (_) {}
  }

  void _switchTo(String id) {
    if (id == _hackathonId) return;
    setState(() {
      _hackathonId = id;
      _board = null;
      _error = null;
      _showAll = false;
      _run++;
    });
    _load();
  }

  Future<void> _openSwitcher() async {
    if (_hackathons == null) await _loadHackathons();
    if (!mounted) return;
    final list = _hackathons;
    if (list == null) return showNotice(context, "Couldn't load other hackathons");
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HackathonSheet(list: list, selectedId: _hackathonId),
    );
    if (picked != null) _switchTo(picked);
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    final name = board?.title ??
        _hackathons?.hackathons.where((h) => h.id == _hackathonId).firstOrNull?.name ??
        'Live hackathon';
    final status = board?.status ?? HackathonStatus.live;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Semantics(header: true, child: Text('Leaderboard', style: AppType.title(size: 24))),
              if (widget.wide && _hackathons != null)
                _HackathonTabs(list: _hackathons!, selectedId: _hackathonId, onPick: _switchTo)
              else
                _SwitcherButton(name: name, status: status, onTap: _openSwitcher),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.of(context, const Duration(milliseconds: 250)),
            switchInCurve: Motion.ease,
            switchOutCurve: Motion.exit,
            child: KeyedSubtree(
              key: ValueKey((_run, board == null)),
              child: board == null
                  ? (_error == null
                      ? const LoadingView(message: 'Counting points…')
                      : ErrorView(
                          error: _error!,
                          onRetry: () {
                            setState(() => _error = null);
                            _load();
                          },
                        ))
                  : board.status == HackathonStatus.upcoming
                      ? _Upcoming(startsAt: board.startsAt)
                      : widget.wide
                          ? _wideBoard(board)
                          : RefreshIndicator(onRefresh: _load, child: _boardList(board)),
            ),
          ),
        ),
      ],
    );
  }

  /// The full table on the left; the podium and your standing on the right.
  Widget _wideBoard(Leaderboard board) {
    final mine = board.myCrew;
    final rows = board.crews.skip(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 32, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: Palette.window, borderRadius: Frame.radius, border: Frame.border),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _TableRow(header: true, cells: ['RANK', 'CREW', 'COMPLETED', 'POINTS']),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(child: Text(board.crews.isEmpty ? 'No crews yet' : 'Only the top three so far', style: AppType.body(color: Palette.muted)))
                        : ListView.builder(
                            itemCount: rows.length,
                            itemBuilder: (context, i) => SlideIn(
                              key: ValueKey(rows[i].id),
                              delay: const Duration(milliseconds: 300) + Motion.stagger(i, stepMs: 50),
                              child: _TableRow(
                                mine: rows[i].id == board.myCrewId,
                                cells: ['${rows[i].rank}', rows[i].name, '${rows[i].completed}', '${rows[i].points}'],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 440,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    decoration: const BoxDecoration(color: Palette.window, borderRadius: Frame.radius, border: Frame.border),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('Top 3', style: AppType.body(size: 16, weight: FontWeight.w700))),
                            Text(board.status == HackathonStatus.live ? 'Updating live' : 'Final results', style: AppType.body(size: 13, color: Palette.muted)),
                          ],
                        ),
                        const Spacer(),
                        if (board.crews.isNotEmpty) _Podium(crews: board.crews.take(3).toList(), myCrewId: board.myCrewId),
                      ],
                    ),
                  ),
                ),
                if (mine != null) _Standing(board: board, mine: mine),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _boardList(Leaderboard board) {
    final rest = board.crews.skip(3).toList();
    final mine = board.myCrew;
    const collapsed = 4;
    final shown = _showAll ? rest : rest.take(collapsed).toList();
    final pinned = !_showAll && mine != null && mine.rank > 3 + collapsed;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (board.myCrewId == null && board.status == HackathonStatus.live)
          _JoinPrompt(onTap: () => widget.onOpen(AppTab.crew)),
        if (board.crews.isEmpty)
          const EmptyState(title: 'No crews yet', message: 'Crews show up as they form.')
        else
          _Podium(crews: board.crews.take(3).toList(), myCrewId: board.myCrewId),
        const SizedBox(height: 14),
        for (final (i, crew) in shown.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SlideIn(
              key: ValueKey(crew.id),
              delay: const Duration(milliseconds: 600) + Motion.stagger(i, stepMs: 70),
              child: _RankLine(crew: crew, mine: crew.id == board.myCrewId),
            ),
          ),
        if (pinned) ...[
          Center(child: Text('···', style: AppType.body(size: 18, color: Palette.muted))),
          const SizedBox(height: 6),
          SlideIn(
            delay: const Duration(milliseconds: 900),
            child: _RankLine(crew: mine, mine: true),
          ),
        ],
        if (rest.length > collapsed)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(_showAll ? 'Show less' : 'Show all ${board.crews.length}'),
            ),
          ),
      ],
    );
  }
}

/// "● MERNOVA X 2026 ▾": which hackathon you're looking at; opens the list.
class _SwitcherButton extends StatelessWidget {
  const _SwitcherButton({required this.name, required this.status, required this.onTap});

  final String name;
  final HackathonStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dot = DecoratedBox(
      decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle),
      child: const SizedBox.square(dimension: 8),
    );
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.only(left: 14, right: 10),
        textStyle: AppType.body(size: 14, weight: FontWeight.w500),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (status == HackathonStatus.live) Pulse(child: dot) else dot,
          Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.expand_more_rounded, size: 20),
        ],
      ),
    );
  }
}

Color _statusColor(HackathonStatus status) => switch (status) {
      HackathonStatus.live => Palette.crimson,
      HackathonStatus.upcoming => Palette.navy,
      HackathonStatus.ended => Palette.dashed,
    };

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _dayMonth(DateTime d) => '${_months[d.toLocal().month - 1]} ${d.toLocal().day}';
String _monthYear(DateTime d) => '${_months[d.toLocal().month - 1]} ${d.toLocal().year}';

/// The list of hackathons, with your record across them on top. Picking one
/// closes the sheet with its id.
class _HackathonSheet extends StatelessWidget {
  const _HackathonSheet({required this.list, required this.selectedId});

  final HackathonList list;
  final String selectedId;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Hackathons', style: AppType.title(size: 20)),
              ),
              Row(
                spacing: 8,
                children: [
                  for (final (value, label) in [
                    ('${list.attended}', 'Hackathons'),
                    (list.bestFinish == null ? '–' : '#${list.bestFinish}', 'Best finish'),
                    ('${list.totalPoints}', 'Total pts'),
                  ])
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Palette.strip, borderRadius: Frame.radius),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(value, style: AppType.body(size: 22, weight: FontWeight.w700, height: 1.2)),
                            Text(label, style: AppType.body(size: 12, color: Palette.muted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                children: [
                  for (final (i, h) in list.hackathons.indexed)
                    Rise(
                      delay: Duration(milliseconds: 120 + 50 * i),
                      child: _HackathonTile(
                        hackathon: h,
                        selected: h.id == selectedId,
                        onTap: () => Navigator.of(context).pop(h.id),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _HackathonTile extends StatelessWidget {
  const _HackathonTile({required this.hackathon, required this.selected, required this.onTap});

  final Hackathon hackathon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final h = hackathon;
    final rank = h.myRank == null ? 'No crew' : '#${h.myRank} of ${h.crewCount}';
    final sub = switch (h.status) {
      HackathonStatus.live => 'Live · $rank',
      HackathonStatus.ended => '${h.endedAt == null ? 'Ended' : _monthYear(h.endedAt!)} · $rank',
      HackathonStatus.upcoming => h.startsAt == null ? 'Upcoming' : 'Starts ${_dayMonth(h.startsAt!)}',
    };
    final initials = h.name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    final (fill, onFill) = switch (h.status) {
      HackathonStatus.live => (Palette.crimson, Palette.onCrimson),
      HackathonStatus.upcoming => (Palette.navy, Palette.cream),
      HackathonStatus.ended => (Palette.high, Palette.ink),
    };
    return Material(
      color: selected ? Palette.strip : Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: Frame.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              spacing: 14,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: fill, borderRadius: Frame.buttonRadius),
                  child: Text(initials, style: AppType.body(size: 13, weight: FontWeight.w700, color: onFill)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(h.name, style: AppType.body(size: 16, weight: FontWeight.w500)),
                      Text(sub, style: AppType.body(size: 13, color: Palette.muted)),
                    ],
                  ),
                ),
                if (selected) const Icon(Icons.check_rounded, size: 22, color: Palette.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An upcoming hackathon has no board yet.
class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.startsAt});

  final DateTime? startsAt;

  @override
  Widget build(BuildContext context) => Center(
        child: Rise(
          offset: -18,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 14,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(color: Palette.navy, borderRadius: BorderRadius.all(Radius.circular(28))),
                child: const Icon(Icons.calendar_month_rounded, size: 40, color: Palette.cream),
              ),
              Text(startsAt == null ? 'Not started yet' : 'Starts ${_dayMonth(startsAt!)}', style: AppType.title(size: 22)),
            ],
          ),
        ),
      );
}

/// The top three on blocks: 2nd, 1st, 3rd. The blocks grow up, then the
/// crews drop in, and the leader's crown sways.
class _Podium extends StatelessWidget {
  const _Podium({required this.crews, required this.myCrewId});

  final List<RankedCrew> crews;
  final String? myCrewId;

  @override
  Widget build(BuildContext context) {
    final order = [
      if (crews.length > 1) (crews[1], 84.0, Palette.gold, Palette.onGold, 150),
      (crews[0], 116.0, Palette.crimson, Palette.onCrimson, 300),
      if (crews.length > 2) (crews[2], 64.0, Palette.navy, Palette.cream, 0),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 10,
      children: [
        for (final (crew, height, fill, onFill, delay) in order)
          Expanded(
            child: Column(
              spacing: 6,
              children: [
                Rise(
                  delay: Duration(milliseconds: 550 + delay),
                  offset: -18,
                  child: Column(
                    spacing: 6,
                    children: [
                      if (crew.rank == 1)
                        const Pulse(
                          minScale: 0.9,
                          period: Duration(milliseconds: 1200),
                          child: Icon(Icons.workspace_premium_rounded, size: 26, color: Palette.gold),
                        ),
                      Container(
                        padding: EdgeInsets.all(crew.rank == 1 ? 3 : 0),
                        decoration: const BoxDecoration(color: Palette.gold, shape: BoxShape.circle),
                        child: Avatar(
                          url: '',
                          name: crew.name,
                          size: crew.rank == 1 ? 60 : 52,
                          background: crew.rank == 1 ? Palette.pink : Palette.high,
                        ),
                      ),
                      Text(
                        crew.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: AppType.body(size: 14, weight: crew.rank == 1 ? FontWeight.w700 : FontWeight.w500),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 6,
                        children: [
                          CountUp(crew.points, suffix: ' pts', style: AppType.body(size: 13, color: Palette.muted)),
                          if (crew.id == myCrewId) const InkBadge('You'),
                        ],
                      ),
                    ],
                  ),
                ),
                GrowUp(
                  delay: Duration(milliseconds: delay),
                  child: Container(
                    height: height,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    alignment: Alignment.center,
                    child: Text('${crew.rank}', style: AppType.title(size: crew.rank == 1 ? 30 : 26, color: onFill)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A crew below the podium: rank, initials, counts and points.
class _RankLine extends StatelessWidget {
  const _RankLine({required this.crew, required this.mine});

  final RankedCrew crew;
  final bool mine;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? Palette.pink : Palette.window,
          borderRadius: Frame.radius,
          border: mine ? Border.all(color: Palette.gold, width: 1.5) : null,
        ),
        child: Row(
          spacing: 12,
          children: [
            SizedBox(width: 22, child: Text('${crew.rank}', style: AppType.body(size: 15, weight: FontWeight.w700, color: Palette.muted))),
            Avatar(url: '', name: crew.name, size: 36, background: Palette.high),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    spacing: 6,
                    children: [
                      Flexible(child: Text(crew.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 15, weight: FontWeight.w500))),
                      if (mine) const InkBadge('You'),
                    ],
                  ),
                ],
              ),
            ),
            Text('${crew.points}', style: AppType.body(size: 15, weight: FontWeight.w700)),
          ],
        ),
      );
}

class _JoinPrompt extends StatelessWidget {
  const _JoinPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: const BoxDecoration(color: Palette.strip, borderRadius: Frame.radius),
    padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
    child: Row(
      children: [
        const Expanded(
          child: Text('No crew yet', style: TextStyle(fontSize: 14)),
        ),
        TextButton(onPressed: onTap, child: const Text('Form a crew')),
      ],
    ),
  );
}

/// One row of the wide ranking table.
class _TableRow extends StatelessWidget {
  const _TableRow({required this.cells, this.header = false, this.mine = false});

  final List<String> cells;
  final bool header;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final style = header
        ? AppType.body(size: 12, weight: FontWeight.w500, color: Palette.muted).copyWith(letterSpacing: 0.8)
        : AppType.body(size: 15);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: mine ? Color.alphaBlend(Palette.gold.withValues(alpha: 0.22), Palette.window) : null,
        border: const Border(bottom: Frame.side),
      ),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(cells[0], style: header ? style : style.copyWith(fontWeight: FontWeight.w700, color: Palette.muted))),
          Expanded(
            child: Row(
              spacing: 10,
              children: [
                if (!header) Avatar(url: '', name: cells[1], size: 32, background: mine ? Palette.gold : Palette.high),
                Flexible(child: Text(cells[1], maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
                if (mine) const InkBadge('You'),
              ],
            ),
          ),
          SizedBox(width: 120, child: Text(cells[2], style: header ? style : style.copyWith(color: Palette.muted))),
          SizedBox(width: 80, child: Text(cells[3], textAlign: TextAlign.right, style: header ? style : style.copyWith(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

/// Your crew's place, with how far you are from the crew above.
class _Standing extends StatelessWidget {
  const _Standing({required this.board, required this.mine});

  final Leaderboard board;
  final RankedCrew mine;

  @override
  Widget build(BuildContext context) {
    final crews = board.crews;
    final i = crews.indexWhere((c) => c.id == mine.id);
    final above = i > 0 ? crews[i - 1] : null;
    final below = i + 1 < crews.length ? crews[i + 1] : null;
    final leader = crews.first;
    final line = above == null
        ? (below == null ? 'Top of the board' : '${mine.points - below.points} pts ahead of ${below.name}')
        : '${above.points - mine.points} pts behind ${above.name} (#${above.rank})';
    final progress = leader.points == 0 ? 1.0 : (mine.points / leader.points).clamp(0.05, 1.0);
    return Rise(
      delay: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Palette.pink, borderRadius: Frame.radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              spacing: 16,
              children: [
                Text('#${mine.rank}', style: AppType.title(size: 40, color: Palette.onPink)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mine.name, style: AppType.body(size: 16, weight: FontWeight.w700, color: Palette.onPink)),
                      Text(board.status == HackathonStatus.live ? 'Your crew · live' : 'Your crew · final', style: AppType.body(size: 13, color: Palette.onPink)),
                    ],
                  ),
                ),
                CountUp(mine.points, suffix: ' pts', style: AppType.body(size: 20, weight: FontWeight.w700, color: Palette.onPink)),
              ],
            ),
            ThinProgressBar(value: progress, color: Palette.crimson),
            Text(line, style: AppType.body(size: 13, weight: FontWeight.w500, color: Palette.onPink)),
          ],
        ),
      ),
    );
  }
}

/// The hackathons as tabs, for wide windows.
class _HackathonTabs extends StatelessWidget {
  const _HackathonTabs({required this.list, required this.selectedId, required this.onPick});

  final HackathonList list;
  final String selectedId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(color: Palette.strip, borderRadius: Frame.pill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final h in list.hackathons)
              Semantics(
                button: true,
                selected: h.id == selectedId,
                child: InkWell(
                  borderRadius: Frame.pill,
                  onTap: () => onPick(h.id),
                  child: AnimatedContainer(
                    duration: Motion.of(context, const Duration(milliseconds: 250)),
                    curve: Motion.standard,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: h.id == selectedId ? Palette.gold : Colors.transparent, borderRadius: Frame.pill),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(color: _statusColor(h.status), shape: BoxShape.circle),
                          child: const SizedBox.square(dimension: 8),
                        ),
                        Text(h.name, style: AppType.body(size: 14, weight: FontWeight.w500, color: h.id == selectedId ? Palette.onGold : Palette.ink)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
