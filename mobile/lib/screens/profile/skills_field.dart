import 'package:material_ui/material_ui.dart';

import '../../ui/ui.dart';

/// Free-text skills: type one (or several, comma-separated) and press enter.
/// Tap a skill to remove it.
class SkillsField extends StatelessWidget {
  const SkillsField({
    super.key,
    required this.skills,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
    this.error,
  });

  final List<String> skills;
  final TextEditingController controller;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final String? error;

  @override
  Widget build(BuildContext context) => Fieldset(
        legend: 'Skills (type, then enter)',
        error: error,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            if (skills.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final skill in skills) _SkillChip(skill, onRemove: () => onRemove(skill)),
                ],
              ),
            TextField(
              controller: controller,
              maxLength: 60,
              textInputAction: TextInputAction.done,
              style: AppType.body(size: 16),
              decoration: const InputDecoration(
                hintText: 'React, Figma, Python…',
                counterText: '',
              ),
              onSubmitted: onAdd,
              onChanged: (text) {
                if (text.contains(',')) onAdd(text);
              },
            ),
          ],
        ),
      );
}

class _SkillChip extends StatelessWidget {
  const _SkillChip(this.skill, {required this.onRemove});

  final String skill;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: 'Remove $skill',
        excludeSemantics: true,
        child: Material(
          color: Palette.blue,
          shape: const RoundedRectangleBorder(
            side: Frame.side,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          child: InkWell(
            onTap: onRemove,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(skill, style: AppType.body()),
                  const SizedBox(width: 6),
                  Text('×', style: AppType.body(size: 18, height: 1)),
                ],
              ),
            ),
          ),
        ),
      );
}
