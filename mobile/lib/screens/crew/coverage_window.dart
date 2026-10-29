import 'package:material_ui/material_ui.dart';

import '../../models/crew.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';

/// Which must-haves the crew covers: frontend, backend, design, pitching.
class CoverageWindow extends StatelessWidget {
  const CoverageWindow({super.key, required this.crew});

  final Crew crew;

  @override
  Widget build(BuildContext context) {
    final missing = crew.missing.map((key) => checklistLabels[key] ?? key).toList();
    return RetroWindow(
      title: 'Coverage',
      inset: false,
      status: missing.isEmpty ? 'All four covered' : '${missing.length} of 4 missing',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 10,
              childAspectRatio: 5,
              children: [
                for (final MapEntry(:key, :value) in checklistLabels.entries)
                  Semantics(
                    label: '$value ${crew.checklist[key] == true ? 'covered' : 'missing'}',
                    excludeSemantics: true,
                    child: Row(
                      spacing: 8,
                      children: [
                        TickBox(checked: crew.checklist[key] == true),
                        Text(value, style: AppType.body()),
                      ],
                    ),
                  ),
              ],
            ),
            if (missing.isNotEmpty && crew.spotsLeft > 0)
              Text(
                'Still missing ${missing.join(' and ')}. '
                'Your deck now ranks people who fill that gap first.',
                style: AppType.body(size: 14, color: Palette.mutedDark),
              ),
          ],
        ),
      ),
    );
  }
}
