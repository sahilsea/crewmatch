import 'package:material_ui/material_ui.dart';

import '../models/user.dart';
import 'palette.dart';
import 'type.dart';

/// A round, ink-ringed profile picture. Falls back to initials when there is
/// no picture or it fails to load (offline, say).
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.url,
    required this.name,
    this.size = 42,
    this.background = Palette.desktop,
  });

  final String url;
  final String name;
  final double size;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final initials = Center(
      child: Text(
        _initials(name),
        style: AppType.label(size: size * 0.42, color: Palette.ink),
      ),
    );
    return Semantics(
      image: true,
      label: name,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: background),
        foregroundDecoration: const BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(Frame.side),
        ),
        clipBehavior: Clip.antiAlias,
        child: url.isEmpty
            ? initials
            : Image.network(
                url,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => initials,
              ),
      ),
    );
  }

  static String _initials(String name) => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}

/// Overlapping avatars for a crew: "3 faces in a row".
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.people, this.size = 26});

  final List<User> people;
  final double size;

  static const _fills = [Palette.desktop, Palette.blue, Palette.pink, Palette.strip];

  @override
  Widget build(BuildContext context) {
    final step = size * 0.68;
    return SizedBox(
      width: people.isEmpty ? 0 : size + step * (people.length - 1),
      height: size,
      child: Stack(
        children: [
          for (final (i, person) in people.indexed)
            Positioned(
              left: i * step,
              child: Avatar(
                url: person.avatar,
                name: person.name,
                size: size,
                background: _fills[i % _fills.length],
              ),
            ),
        ],
      ),
    );
  }
}
