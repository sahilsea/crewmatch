import 'package:material_ui/material_ui.dart';

import '../../models/user.dart';
import '../clubs/club_ui.dart';
import '../people/people_ui.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';

/// One swipe card, styled the way its owner set it up: a cover with their
/// headline, their photo ringed in their accent colour, why they fit, and the
/// details they chose to show.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.person,
    this.position = '',
    this.fitLabel,
  });

  final User person;

  /// "1 of 18", for screen readers.
  final String position;

  /// Overrides the fit tag, e.g. "Your fit shows here" in your own preview.
  final String? fitLabel;

  @override
  Widget build(BuildContext context) {
    final (accent, onAccent) = CardStyle.accent(person.accent);
    final show = person.cardFields.toSet();
    final fit =
        fitLabel ?? (person.score == null ? null : '${person.score}% fit');
    final meta = [
      if (person.role != null) optionLabel(person.role!),
      if (show.contains('experience') && person.experienceLevel != null)
        optionLabel(person.experienceLevel!),
      if (show.contains('schedule') && person.schedule != null)
        optionLabel(person.schedule!),
    ].join(' · ');
    final chips = <Widget>[
      if (show.contains('superpowers'))
        for (final p in person.superpowers)
          InfoTag(optionLabel(p), color: accent, textColor: onAccent),
      if (show.contains('skills'))
        for (final s in person.skills) _OutlineChip(s),
      if (show.contains('interests'))
        for (final i in person.interests)
          InfoTag(optionLabel(i), color: Palette.strip, textColor: Palette.ink),
    ].take(6).toList();

    return Semantics(
      label: position.isEmpty ? null : 'Card $position',
      child: Container(
        decoration: const BoxDecoration(
          color: Palette.window,
          borderRadius: Frame.radius,
          border: Frame.border,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Cover(person: person, fit: fit),
            ),
            // The photo sits half over the cover; the row itself is only as
            // tall as the name, so nothing below gets pushed down.
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: SizedBox(
                height: 50,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                          border: Border.all(color: Palette.window, width: 4),
                        ),
                        child: ProfileTap(
                          userId: person.id,
                          handle: person.handle,
                          name: person.name,
                          child: Avatar(url: person.avatar, name: person.name, size: 74, background: accent),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 102,
                      right: 0,
                      bottom: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.title(size: 22),
                          ),
                          if (meta.isNotEmpty)
                            Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.body(
                                size: 14,
                                color: Palette.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  if ((person.headline.isNotEmpty ? person.headline : person.bio) case final line when line.isNotEmpty)
                    Text(line, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppType.body(size: 16, height: 1.4)),
                  if (person.tags.isNotEmpty)
                    Rise(
                      delay: const Duration(milliseconds: 80),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in person.tags.take(2))
                            InfoTag(tag, icon: Icons.check_rounded),
                        ],
                      ),
                    ),
                  if (chips.isNotEmpty)
                    Rise(
                      delay: const Duration(milliseconds: 160),
                      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
                    ),
                  if (person.clubs.isNotEmpty || person.crewName != null || person.score != null)
                    Rise(
                      delay: const Duration(milliseconds: 220),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final c in person.clubs.take(2)) ClubChip(c),
                          if (person.score != null)
                            Text(
                              crewStatus(person),
                              style: AppType.body(size: 12.5, weight: FontWeight.w500, color: person.crewName == null ? Palette.link : Palette.muted),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The cover, with the fit tag on top and the headline over a soft fade.
class _Cover extends StatelessWidget {
  const _Cover({required this.person, required this.fit});

  final User person;
  final String? fit;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: CardStyle.cover(person.cover, photoUrl: person.coverUrl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A texture on the preset covers, so a big cover never reads as empty.
            if (person.cover == 'circuit') const CustomPaint(painter: _CircuitPainter()) else if (person.coverUrl == null) const CustomPaint(painter: _DotsPainter()),
            if (fit != null) Positioned(top: 14, left: 14, child: _FitTag(fit!)),
          ],
        ),
      );
}

/// Soft gold dots for the preset covers.
class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x2EE8C25E);
    for (var y = 6.0; y < size.height; y += 14) {
      for (var x = 6.0; x < size.width; x += 14) {
        canvas.drawCircle(Offset(x, y), 1.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FitTag extends StatelessWidget {
  const _FitTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => PopIn(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Palette.gold,
        borderRadius: BorderRadius.all(Radius.circular(999)),
        boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          const Icon(Icons.bolt_rounded, size: 18, color: Palette.onGold),
          Text(label, style: AppType.body(size: 15, weight: FontWeight.w700, color: Palette.onGold)),
        ],
      ),
    ),
  );
}

class _OutlineChip extends StatelessWidget {
  const _OutlineChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      borderRadius: Frame.tagRadius,
      border: Border.all(color: Palette.dashed),
    ),
    child: Text(
      text,
      style: AppType.body(size: 13, weight: FontWeight.w500, height: 1.2),
    ),
  );
}

/// Thin gold diagonals for the Circuit cover.
class _CircuitPainter extends CustomPainter {
  const _CircuitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x38E8C25E)
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width; x += 16) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
