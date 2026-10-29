import 'package:material_ui/material_ui.dart';

import '../../models/user.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';

/// One swipe card: halftone photo, fit %, name, why they fit, and the facts.
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.person, required this.position});

  final User person;

  /// "1 of 18"
  final String position;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Palette.inset, border: Frame.border),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The photo gives way first on short screens.
            final photoHeight = (constraints.maxHeight * 0.34).clamp(110.0, 190.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: photoHeight, child: _Photo(person: person, height: photoHeight)),
                _FileStrip(name: profileFileName(person.name), position: position),
                Expanded(
                  // Long bios are clipped rather than overflowing the card.
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: _About(person: person),
                  ),
                ),
                _Facts(person: person),
              ],
            );
          },
        ),
      );
}

class _Photo extends StatelessWidget {
  const _Photo({required this.person, required this.height});

  final User person;
  final double height;

  @override
  Widget build(BuildContext context) => Halftone(
        color: Palette.blue,
        child: Stack(
          children: [
            Center(
              child: Avatar(
                url: person.avatar,
                name: person.name,
                size: (height - 40).clamp(72.0, 136.0),
              ),
            ),
            if (person.score case final score?)
              Positioned(top: 8, right: 8, child: FitBadge(score)),
          ],
        ),
      );
}

class _FileStrip extends StatelessWidget {
  const _FileStrip({required this.name, required this.position});

  final String name;
  final String position;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: const BoxDecoration(
          color: Palette.strip,
          border: Border.symmetric(horizontal: Frame.side),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.label(size: 17, color: const Color(0xFF3D3935)),
              ),
            ),
            Label(position, size: 17, color: const Color(0xFF3D3935)),
          ],
        ),
      );
}

class _About extends StatelessWidget {
  const _About({required this.person});

  final User person;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(person.name, style: AppType.headline(size: 28)),
          Label(personMeta(person), size: 18, color: Palette.mutedDark),
          if (person.bio.isNotEmpty) Text(person.bio, style: AppType.body()),
          if (person.tags.isNotEmpty)
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [for (final tag in person.tags) Tag(tag)],
            ),
        ],
      );
}

class _Facts extends StatelessWidget {
  const _Facts({required this.person});

  final User person;

  @override
  Widget build(BuildContext context) {
    final facts = [
      ('Skills', person.skills.join(', ')),
      if (person.superpowers.isNotEmpty)
        ('Powers', person.superpowers.map(optionLabel).join(', ')),
      ('Into', person.interests.map(optionLabel).join(', ')),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        children: [
          for (final (label, value) in facts) ...[
            const DashedLine(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 66, child: Label(label, color: Palette.mutedDark)),
                  Expanded(
                    child: Text(
                      value.isEmpty ? '—' : value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body(size: 14, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const DashedLine(),
        ],
      ),
    );
  }
}
