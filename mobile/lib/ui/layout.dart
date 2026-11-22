import 'package:material_ui/material_ui.dart';

/// Material 3 window sizes. Phones are compact; a tablet or a narrow browser
/// window is medium (side rail, one pane); a wide browser is expanded (side
/// rail, two panes).
enum WindowSize {
  compact,
  medium,
  expanded;

  static WindowSize forWidth(double width) => width < 600
      ? compact
      : width < 840
          ? medium
          : expanded;

  static WindowSize of(BuildContext context) => forWidth(MediaQuery.sizeOf(context).width);

  bool get hasRail => this != compact;
  bool get twoPane => this == expanded;
}
