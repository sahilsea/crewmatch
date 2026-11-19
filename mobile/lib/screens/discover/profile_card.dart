import 'package:material_ui/material_ui.dart';

import '../../models/user.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';

/// One swipe card: photo with the fit tag, name, why they fit and
/// superpowers.
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.person, required this.position});

  final User person;

  /// "1 of 18", shown under the card by the Discover screen.
  final String position;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Palette.window,
          borderRadius: Frame.radius,
          border: Frame.border,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _Photo(person: person)),
            _About(person: person),
          ],
        ),
      );
}

class _Photo extends StatelessWidget {
  const _Photo({required this.person});

  final User person;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Palette.pink,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = (constraints.maxHeight - 40).clamp(72.0, 128.0);
            return Stack(
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Palette.gold, shape: BoxShape.circle),
                    child: Avatar(url: person.avatar, name: person.name, size: size),
                  ),
                ),
                if (person.score case final score?)
                  Positioned(top: 14, left: 14, child: _FitTag(score)),
              ],
            );
          },
        ),
      );
}

class _FitTag extends StatelessWidget {
  const _FitTag(this.score);

  final int score;

  @override
  Widget build(BuildContext context) => Pulse(
        minScale: 0.96,
        period: const Duration(milliseconds: 1400),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: const BoxDecoration(color: Palette.crimson, borderRadius: Frame.chipRadius),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: Palette.onCrimson),
              Text('$score% fit', style: AppType.body(size: 14, weight: FontWeight.w700, color: Palette.onCrimson)),
            ],
          ),
        ),
      );
}

class _About extends StatelessWidget {
  const _About({required this.person});

  final User person;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Rise(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.title(size: 24)),
                  Text(personMeta(person), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 14, color: Palette.muted)),
                ],
              ),
            ),
            if (person.tags.isNotEmpty)
              Rise(
                delay: const Duration(milliseconds: 80),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final tag in person.tags.take(2)) InfoTag(tag, icon: Icons.check_rounded)],
                ),
              ),
            if (person.superpowers.isNotEmpty)
              Rise(
                delay: const Duration(milliseconds: 160),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final power in person.superpowers)
                      InfoTag(optionLabel(power), color: Palette.navy, textColor: Palette.cream),
                  ],
                ),
              ),
          ],
        ),
      );
}
