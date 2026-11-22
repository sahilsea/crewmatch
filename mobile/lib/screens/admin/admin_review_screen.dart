import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/when.dart';
import 'admin_common.dart';

/// Crews' challenge links and students' event proposals, each approved with
/// points, sent back, or (for proposals) kept as a community event.
class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key, required this.wide, required this.onChanged});

  final bool wide;
  final VoidCallback onChanged;

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

/// One line in "Recently decided".
typedef _Decided = ({String title, String detail, Decision decision, int points});

class _AdminReviewScreenState extends State<AdminReviewScreen> {
  List<ReviewItem>? _items;
  Object? _error;
  var _entries = true;
  final _points = <String, int>{};
  final _busy = <String>{};
  final _log = <_Decided>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final events = await context.api.adminEvents();
      if (!mounted) return;
      setState(() {
        _items = reviewItemsOf(events);
        _error = null;
        // Open on whichever list has something in it.
        if (!_items!.any((i) => i.isEntry) && _items!.isNotEmpty) _entries = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _decide(ReviewItem item, Decision decision) async {
    final points = _points[item.id] ?? item.suggestedPoints;
    setState(() => _busy.add(item.id));
    try {
      final message = await decide(context, item, decision, points);
      if (!mounted) return;
      setState(() {
        _items = [for (final i in _items!) if (i.id != item.id) i];
        _log.insert(0, (
          title: item.event.title,
          detail: '${item.who} · ${_verb(item, decision)}',
          decision: decision,
          points: decision == Decision.approve ? points : 0,
        ));
      });
      showNotice(context, message);
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  static String _verb(ReviewItem item, Decision d) => switch (d) {
        Decision.approve => item.isEntry ? 'approved' : 'now official',
        Decision.keep => 'kept as community',
        Decision.reject => item.isEntry ? 'sent back' : 'removed',
      };

  @override
  Widget build(BuildContext context) {
    final items = _items;
    const header = AdminHeader(title: 'Review');
    if (items == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(child: _error == null ? const LoadingView() : ErrorView(error: _error!, onRetry: _load)),
        ],
      );
    }
    final entries = items.where((i) => i.isEntry).toList();
    final proposals = items.where((i) => !i.isEntry).toList();
    final shown = _entries ? entries : proposals;
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text('Challenge entries · ${entries.length}')),
              ButtonSegment(value: false, label: Text('Event proposals · ${proposals.length}')),
            ],
            selected: {_entries},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _entries = s.first),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: shown.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 40),
                      Center(
                        child: PopIn(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(color: Palette.gold, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, size: 30, color: Palette.onGold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('All caught up', textAlign: TextAlign.center, style: AppType.body(size: 17, weight: FontWeight.w700)),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final item = shown[i];
                      return Rise(
                        key: ValueKey(item.id),
                        delay: Motion.stagger(i.clamp(0, 5)),
                        child: _ReviewCard(
                          item: item,
                          points: _points[item.id] ?? item.suggestedPoints,
                          busy: _busy.contains(item.id),
                          onPoints: (p) => setState(() => _points[item.id] = p),
                          onDecide: (d) => _decide(item, d),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: widget.wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 24,
                    children: [
                      Expanded(child: list),
                      SizedBox(width: 300, child: _DecidedLog(log: _log)),
                    ],
                  )
                : list,
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.item,
    required this.points,
    required this.busy,
    required this.onPoints,
    required this.onDecide,
  });

  final ReviewItem item;
  final int points;
  final bool busy;
  final ValueChanged<int> onPoints;
  final ValueChanged<Decision> onDecide;

  @override
  Widget build(BuildContext context) {
    final e = item.event;
    final entry = item.entry?.entry;
    final start = e.startsAt.toLocal();
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 12,
            children: [
              Avatar(url: '', name: item.who, size: 44, background: item.isEntry ? Palette.pink : Palette.gold),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(item.who, style: AppType.body(size: 15, weight: FontWeight.w500)),
                    Text(item.isEntry ? 'Crew' : 'Wants to host', style: AppType.body(size: 13, color: Palette.muted)),
                  ],
                ),
              ),
              InfoTag(item.isEntry ? '${capitalized(e.category)} challenge' : capitalized(e.category), color: Palette.high, textColor: Palette.ink),
            ],
          ),
          Text(e.title, style: AppType.body(size: 18, weight: FontWeight.w700)),
          if (entry?.submissionUrl case final url?)
            Row(
              spacing: 6,
              children: [
                const Icon(Icons.link_rounded, size: 18, color: Palette.link),
                Expanded(child: SelectableText(url, style: AppType.body(size: 14, weight: FontWeight.w500, color: Palette.link))),
              ],
            ),
          if (!item.isEntry)
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Meta(Icons.schedule_rounded, '${calendarDate(start)} · ${clock(start)}'),
                _Meta(Icons.place_outlined, e.location),
                if (e.capacity case final cap?) _Meta(Icons.groups_outlined, '$cap crews'),
              ],
            ),
          if ((item.isEntry ? entry?.note : e.summary) case final text? when text.isNotEmpty)
            Text(text, style: AppType.body(size: 15, height: 1.5)),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(border: Border(top: Frame.side)),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              children: [
                PointsStepper(value: points, onChanged: busy ? null : onPoints),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: busy ? null : () => onDecide(Decision.reject),
                      child: Text(item.isEntry ? 'Send back' : 'Reject'),
                    ),
                    if (!item.isEntry)
                      OutlinedButton(
                        onPressed: busy ? null : () => onDecide(Decision.keep),
                        child: const Text('Keep as community'),
                      ),
                    FilledButton.icon(
                      onPressed: busy ? null : () => onDecide(Decision.approve),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(item.isEntry ? 'Approve' : 'Make official'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(icon, size: 15, color: Palette.muted),
          Text(text, style: AppType.body(size: 13, color: Palette.muted)),
        ],
      );
}

class _DecidedLog extends StatelessWidget {
  const _DecidedLog({required this.log});

  final List<_Decided> log;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text('Recently decided', style: AppType.body(size: 15, weight: FontWeight.w700)),
          ),
          if (log.isEmpty) Text('Decisions you make show up here.', style: AppType.body(size: 13, color: Palette.muted)),
          for (final d in log)
            SlideIn(
              key: ValueKey(d),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: Frame.side)),
                child: Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: switch (d.decision) {
                          Decision.approve => Palette.gold,
                          Decision.keep => Palette.high,
                          Decision.reject => Palette.crimson,
                        },
                      ),
                      child: Icon(
                        switch (d.decision) {
                          Decision.approve => Icons.check_rounded,
                          Decision.keep => Icons.remove_rounded,
                          Decision.reject => Icons.close_rounded,
                        },
                        size: 16,
                        color: switch (d.decision) {
                          Decision.approve => Palette.onGold,
                          Decision.keep => Palette.ink,
                          Decision.reject => Palette.onCrimson,
                        },
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 14, weight: FontWeight.w500)),
                          Text(d.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 12, color: Palette.muted)),
                        ],
                      ),
                    ),
                    if (d.points > 0) Text('+${d.points}', style: AppType.body(size: 13, weight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      );
}
