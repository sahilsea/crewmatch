import 'package:material_ui/material_ui.dart';

import '../../models/hub_event.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import '../../util/when.dart';

/// One event or challenge: when and where, points, capacity, your crew's
/// status, and the actions that make sense right now.
class EventCard extends StatefulWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.hasCrew,
    required this.busy,
    required this.onJoin,
    required this.onLeave,
    required this.onCheckIn,
    required this.onSubmit,
  });

  final HubEvent event;

  /// Without a crew there is nothing to do here; the screen explains why.
  final bool hasCrew;

  /// A request for this card is in flight.
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onCheckIn;
  final VoidCallback onSubmit;

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  var _expanded = false;

  List<Segment> _actions(DateTime now) {
    final e = widget.event;
    final entry = e.myEntry;
    if (!widget.hasCrew || e.isCompleted) return const [];
    VoidCallback? unlessBusy(VoidCallback action) => widget.busy ? null : action;

    final join = entry == null && e.state != EventState.ended
        ? Segment(
            label: e.isFull ? 'Full' : (e.isChallenge ? 'Accept' : 'Join'),
            color: Palette.blue,
            onPressed: e.isFull ? null : unlessBusy(widget.onJoin),
          )
        : null;
    final leave = entry?.status == EntryStatus.joined && e.state != EventState.ended
        ? Segment(label: 'Leave', onPressed: unlessBusy(widget.onLeave))
        : null;

    if (!e.isChallenge) {
      return [
        ?join,
        ?leave,
        if (e.canCheckIn(now))
          Segment(label: 'Check in', color: Palette.pink, onPressed: unlessBusy(widget.onCheckIn)),
      ];
    }
    return [
      ?join,
      ?leave,
      if (entry != null && e.state != EventState.ended)
        Segment(
          label: entry.status == EntryStatus.submitted ? 'Update link' : 'Submit link',
          color: Palette.pink,
          onPressed: unlessBusy(widget.onSubmit),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final now = DateTime.now();
    final actions = _actions(now);
    return Container(
      decoration: const BoxDecoration(color: Palette.inset, border: Frame.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(event: e),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 5,
              children: [
                Text(e.title, style: AppType.headline(size: 22)),
                if (e.summary.isNotEmpty) Text(e.summary, style: AppType.body(size: 14.5)),
                if (e.details.isNotEmpty) ...[
                  if (_expanded) Text(e.details, style: AppType.body(size: 14, color: Palette.mutedDark)),
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 36)),
                    child: Text(_expanded ? 'Less' : 'More'),
                  ),
                ],
                Label('${e.location} · ${scheduleLine(e, now)}', size: 16, color: Palette.ink),
                Label(countdown(e, now), size: 16, color: Palette.mutedDark),
                _Capacity(event: e),
              ],
            ),
          ),
          if (_statusLine(e) case (final status, final detail, final color))
            _StatusLine(status: status, detail: detail, color: color),
          if (actions.isNotEmpty) SegmentRow(segments: actions, height: 48),
        ],
      ),
    );
  }

  /// What your crew has done here: a status, an optional detail (a link or a
  /// reviewer's note, shown as typed), and the colour to show it in.
  static (String, String?, Color)? _statusLine(HubEvent e) {
    final entry = e.myEntry;
    if (entry == null) return e.isFull ? ('Full · no spots left', null, Palette.strip) : null;
    final points = '+${entry.pointsAwarded} pts';
    return switch (entry.status) {
      EntryStatus.completed =>
        (e.isChallenge ? '✓ Approved · $points' : '✓ Checked in · $points', null, Palette.blue),
      EntryStatus.submitted => ('In review', entry.submissionUrl, Palette.strip),
      EntryStatus.joined when entry.wasSentBack => ('Sent back', entry.note, Palette.pink),
      EntryStatus.joined => (
          e.isChallenge ? 'Accepted · submit a link before the deadline' : '✓ Your crew is going',
          null,
          Palette.strip,
        ),
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.event});

  final HubEvent event;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(border: Border(bottom: Frame.side)),
        child: Halftone(
          color: event.isChallenge ? Palette.pink : Palette.blue,
          opacity: 0.2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              spacing: 8,
              children: [
                InkBadge(event.category.isEmpty ? event.kind.name : event.category),
                switch (event.state) {
                  EventState.live => const LivePill(),
                  EventState.upcoming => const Label('Upcoming', color: Palette.ink),
                  EventState.ended => const Label('Ended', color: Palette.mutedDark),
                },
                const Spacer(),
                Label('+${event.points} pts', size: 20, color: Palette.ink),
              ],
            ),
          ),
        ),
      );
}

class _Capacity extends StatelessWidget {
  const _Capacity({required this.event});

  final HubEvent event;

  @override
  Widget build(BuildContext context) {
    final capacity = event.capacity;
    final count = plural(event.crewCount, 'crew');
    if (capacity == null) return Label('$count in · no limit', color: Palette.mutedDark);
    return Row(
      spacing: 10,
      children: [
        Expanded(child: ThinProgressBar(value: event.crewCount / capacity)),
        Label('${event.crewCount} / $capacity crews', color: Palette.mutedDark),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status, required this.detail, required this.color});

  final String status;
  final String? detail;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color, border: const Border(top: Frame.side)),
        child: Text.rich(
          TextSpan(
            text: status.toUpperCase(),
            children: [
              if (detail != null && detail!.isNotEmpty)
                TextSpan(text: ': $detail', style: AppType.body(size: 14)),
            ],
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: AppType.label(size: 17, color: Palette.ink),
        ),
      );
}
