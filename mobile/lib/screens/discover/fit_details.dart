import 'package:material_ui/material_ui.dart';

import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import '../../util/when.dart';
import '../people/people_ui.dart';

/// Everything behind a deck card, as a bento: a score ring with the verdict,
/// then tiles for why the score, work style next to yours, their record and
/// similar people. Two columns when there's room (the wide Discover panel),
/// one column otherwise (the phone sheet).
class FitDetails extends StatelessWidget {
  const FitDetails({super.key, required this.person, required this.onRequest, this.similar = const []});

  final User person;
  final VoidCallback onRequest;
  final List<User> similar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final tiles = [
        if (person.breakdown != null) _WhyTile(person),
        if (person.schedule != null || person.commitment != null || person.communication != null) _StyleTile(person),
        _RecordTile(person),
        if (similar.isNotEmpty) _SimilarTile(similar),
      ];
      final grid = box.maxWidth >= 640;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Rise(
            child: FitHero(person: person, onRequest: onRequest),
          ),
          if (grid)
            for (var i = 0; i < tiles.length; i += 2)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    Expanded(
                      child: Rise(delay: Motion.stagger(i + 1), child: tiles[i]),
                    ),
                    Expanded(
                      child: i + 1 < tiles.length ? Rise(delay: Motion.stagger(i + 2), child: tiles[i + 1]) : const SizedBox(),
                    ),
                  ],
                ),
              )
          else
            for (final (i, t) in tiles.indexed) Rise(delay: Motion.stagger(i + 1), child: t),
        ],
      );
    },
  );
}

String _verdict(int score) => score >= 85
    ? 'Great fit'
    : score >= 72
    ? 'Strong fit'
    : 'Good fit';

/// The top of the details: the fit as a ring, a one-word verdict, the reasons
/// and their bio. A small Request button (the heart under the card does the same).
class FitHero extends StatelessWidget {
  const FitHero({super.key, required this.person, required this.onRequest});

  final User person;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final score = person.score ?? 0;
    final about = person.bio.isNotEmpty && person.bio != person.headline ? person.bio : null;
    final reasons = [
      for (final t in person.tags)
        if (t != 'In your club') t,
    ];
    final request = OutlinedButton.icon(
      onPressed: onRequest,
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.fromLTRB(12, 0, 16, 0)),
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
      label: const Text('Request'),
    );
    return LayoutBuilder(
      builder: (context, box) {
        // Phones: a smaller ring, and Request under the reasons so the verdict never wraps.
        final narrow = box.maxWidth < 480;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
          decoration: const BoxDecoration(color: Palette.window, borderRadius: BorderRadius.all(Radius.circular(28)), border: Frame.border),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 18,
            children: [
              _ScoreRing(score: score, size: narrow ? 76 : 96),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    if (narrow)
                      Text(_verdict(score), style: AppType.title(size: 20))
                    else
                      Row(
                        children: [
                          Expanded(child: Text(_verdict(score), style: AppType.title(size: 22))),
                          request,
                        ],
                      ),
                    if (reasons.isNotEmpty)
                      Wrap(spacing: 6, runSpacing: 6, children: [for (final r in reasons) _Chip(r, icon: Icons.check_rounded)]),
                    if (about != null)
                      Text(
                        '“$about”',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(size: 14, height: 1.45, color: Palette.muted),
                      ),
                    if (narrow) Padding(padding: const EdgeInsets.only(top: 4), child: request),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, this.size = 96});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: score / 100),
    duration: const Duration(milliseconds: 1000),
    curve: Curves.easeOutCubic,
    builder: (context, t, _) => SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(t, track: Palette.high, fill: Palette.gold),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score%',
                style: AppType.body(size: size * 0.27, weight: FontWeight.w700, height: 1),
              ),
              Text('fit', style: AppType.body(size: 11, color: Palette.muted)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, {required this.track, required this.fill});

  final double t;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, 6.2832, false, paint..color = track);
    if (t > 0) canvas.drawArc(arc, -1.5708, 6.2832 * t, false, paint..color = fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t || old.track != track || old.fill != fill;
}

/// A rounded tile with an icon, a title and an optional note on the right.
class _BentoTile extends StatelessWidget {
  const _BentoTile({required this.icon, required this.title, required this.child, this.meta});

  final IconData icon;
  final String title;
  final String? meta;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
    decoration: const BoxDecoration(color: Palette.window, borderRadius: BorderRadius.all(Radius.circular(24)), border: Frame.border),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Row(
          spacing: 10,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(color: Palette.high, borderRadius: BorderRadius.all(Radius.circular(10))),
              child: Icon(icon, size: 17, color: Palette.link),
            ),
            Expanded(
              child: Text(title, style: AppType.body(size: 15, weight: FontWeight.w700)),
            ),
            if (meta != null)
              Text(
                meta!,
                style: AppType.body(size: 12.5, weight: FontWeight.w500, color: Palette.muted),
              ),
          ],
        ),
        child,
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.icon, this.gold = true});

  final String text;
  final IconData? icon;
  final bool gold;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: gold ? Palette.gold : Palette.high, borderRadius: Frame.pill),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        if (icon != null) Icon(icon, size: 14, color: gold ? Palette.onGold : Palette.ink),
        Text(
          text,
          style: AppType.body(size: 12.5, weight: gold ? FontWeight.w500 : FontWeight.w700, color: gold ? Palette.onGold : Palette.ink),
        ),
      ],
    ),
  );
}

/// One bar split into the three parts of the score, then a legend.
class _WhyTile extends StatelessWidget {
  const _WhyTile(this.person);

  final User person;

  @override
  Widget build(BuildContext context) {
    final b = person.breakdown!;
    final parts = [
      ('Complementary skills', b.skills, 50, Palette.crimson),
      ('Work style', b.style, 30, Palette.navy),
      ('Shared interests', b.interests, 20, Palette.gold),
    ];
    return _BentoTile(
      icon: Icons.bar_chart_rounded,
      title: 'Why ${person.score ?? b.skills + b.style + b.interests}%',
      meta: 'out of 100',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => ClipRRect(
              borderRadius: Frame.pill,
              child: SizedBox(
                height: 14,
                child: ColoredBox(
                  color: Palette.high,
                  child: LayoutBuilder(
                    builder: (context, bar) => Row(
                      children: [
                        // Each part takes its share of 100, growing in from the left.
                        for (final (_, got, _, color) in parts)
                          if (got > 0)
                            Container(
                              width: (bar.maxWidth * got / 100 * t - 2).clamp(0, bar.maxWidth),
                              margin: const EdgeInsets.only(right: 2),
                              color: color,
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          for (final (label, got, max, color) in parts)
            Row(
              spacing: 10,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                Expanded(child: Text(label, style: AppType.body(size: 14))),
                Text('$got', style: AppType.body(size: 14, weight: FontWeight.w700)),
                Text('/ $max', style: AppType.body(size: 12.5, color: Palette.muted)),
              ],
            ),
          if (b.clubs > 0) Text('+${b.clubs} for a shared club', style: AppType.body(size: 12.5, color: Palette.muted)),
        ],
      ),
    );
  }
}

/// Their work style, each row compared with yours.
class _StyleTile extends StatelessWidget {
  const _StyleTile(this.person);

  final User person;

  @override
  Widget build(BuildContext context) {
    final me = context.session.user;
    final rows = [
      (Icons.schedule_rounded, person.schedule, me?.schedule),
      (Icons.flag_rounded, person.commitment, me?.commitment),
      (Icons.forum_rounded, person.communication, me?.communication),
    ].where((r) => r.$2 != null).toList();
    final same = rows.where((r) => r.$2 == r.$3).length;
    return _BentoTile(
      icon: Icons.auto_awesome_rounded,
      title: 'Work style',
      meta: me == null ? null : '$same of ${rows.length} match',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          for (final (icon, theirs, mine) in rows)
            Row(
              spacing: 12,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(color: Palette.high, shape: BoxShape.circle),
                  child: Icon(icon, size: 17, color: Palette.ink),
                ),
                Expanded(
                  child: Text(optionLabel(theirs!), style: AppType.body(size: 14.5, weight: FontWeight.w500)),
                ),
                if (mine != null)
                  theirs == mine
                      ? const _Chip('Same', icon: Icons.check_rounded)
                      : Text('You: ${optionLabel(mine)}', style: AppType.body(size: 12.5, color: Palette.muted)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Events, challenges and points their crew finished, and the latest one.
class _RecordTile extends StatelessWidget {
  const _RecordTile(this.person);

  final User person;

  @override
  Widget build(BuildContext context) {
    final r = person.record;
    Widget stat(int value, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: const BoxDecoration(color: Palette.high, borderRadius: BorderRadius.all(Radius.circular(16))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            Text('$value', style: AppType.body(size: 24, weight: FontWeight.w700, height: 1.1)),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.body(size: 12.5, color: Palette.muted),
            ),
          ],
        ),
      ),
    );
    return _BentoTile(
      icon: Icons.emoji_events_rounded,
      title: 'Hackathon record',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 8,
            children: [
              stat(r?.events ?? 0, (r?.events ?? 0) == 1 ? 'event' : 'events'),
              stat(r?.challenges ?? 0, (r?.challenges ?? 0) == 1 ? 'challenge' : 'challenges'),
              stat(r?.points ?? 0, 'points'),
            ],
          ),
          Row(
            spacing: 6,
            children: [
              const Icon(Icons.schedule_rounded, size: 15, color: Palette.muted),
              Expanded(
                child: Text(
                  switch (r) {
                    HackRecord(lastTitle: final t?, lastAt: final at?) => '$t · ${timeAgo(at, DateTime.now())}',
                    _ when person.crewName == null => 'No events yet. A fresh start.',
                    _ => 'Nothing finished with ${person.crewName} yet.',
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(size: 13, color: Palette.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Others in the deck like this person; tap to open their profile.
class _SimilarTile extends StatelessWidget {
  const _SimilarTile(this.people);

  final List<User> people;

  @override
  Widget build(BuildContext context) => _BentoTile(
    icon: Icons.group_rounded,
    title: 'Similar people',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        for (final p in people.take(3))
          ProfileTap(
            userId: p.id,
            handle: p.handle,
            name: p.name,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                spacing: 12,
                children: [
                  Avatar(url: p.avatar, name: p.name, size: 40, background: Palette.pink),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 1,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body(size: 14, weight: FontWeight.w500),
                        ),
                        Text(
                          [if (p.role != null) optionLabel(p.role!), if (p.tags.isNotEmpty) p.tags.first].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body(size: 12, color: Palette.muted),
                        ),
                      ],
                    ),
                  ),
                  if (p.score != null) _Chip('${p.score}%', gold: false),
                  const Icon(Icons.chevron_right_rounded, color: Palette.muted),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// "Why 86%": the three score bars and the reasons. Empty without a breakdown.
class WhyFitSection extends StatelessWidget {
  const WhyFitSection(this.person, {super.key});

  final User person;

  @override
  Widget build(BuildContext context) {
    final b = person.breakdown;
    if (b == null) return const SizedBox.shrink();
    return DetailSection(
      title: 'Why ${person.score ?? b.skills + b.style + b.interests}%',
      children: [
        _Bar(label: 'Complementary skills', value: b.skills, max: 50, delay: 0),
        _Bar(label: 'Work style', value: b.style, max: 30, delay: 1),
        _Bar(label: 'Shared interests', value: b.interests, max: 20, delay: 2),
        if (b.clubs > 0) _Reason('Same club · +${b.clubs}'),
        for (final t in person.tags.where((t) => t != 'In your club')) _Reason(t),
      ],
    );
  }
}

/// Schedule, commitment and how they talk, marked where they match yours.
class WorkStyleSection extends StatelessWidget {
  const WorkStyleSection(this.person, {super.key, this.compare = true});

  final User person;
  final bool compare;

  @override
  Widget build(BuildContext context) {
    final me = compare ? context.session.user : null;
    if (person.schedule == null && person.commitment == null && person.communication == null) return const SizedBox.shrink();
    return DetailSection(
      title: 'Work style',
      children: [
        _StyleRow(Icons.schedule_rounded, 'Schedule', person.schedule, me?.schedule),
        _StyleRow(Icons.flag_rounded, 'Commitment', person.commitment, me?.commitment),
        _StyleRow(Icons.forum_rounded, 'Talks by', person.communication, me?.communication),
      ],
    );
  }
}

/// Events, challenges and points their crew finished, and the latest one.
class RecordSection extends StatelessWidget {
  const RecordSection(this.person, {super.key});

  final User person;

  @override
  Widget build(BuildContext context) {
    final r = person.record;
    return DetailSection(
      title: 'Hackathon record',
      children: [
        Row(
          spacing: 10,
          children: [
            _Tile(value: r?.events ?? 0, label: 'Events'),
            _Tile(value: r?.challenges ?? 0, label: 'Challenges'),
            _Tile(value: r?.points ?? 0, label: 'Points'),
          ],
        ),
        Text(switch (r) {
          HackRecord(lastTitle: final t?, lastAt: final at?) => 'Last: $t · ${timeAgo(at, DateTime.now())}',
          _ when person.crewName == null => 'No events yet. A fresh start.',
          _ => 'Nothing finished with ${person.crewName} yet.',
        }, style: AppType.body(size: 13, color: Palette.muted)),
      ],
    );
  }
}

/// A bold title over its content.
class DetailSection extends StatelessWidget {
  const DetailSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      Text(title, style: AppType.body(size: 16, weight: FontWeight.w700)),
      ...children,
    ],
  );
}

/// One part of the score as a rounded bar that fills in.
class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.max, required this.delay});

  final String label;
  final int value;
  final int max;
  final int delay;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 6,
    children: [
      Row(
        children: [
          Expanded(child: Text(label, style: AppType.body(size: 14))),
          Text('$value/$max', style: AppType.body(size: 13.5, weight: FontWeight.w700)),
        ],
      ),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: max == 0 ? 0 : (value / max).clamp(0, 1)),
        duration: Duration(milliseconds: 700 + 120 * delay),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => ClipRRect(
          borderRadius: Frame.pill,
          child: SizedBox(
            height: 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Palette.high),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: t,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Palette.gold, borderRadius: Frame.pill),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _Reason extends StatelessWidget {
  const _Reason(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      const Icon(Icons.check_circle_rounded, size: 18, color: Palette.gold),
      Expanded(child: Text(text, style: AppType.body(size: 14.5))),
    ],
  );
}

class _StyleRow extends StatelessWidget {
  const _StyleRow(this.icon, this.label, this.theirs, this.mine);

  final IconData icon;
  final String label;
  final String? theirs;
  final String? mine;

  @override
  Widget build(BuildContext context) {
    final value = theirs;
    if (value == null) return const SizedBox.shrink();
    return Row(
      spacing: 10,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(color: Palette.strip, borderRadius: Frame.buttonRadius),
          child: Icon(icon, size: 18, color: Palette.muted),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppType.body(size: 12, color: Palette.muted)),
              Text(optionLabel(value), style: AppType.body(size: 14.5, weight: FontWeight.w500)),
            ],
          ),
        ),
        if (value == mine) const InfoTag('Same as you', color: Palette.navy, textColor: Palette.cream),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(color: Palette.strip, borderRadius: Frame.radius),
      child: Column(
        children: [
          Text('$value', style: AppType.title(size: 22)),
          Text(label, style: AppType.body(size: 12, color: Palette.muted)),
        ],
      ),
    ),
  );
}

/// Phone: the same details in a tall sheet.
Future<void> showFitDetails(BuildContext context, {required User person, required List<User> similar, required VoidCallback onRequest}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (sheet, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: FitDetails(
            person: person,
            similar: similar,
            onRequest: () {
              Navigator.of(sheet).pop();
              onRequest();
            },
          ),
        ),
      ),
    );
