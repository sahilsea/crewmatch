import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/admin_stats.dart';
import '../../models/hub_event.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import '../../util/parallel.dart';
import '../../util/when.dart';
import 'admin_common.dart';

/// The organiser's home: the numbers, what needs review, and the live
/// check-in code ready to put on a projector.
class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({
    super.key,
    required this.wide,
    required this.onOpen,
    required this.onNewEvent,
    required this.onChanged,
  });

  final bool wide;
  final OpenAdminTab onOpen;
  final VoidCallback onNewEvent;

  /// Something was reviewed: the shell refreshes its badge.
  final VoidCallback onChanged;

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  AdminStats? _stats;
  List<HubEvent>? _events;
  Object? _error;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.api;
    try {
      final (stats, events) = await waitBoth(api.adminStats(), api.adminEvents());
      if (mounted) {
        setState(() {
          _stats = stats;
          _events = events;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _decide(ReviewItem item, Decision decision) async {
    setState(() => _busy.add(item.id));
    try {
      final message = await decide(context, item, decision, item.suggestedPoints);
      if (!mounted) return;
      showNotice(context, message);
      widget.onChanged();
      await _load();
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final events = _events;
    final header = AdminHeader(
      title: 'Admin',
      trailing: FilledButton.icon(
        onPressed: widget.onNewEvent,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('New event'),
      ),
    );
    if (stats == null || events == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(child: _error == null ? const LoadingView() : ErrorView(error: _error!, onRetry: _load)),
        ],
      );
    }
    final queue = reviewItemsOf(events);
    final live = [
      for (final e in events)
        if (e.state == EventState.live && !e.isChallenge && e.checkinCode != null) e,
    ];
    final tiles = _Tiles(stats: stats, liveCount: live.length, waiting: queue.length, onOpen: widget.onOpen);
    final review = _ReviewList(items: queue, busy: _busy, onDecide: _decide, onOpenAll: () => widget.onOpen(AdminTab.review));
    final side = [
      if (live.isNotEmpty) _LiveCode(events: live),
      _Roles(stats: stats),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          header,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Rise(child: tiles),
                if (widget.wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 20,
                    children: [
                      Expanded(flex: 135, child: Rise(delay: Motion.stagger(2), child: review)),
                      Expanded(
                        flex: 100,
                        child: Column(
                          spacing: 16,
                          children: [for (final (i, w) in side.indexed) SlideIn(delay: Motion.stagger(i + 2), child: w)],
                        ),
                      ),
                    ],
                  )
                else ...[
                  if (live.isNotEmpty) Rise(delay: Motion.stagger(1), child: side.first),
                  Rise(delay: Motion.stagger(2), child: review),
                  Rise(delay: Motion.stagger(3), child: side.last),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.stats, required this.liveCount, required this.waiting, required this.onOpen});

  final AdminStats stats;
  final int liveCount;
  final int waiting;
  final OpenAdminTab onOpen;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Tile(label: 'Students', value: stats.students, sub: '${stats.crews} crews', onTap: null),
      _Tile(label: 'Events', value: stats.events + stats.challenges, sub: '${stats.challenges} challenges', onTap: () => onOpen(AdminTab.events)),
      _Tile(
        label: 'Live now',
        value: liveCount,
        sub: liveCount == 0 ? 'Nothing running' : 'Codes below',
        color: Palette.pink,
        ink: Palette.onPink,
        onTap: () => onOpen(AdminTab.events),
      ),
      _Tile(
        label: 'Waiting for review',
        value: waiting,
        sub: waiting == 0 ? 'All clear' : 'Links and events',
        color: Palette.crimson,
        ink: Palette.onCrimson,
        onTap: () => onOpen(AdminTab.review),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final perRow = c.maxWidth >= 700 ? 4 : 2;
        final width = (c.maxWidth - 12 * (perRow - 1)) / perRow;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.sub,
    required this.onTap,
    this.color = Palette.window,
    this.ink = Palette.ink,
  });

  final String label;
  final int value;
  final String sub;
  final VoidCallback? onTap;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: Frame.radius,
          side: color == Palette.window ? Frame.side : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(label, style: AppType.body(size: 13, weight: FontWeight.w500, color: ink)),
                CountUp(value, style: AppType.title(size: 32, color: ink)),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13, color: ink)),
              ],
            ),
          ),
        ),
      );
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({required this.items, required this.busy, required this.onDecide, required this.onOpenAll});

  final List<ReviewItem> items;
  final Set<String> busy;
  final Future<void> Function(ReviewItem, Decision) onDecide;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) => AdminPanel(
        padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Needs your review', style: AppType.body(size: 17, weight: FontWeight.w700))),
                TextButton(onPressed: onOpenAll, child: const Text('Open review ›')),
              ],
            ),
            SmoothSize(
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        spacing: 8,
                        children: [
                          PopIn(
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(color: Palette.gold, shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded, color: Palette.onGold),
                            ),
                          ),
                          Text('All caught up', style: AppType.body(size: 16, weight: FontWeight.w700)),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        for (final item in items.take(4))
                          _QueueRow(
                            key: ValueKey(item.id),
                            item: item,
                            busy: busy.contains(item.id),
                            onApprove: () => onDecide(item, Decision.approve),
                            onReject: () => onDecide(item, item.isEntry ? Decision.reject : Decision.keep),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      );
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({super.key, required this.item, required this.busy, required this.onApprove, required this.onReject});

  final ReviewItem item;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(top: Frame.side)),
        child: Row(
          spacing: 10,
          children: [
            Avatar(url: '', name: item.who, size: 40, background: item.isEntry ? Palette.pink : Palette.gold),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(item.event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 15, weight: FontWeight.w500)),
                  Text(
                    '${item.who} · ${item.isEntry ? 'Entry' : 'Event proposal'} · +${item.suggestedPoints}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(size: 13, color: Palette.muted),
                  ),
                ],
              ),
            ),
            IconButton.outlined(
              tooltip: item.isEntry ? 'Send back' : 'Keep as community',
              onPressed: busy ? null : onReject,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
            IconButton.filled(
              tooltip: 'Approve +${item.suggestedPoints}',
              onPressed: busy ? null : onApprove,
              style: IconButton.styleFrom(backgroundColor: Palette.crimson, foregroundColor: Palette.onCrimson),
              icon: const Icon(Icons.check_rounded, size: 18),
            ),
          ],
        ),
      );
}

/// The code for a live event, with a projector view.
class _LiveCode extends StatefulWidget {
  const _LiveCode({required this.events});

  final List<HubEvent> events;

  @override
  State<_LiveCode> createState() => _LiveCodeState();
}

class _LiveCodeState extends State<_LiveCode> {
  var _index = 0;

  void _project(HubEvent e) => showDialog<void>(
        context: context,
        useSafeArea: false,
        builder: (context) => Dialog.fullscreen(
          backgroundColor: Palette.navy,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 28,
                children: [
                  Text(
                    '${e.title} · +${e.points} pts',
                    textAlign: TextAlign.center,
                    style: AppType.title(size: 26, color: Palette.cream),
                  ),
                  FittedBox(child: CodeTiles(e.checkinCode!, size: 170, color: Palette.gold, textColor: Palette.onGold)),
                  Text('CrewMatch › Posts › Check in', style: AppType.body(size: 20, color: Palette.cream)),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(foregroundColor: Palette.cream, side: const BorderSide(color: Palette.cream)),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final events = widget.events;
    final e = events[_index.clamp(0, events.length - 1)];
    final checked = e.entries.where((x) => x.entry.status == EntryStatus.completed).length;
    return AdminPanel(
      color: Palette.navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            spacing: 8,
            children: [
              const Pulse(child: SizedBox.square(dimension: 8, child: DecoratedBox(decoration: BoxDecoration(color: Palette.gold, shape: BoxShape.circle)))),
              Expanded(child: Text('Live check-in code', style: AppType.body(size: 15, weight: FontWeight.w700, color: Palette.cream))),
              OutlinedButton.icon(
                onPressed: () => _project(e),
                style: OutlinedButton.styleFrom(foregroundColor: Palette.cream, side: const BorderSide(color: Palette.darkMuted)),
                icon: const Icon(Icons.fullscreen_rounded, size: 18),
                label: const Text('Project'),
              ),
            ],
          ),
          if (events.length > 1)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, ev) in events.indexed)
                  ChoiceChip(
                    label: Text(ev.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    selected: i == _index,
                    onSelected: (_) => setState(() => _index = i),
                  ),
              ],
            )
          else
            Text(e.title, style: AppType.body(size: 14, color: Palette.cream)),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: CodeTiles(e.checkinCode!, size: 64, color: Palette.gold, textColor: Palette.onGold),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  e.capacity == null ? '${plural(checked, 'crew')} checked in' : '$checked of ${e.capacity} crews checked in',
                  style: AppType.body(size: 13, color: Palette.cream),
                ),
              ),
              Text('till ${clock(e.endsAt.toLocal())}', style: AppType.body(size: 13, color: Palette.cream)),
            ],
          ),
          if (e.capacity case final cap?) ThinProgressBar(value: checked / cap),
        ],
      ),
    );
  }
}

class _Roles extends StatelessWidget {
  const _Roles({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final roles = stats.byRole.take(6).toList();
    final top = roles.isEmpty ? 1 : roles.first.count;
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text('Students by role', style: AppType.body(size: 15, weight: FontWeight.w700)),
          for (final r in roles)
            Row(
              spacing: 10,
              children: [
                SizedBox(width: 84, child: Text(optionLabel(r.role), style: AppType.body(size: 13))),
                Expanded(child: ThinProgressBar(value: r.count / top)),
                SizedBox(width: 24, child: Text('${r.count}', textAlign: TextAlign.right, style: AppType.body(size: 13, weight: FontWeight.w700))),
              ],
            ),
        ],
      ),
    );
  }
}
