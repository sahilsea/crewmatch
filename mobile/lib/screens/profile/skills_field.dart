import 'package:material_ui/material_ui.dart';

import '../../ui/ui.dart';

/// Free-text skills. A skill is added on comma, Enter, the Add button, or
/// when you leave the field, so typed text is never silently left behind.
/// Common skills can be added with one tap. Tap a skill to remove it.
class SkillsField extends StatefulWidget {
  const SkillsField({
    super.key,
    required this.skills,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
    this.onTyping,
    this.error,
  });

  final List<String> skills;
  final TextEditingController controller;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  /// Called as the text changes, so the form can count unfinished text.
  final VoidCallback? onTyping;
  final String? error;

  static const suggestions = [
    'Python',
    'JavaScript',
    'React',
    'Node.js',
    'Flutter',
    'Java',
    'Figma',
    'UI/UX',
    'Machine Learning',
    'SQL',
    'MongoDB',
    'Public speaking',
  ];

  @override
  State<SkillsField> createState() => _SkillsFieldState();
}

class _SkillsFieldState extends State<SkillsField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Leaving the field adds whatever was typed.
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    if (widget.controller.text.trim().isNotEmpty) widget.onAdd(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final typed = widget.controller.text.trim();
    final have = {for (final s in widget.skills) s.toLowerCase()};
    final suggestions = [
      for (final s in SkillsField.suggestions)
        if (!have.contains(s.toLowerCase())) s,
    ];
    return Fieldset(
      legend: 'Skills',
      error: widget.error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          if (widget.skills.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in widget.skills)
                  _SkillChip(key: ValueKey(skill), skill: skill, onRemove: () => widget.onRemove(skill)),
              ],
            ),
          TextField(
            controller: widget.controller,
            focusNode: _focus,
            maxLength: 60,
            textInputAction: TextInputAction.done,
            style: AppType.body(size: 16),
            decoration: InputDecoration(
              hintText: widget.skills.isEmpty ? 'Type a skill, e.g. React' : 'Add another skill',
              counterText: '',
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton.icon(
                  onPressed: typed.isEmpty ? null : _commit,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                ),
              ),
            ),
            onSubmitted: (_) {
              _commit();
              _focus.requestFocus();
            },
            onChanged: (text) {
              if (text.contains(',')) widget.onAdd(text);
              widget.onTyping?.call();
            },
          ),
          Text(
            typed.isEmpty
                ? 'Press Enter or a comma after each skill. Tap a skill to remove it.'
                : 'Press Enter or Add to keep “$typed”',
            style: AppType.body(size: 12.5, color: typed.isEmpty ? Palette.muted : Palette.link),
          ),
          if (suggestions.isNotEmpty && widget.skills.length < 15)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Quick add:', style: AppType.body(size: 12.5, color: Palette.muted)),
                for (final s in suggestions.take(8))
                  ActionChip(
                    label: Text(s),
                    avatar: const Icon(Icons.add_rounded, size: 16),
                    onPressed: () => widget.onAdd(s),
                    shape: const StadiumBorder(side: BorderSide(color: Palette.border)),
                    backgroundColor: Palette.window,
                    labelStyle: AppType.body(size: 13),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({super.key, required this.skill, required this.onRemove});

  final String skill;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => PopIn(
    child: InputChip(
      label: Text(skill),
      onDeleted: onRemove,
      onPressed: onRemove,
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
      deleteButtonTooltipMessage: 'Remove $skill',
      backgroundColor: Palette.gold,
      labelStyle: AppType.body(size: 14, weight: FontWeight.w500, color: Palette.onGold),
      deleteIconColor: Palette.onGold,
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
  );
}
