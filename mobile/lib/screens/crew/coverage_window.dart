import 'package:material_ui/material_ui.dart';

import '../../models/crew.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';

/// Which must-haves the crew still lacks (frontend, backend, design,
/// pitching), on a navy card. Gold when every role is covered.
class CoverageWindow extends StatelessWidget {
  const CoverageWindow({super.key, required this.crew});

  final Crew crew;

  @override
  Widget build(BuildContext context) {
    final missing = crew.missing.map((key) => checklistLabels[key] ?? key).toList();
    final covered = missing.isEmpty;
    final fg = covered ? Palette.onGold : Palette.cream;
    return Rise(
      delay: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: covered ? Palette.gold : Palette.navy, borderRadius: Frame.radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Row(
              spacing: 8,
              children: [
                Pulse(
                  minScale: 0.85,
                  child: Icon(covered ? Icons.check_circle_rounded : Icons.bolt_rounded, size: 20, color: covered ? Palette.onGold : Palette.gold),
                ),
                Expanded(
                  child: Text(
                    covered ? 'Every role covered' : 'Missing: ${missing.join(', ')}',
                    style: AppType.body(size: 16, weight: FontWeight.w500, color: fg),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
