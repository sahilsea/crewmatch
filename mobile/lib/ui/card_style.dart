import 'package:material_ui/material_ui.dart';

import 'media.dart';

/// The looks someone can give their swipe card. The ids match the API's
/// `cover`, `accent` and `cardFields` values.
abstract final class CardStyle {
  static const covers = <(String, String)>[
    ('dusk', 'Dusk'),
    ('gold', 'Gold hour'),
    ('midnight', 'Midnight'),
    ('parchment', 'Parchment'),
    ('circuit', 'Circuit'),
    ('photo', 'Your photo'),
  ];

  static const accents = <String, (Color, Color)>{
    'crimson': (Color(0xFF7A1C1C), Color(0xFFFFF6E0)),
    'gold': (Color(0xFFE8C25E), Color(0xFF3A2900)),
    'navy': (Color(0xFF22305A), Color(0xFFF3E9D2)),
    'teal': (Color(0xFF1F6F6B), Color(0xFFE9FFFB)),
    'plum': (Color(0xFF5B2A5E), Color(0xFFFCEBFF)),
  };

  static const fields = <(String, String)>[
    ('superpowers', 'Superpowers'),
    ('skills', 'Skills'),
    ('interests', 'Interests'),
    ('experience', 'Experience'),
    ('schedule', 'Schedule'),
  ];

  static (Color, Color) accent(String id) => accents[id] ?? accents['crimson']!;

  /// The cover behind the headline. [photoUrl] is used for `photo`; without
  /// one the card falls back to Dusk.
  static Decoration cover(String id, {String? photoUrl}) => switch (id) {
        'photo' when photoUrl != null => BoxDecoration(
            color: const Color(0xFF22305A),
            image: DecorationImage(image: NetworkImage(mediaUrl(photoUrl)), fit: BoxFit.cover),
          ),
        'gold' => const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE8C25E), Color(0xFFA8312E)]),
          ),
        'midnight' => const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.6, -0.6),
              radius: 1.3,
              colors: [Color(0xFF6B5A3A), Color(0xFF2C3E70), Color(0xFF15100C)],
              stops: [0, 0.3, 1],
            ),
          ),
        'parchment' => const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.6, -0.5),
              radius: 1.4,
              colors: [Color(0xFFF2DDB1), Color(0xFFF7EEDC), Color(0xFFE6D1A9)],
              stops: [0, 0.35, 1],
            ),
          ),
        'circuit' => const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1F1812), Color(0xFF22305A)],
            ),
          ),
        _ => const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF22305A), Color(0xFF7A1C1C)]),
          ),
      };
}
