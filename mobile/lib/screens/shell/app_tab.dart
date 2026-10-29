import '../../ui/glyphs.dart';

/// The five tabs of the bottom dock.
enum AppTab {
  discover('Discover', Glyph.discover),
  matches('Matches', Glyph.matches),
  crew('Crew', Glyph.crew),
  events('Events', Glyph.events),
  ranks('Ranks', Glyph.ranks);

  const AppTab(this.label, this.glyph);

  final String label;
  final Glyph glyph;
}

/// Lets a screen send the user to another tab, e.g. "See matches".
typedef OpenTab = void Function(AppTab tab);
