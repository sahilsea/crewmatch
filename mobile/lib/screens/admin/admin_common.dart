import 'package:material_ui/material_ui.dart';

import '../../models/hub_event.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';

/// The organiser's tabs.
enum AdminTab {
  overview('Overview', Icons.space_dashboard_outlined),
  events('Events', Icons.event_outlined),
  review('Review', Icons.fact_check_outlined),
  clubs('Clubs', Icons.groups_2_outlined),
  ranks('Ranks', Icons.leaderboard_outlined);

  const AdminTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

typedef OpenAdminTab = void Function(AdminTab tab);

/// Something waiting for an organiser: a crew's challenge link ([entry] set),
/// or a student's event that asked for points.
class ReviewItem {
  const ReviewItem(this.event, [this.entry]);

  final HubEvent event;
  final AdminEntry? entry;

  bool get isEntry => entry != null;
  String get id => isEntry ? '${event.id}:${entry!.crewId}' : event.id;
  String get who => isEntry ? entry!.crewName : event.host?.name ?? 'A student';

  /// What approving awards unless the organiser changes it.
  int get suggestedPoints => isEntry ? event.points : event.askedPoints;
}

/// Challenge links first (crews are waiting on points), then event proposals.
List<ReviewItem> reviewItemsOf(List<HubEvent> events) => [
      for (final e in events)
        for (final entry in e.entries)
          if (entry.entry.status == EntryStatus.submitted) ReviewItem(e, entry),
      for (final e in events)
        if (e.isPending) ReviewItem(e),
    ];

enum Decision { approve, keep, reject }

/// Sends an organiser's decision to the API and returns what to tell them.
Future<String> decide(BuildContext context, ReviewItem item, Decision decision, int points) async {
  final api = context.api;
  final e = item.event;
  if (item.isEntry) {
    final crew = item.entry!;
    if (decision == Decision.approve) {
      await api.approveEntry(e.id, crew.crewId, points: points);
      return '${crew.crewName} +$points pts';
    }
    await api.rejectEntry(e.id, crew.crewId);
    return "${crew.crewName}'s entry sent back";
  }
  switch (decision) {
    case Decision.approve:
      await api.makeOfficial(e.id, points: points);
      return '${e.title} is official · +$points';
    case Decision.keep:
      await api.keepCommunity(e.id);
      return '${e.title} stays a community event';
    case Decision.reject:
      await api.deleteEvent(e.id);
      return '${e.title} removed';
  }
}

/// The title row of an admin page.
class AdminHeader extends StatelessWidget {
  const AdminHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Semantics(header: true, child: Text(title, style: AppType.title(size: 26))),
                  Text('Organiser tools', style: AppType.body(size: 14, color: Palette.muted)),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      );
}

/// A rounded card with the app's border.
class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color = Palette.window});

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: Frame.radius,
          border: color == Palette.window ? Frame.border : null,
        ),
        child: child,
      );
}

/// Minus, the points in gold, plus. Steps of 10, from 0 to 1000.
class PointsStepper extends StatelessWidget {
  const PointsStepper({super.key, required this.value, required this.onChanged});

  final int value;

  /// Null disables it.
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        IconButton.outlined(
          tooltip: 'Fewer points',
          onPressed: change == null || value <= 0 ? null : () => change((value - 10).clamp(0, 1000)),
          icon: const Icon(Icons.remove_rounded, size: 18),
        ),
        Semantics(
          liveRegion: true,
          label: '$value points',
          excludeSemantics: true,
          child: AnimatedSwitcher(
            duration: Motion.of(context, const Duration(milliseconds: 250)),
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: Container(
              key: ValueKey(value),
              constraints: const BoxConstraints(minWidth: 68),
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: change == null ? Palette.high : Palette.gold,
                borderRadius: Frame.buttonRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 3,
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: change == null ? Palette.muted : Palette.onGold),
                  Text('$value', style: AppType.body(size: 16, weight: FontWeight.w700, color: change == null ? Palette.muted : Palette.onGold)),
                ],
              ),
            ),
          ),
        ),
        IconButton.outlined(
          tooltip: 'More points',
          onPressed: change == null || value >= 1000 ? null : () => change((value + 10).clamp(0, 1000)),
          icon: const Icon(Icons.add_rounded, size: 18),
        ),
      ],
    );
  }
}

/// A check-in code as gold or navy letter tiles.
class CodeTiles extends StatelessWidget {
  const CodeTiles(this.code, {super.key, this.size = 44, this.color = Palette.navy, this.textColor = Palette.cream});

  final String code;
  final double size;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Check-in code ${code.split('').join(' ')}',
        excludeSemantics: true,
        child: AnimatedSwitcher(
          duration: Motion.of(context, const Duration(milliseconds: 300)),
          child: Row(
            key: ValueKey(code),
            mainAxisSize: MainAxisSize.min,
            spacing: size * 0.16,
            children: [
              for (final (i, ch) in code.split('').indexed)
                PopIn(
                  delay: Motion.stagger(i, stepMs: 50),
                  child: Container(
                    width: size * 0.9,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.22)),
                    child: Text(ch, style: AppType.title(size: size * 0.5, color: textColor)),
                  ),
                ),
            ],
          ),
        ),
      );
}

/// Status of an event as organisers see it: live, upcoming, ended, or a student's.
(String, Color, Color) statusOf(HubEvent e) => switch (e.status) {
      EventStatus.pending => ('Needs review', Palette.gold, Palette.onGold),
      EventStatus.community => ('Community', Palette.high, Palette.ink),
      EventStatus.official => switch (e.state) {
          EventState.live => ('LIVE', Palette.crimson, Palette.onCrimson),
          EventState.upcoming => ('Upcoming', Palette.navy, Palette.cream),
          EventState.ended => ('Ended', Palette.strip, Palette.muted),
        },
    };

class StatusPill extends StatelessWidget {
  const StatusPill(this.event, {super.key});

  final HubEvent event;

  @override
  Widget build(BuildContext context) {
    final (text, color, ink) = statusOf(event);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: Frame.tagRadius),
      child: Text(text, style: AppType.body(size: 11.5, weight: FontWeight.w700, color: ink)),
    );
  }
}

String capitalized(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
