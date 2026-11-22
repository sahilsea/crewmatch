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
    final status = _statusLine(e);
    final live = e.state == EventState.live;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.window,
        borderRadius: Frame.radius,
        border: Frame.border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              _DateBlock(date: e.startsAt.toLocal(), live: live),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Row(
                      spacing: 8,
                      children: [
                        switch (e.state) {
                          EventState.live => const LivePill(),
                          EventState.upcoming => const SizedBox.shrink(),
                          EventState.ended => const InkBadge('Ended'),
                        },
                        Flexible(
                          child: Text(
                            _capitalized(e.category.isEmpty ? e.kind.name : e.category),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.body(size: 12, weight: FontWeight.w500, color: Palette.muted),
                          ),
                        ),
                      ],
                    ),
                    Text(e.title, style: AppType.body(size: 16, weight: FontWeight.w700, height: 1.3)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(Icons.place_outlined, size: 14, color: Palette.muted),
                        ),
                        Expanded(
                          child: Text(
                            '${e.location} · ${scheduleLine(e, now)}',
                            style: AppType.body(size: 13, color: Palette.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (e.hosting || e.host != null) _HostLine(event: e),
          if (_expanded) ...[
            if (e.summary.isNotEmpty) Text(e.summary, style: AppType.body(size: 14.5)),
            if (e.details.isNotEmpty) Text(e.details, style: AppType.body(size: 14, color: Palette.muted)),
            Text(countdown(e, now), style: AppType.body(size: 13, color: Palette.muted)),
            _Capacity(event: e),
          ],
          if (status case (final text, final detail, final color)) _StatusLine(status: text, detail: detail, color: color),
          Row(
            children: [
              if (e.isOfficial)
                InfoTag('+${e.points} pts', icon: Icons.bolt_rounded)
              else if (e.isPending)
                InfoTag('+${e.askedPoints} pending', icon: Icons.schedule_rounded, color: Palette.high, textColor: Palette.ink)
              else
                const InfoTag('Community', color: Palette.high, textColor: Palette.ink),
              const SizedBox(width: 6),
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Less' : 'More'),
              ),
              const Spacer(),
              if (e.isCompleted)
                Flexible(
                  child: PopIn(child: _Stamp(e.isChallenge ? 'Approved · +${e.myEntry!.pointsAwarded}' : 'Checked in · +${e.myEntry!.pointsAwarded}')),
                ),
            ],
          ),
          // Actions get their own full-width row so two never push off-screen.
          if (!e.isCompleted && actions.isNotEmpty)
            Row(
              spacing: 8,
              children: [
                for (final action in actions)
                  Expanded(
                    child: action.color == Palette.inset
                        ? OutlinedButton(onPressed: action.onPressed, child: Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis))
                        : FilledButton(
                            onPressed: action.onPressed,
                            style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                            child: Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// What your crew has done here: a status, an optional detail (a link or a
  /// reviewer's note, shown as typed), and the colour to show it in.
  static (String, String?, Color)? _statusLine(HubEvent e) {
    final entry = e.myEntry;
    if (entry == null) return e.isFull ? ('Full', null, Palette.strip) : null;
    return switch (entry.status) {
      EntryStatus.completed => null,
      EntryStatus.submitted => ('In review', entry.submissionUrl, Palette.strip),
      EntryStatus.joined when entry.wasSentBack => ('Sent back', entry.note, Palette.pink),
      EntryStatus.joined => (
          e.isChallenge ? 'Accepted' : '✓ Going',
          null,
          Palette.strip,
        ),
    };
  }
}

/// The day and date in a small tile, warmer when the event is live.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date, required this.live});

  final DateTime date;
  final bool live;

  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) => Container(
        width: 54,
        height: 58,
        decoration: BoxDecoration(
          color: live ? Palette.pink : Palette.high,
          borderRadius: Frame.buttonRadius,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_days[date.weekday - 1], style: AppType.body(size: 11, weight: FontWeight.w500)),
            Text('${date.day}', style: AppType.body(size: 20, weight: FontWeight.w700, height: 1.1)),
          ],
        ),
      );
}

/// The navy "Checked in · +40" stamp on a finished event.
class _Stamp extends StatelessWidget {
  const _Stamp(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(color: Palette.navy, borderRadius: Frame.chipRadius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            const Icon(Icons.check_rounded, size: 16, color: Palette.cream),
            Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 14, weight: FontWeight.w500, color: Palette.cream))),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color == Palette.blue ? Palette.pink : color, borderRadius: Frame.chipRadius),
        child: Text.rich(
          TextSpan(
            text: status,
            children: [
              if (detail != null && detail!.isNotEmpty)
                TextSpan(text: ': $detail', style: AppType.body(size: 14)),
            ],
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: AppType.body(size: 14, weight: FontWeight.w500),
        ),
      );
}

String _capitalized(String text) => text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

/// Who hosts a student event. The host also sees the check-in code to show at the venue.
class _HostLine extends StatelessWidget {
  const _HostLine({required this.event});

  final HubEvent event;

  @override
  Widget build(BuildContext context) {
    final code = event.checkinCode;
    final text = event.hosting ? 'You host this' : 'Hosted by ${event.host!.name}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(color: Palette.strip, borderRadius: Frame.chipRadius),
      child: Row(
        spacing: 8,
        children: [
          const Icon(Icons.person_outline_rounded, size: 18, color: Palette.muted),
          Expanded(child: Text(text, style: AppType.body(size: 14, weight: FontWeight.w500))),
          if (event.hosting && code != null)
            Semantics(
              label: 'Check-in code ${code.split('').join(' ')}',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(color: Palette.navy, borderRadius: Frame.tagRadius),
                child: Text(code, style: AppType.title(size: 16, color: Palette.cream)),
              ),
            ),
        ],
      ),
    );
  }
}
