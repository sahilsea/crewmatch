import 'package:material_ui/material_ui.dart';

import '../../models/crew.dart';
import '../../models/user.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';

/// One match as a compact row: avatar, name, role, fit and an Add button.
/// Tapping the row opens their details, with email and Unmatch.
class MatchTile extends StatelessWidget {
  const MatchTile({
    super.key,
    required this.person,
    required this.crew,
    required this.onAddToCrew,
    required this.onRemoveFromCrew,
    required this.onUnmatch,
  });

  final User person;

  /// Your crew, if you have one.
  final Crew? crew;
  final VoidCallback onAddToCrew;
  final VoidCallback onRemoveFromCrew;
  final VoidCallback onUnmatch;

  @override
  Widget build(BuildContext context) {
    final crew = this.crew;
    final added = crew != null && crew.hasMember(person.id);
    final role = person.role == null ? '' : optionLabel(person.role!);
    return Material(
      type: MaterialType.transparency,
      shape: const RoundedRectangleBorder(borderRadius: Frame.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            spacing: 12,
            children: [
              AnimatedContainer(
                duration: Motion.of(context, const Duration(milliseconds: 300)),
                curve: Motion.ease,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: added ? Palette.gold : Colors.transparent, width: 2),
                ),
                child: Avatar(url: person.avatar, name: person.name, size: 46, background: Palette.pink),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 16, weight: FontWeight.w500)),
                    Text(
                      [if (role.isNotEmpty) role, if (person.score != null) '${person.score}% fit'].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body(size: 13, color: Palette.muted),
                    ),
                  ],
                ),
              ),
              _AddButton(
                added: added,
                elsewhere: !added && person.inCrew,
                full: crew != null && crew.spotsLeft == 0,
                onAdd: onAddToCrew,
                onRemove: onRemoveFromCrew,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Row(
                  spacing: 14,
                  children: [
                    Avatar(url: person.avatar, name: person.name, size: 56, background: Palette.pink),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(person.name, style: AppType.title(size: 20)),
                          Text(personMeta(person), style: AppType.body(size: 14, color: Palette.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (person.bio.isNotEmpty) Text(person.bio, style: AppType.body(size: 15)),
                if (person.skills.isNotEmpty)
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final s in person.skills) InfoTag(s, color: Palette.strip, textColor: Palette.ink)]),
                if (person.email case final email?) CopyText(email),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onUnmatch();
                    },
                    child: const Text('Unmatch'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// "Add" until they join your crew, then a navy "✓ Added" that pops in.
/// Tapping "✓ Added" takes them out again. When the crew is full, "Add"
/// looks quieter but still explains why it can't add.
class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.added,
    required this.elsewhere,
    required this.full,
    required this.onAdd,
    required this.onRemove,
  });

  final bool added;
  final bool elsewhere;
  final bool full;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (elsewhere) return Text('In a crew', style: AppType.body(size: 13, color: Palette.muted));
    return AnimatedSwitcher(
      duration: Motion.of(context, const Duration(milliseconds: 300)),
      switchInCurve: Motion.ease,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)),
      child: added
          ? Tooltip(
              message: 'Remove from crew',
              child: FilledButton(
                key: const ValueKey('added'),
                onPressed: onRemove,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(76, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  backgroundColor: Palette.navy,
                  foregroundColor: Palette.cream,
                  textStyle: AppType.body(size: 14, weight: FontWeight.w500),
                ),
                child: const Text('✓ Added'),
              ),
            )
          : OutlinedButton(
              key: const ValueKey('add'),
              onPressed: onAdd,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(76, 40),
                foregroundColor: full ? Palette.muted : Palette.ink,
                side: BorderSide(color: full ? Palette.border : Palette.dashed),
                textStyle: AppType.body(size: 14, weight: FontWeight.w500),
              ),
              child: const Text('Add'),
            ),
    );
  }
}
