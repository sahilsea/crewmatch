import 'package:material_ui/material_ui.dart';

import '../../ui/ui.dart';
import '../../util/labels.dart';

/// A fieldset of option chips. Single choice when [max] is 1.
class ChoiceGroup extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.legend,
    required this.values,
    required this.selected,
    required this.onToggle,
    this.max,
    this.error,
  });

  final String legend;

  /// Allowed values from `GET /options`.
  final List<String> values;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  /// When this many are selected, the other chips are disabled (superpowers).
  final int? max;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final full = max != null && max! > 1 && selected.length >= max!;
    return Fieldset(
      legend: legend,
      error: error,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final value in values)
            OptionChip(
              label: optionLabel(value),
              selected: selected.contains(value),
              onTap: full && !selected.contains(value) ? null : () => onToggle(value),
            ),
        ],
      ),
    );
  }
}
