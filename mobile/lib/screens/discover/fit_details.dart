import 'package:material_ui/material_ui.dart';

import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import '../../util/when.dart';
import '../people/people_ui.dart';

/// Everything behind a deck card: about, why the score, work style next to
/// yours, their hackathon record and a few similar people.
///
/// Used by the wide side panel and the phone sheet.
class FitDetails extends StatelessWidget {
  const FitDetails({super.key, required this.person, required this.onRequest, this.similar = const []});

  final User person;
  final VoidCallback onRequest;
  final List<User> similar;

  @override
  Widget build(BuildContext context) {
    final me = context.session.user;
    final b = person.breakdown;
    final r = person.record;
    final about = person.bio.isNotEmpty ? person.bio : person.headline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 26,
      children: [
        _Section(
          title: 'About',
          children: [
            if (about.isNotEmpty) Text(about, style: AppType.body(size: 15.5, height: 1.55)),
            FilledButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.group_add_rounded, size: 20),
              label: const Text('Request to team up'),
            ),
          ],
        ),
        if (b != null)
          _Section(
            title: 'Why ${person.score ?? b.skills + b.style + b.interests}%',
            children: [
              _Bar(label: 'Complementary skills', value: b.skills, max: 50, delay: 0),
              _Bar(label: 'Work style', value: b.style, max: 30, delay: 1),
              _Bar(label: 'Shared interests', value: b.interests, max: 20, delay: 2),
              if (b.clubs > 0) _Reason('Same club · +${b.clubs}'),
              for (final t in person.tags.where((t) => t != 'In your club')) _Reason(t),
            ],
          ),
        if (person.schedule != null || person.commitment != null || person.communication != null)
          _Section(
            title: 'Work style',
            children: [
              _StyleRow(Icons.schedule_rounded, 'Schedule', person.schedule, me?.schedule),
              _StyleRow(Icons.flag_rounded, 'Commitment', person.commitment, me?.commitment),
              _StyleRow(Icons.forum_rounded, 'Talks by', person.communication, me?.communication),
            ],
          ),
        _Section(
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
            Text(
              switch (r) {
                HackRecord(lastTitle: final t?, lastAt: final at?) => 'Last: $t · ${timeAgo(at, DateTime.now())}',
                _ when person.crewName == null => 'No events yet. A fresh start.',
                _ => 'Nothing finished with ${person.crewName} yet.',
              },
              style: AppType.body(size: 13, color: Palette.muted),
            ),
          ],
        ),
        if (similar.isNotEmpty)
          _Section(
            title: 'Similar people',
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [for (final p in similar.take(3)) Expanded(child: _Mini(p))],
              ),
            ],
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [Text(title, style: AppType.body(size: 16, weight: FontWeight.w700)), ...children],
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
                      child: const DecoratedBox(decoration: BoxDecoration(color: Palette.gold, borderRadius: Frame.pill)),
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

class _Mini extends StatelessWidget {
  const _Mini(this.person);

  final User person;

  @override
  Widget build(BuildContext context) => ProfileTap(
        userId: person.id,
        handle: person.handle,
        name: person.name,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: Palette.inset, borderRadius: Frame.radius, border: Frame.border),
          child: Column(
            spacing: 6,
            children: [
              Avatar(url: person.avatar, name: person.name, size: 44, background: Palette.pink),
              Text(person.name.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13.5, weight: FontWeight.w700)),
              if (person.score != null) InfoTag('${person.score}%', color: Palette.gold, textColor: Palette.onGold),
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
