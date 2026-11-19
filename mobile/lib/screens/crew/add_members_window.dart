import 'package:material_ui/material_ui.dart';

import '../../models/user.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';

/// Matches who could still join the crew, each with an Add button.
class AddMembersWindow extends StatelessWidget {
  const AddMembersWindow({super.key, required this.people, required this.onAdd});

  final List<User> people;
  final ValueChanged<User> onAdd;

  @override
  Widget build(BuildContext context) => RetroWindow(
        title: 'Add from matches',
        child: Column(
          children: [
            for (final (i, person) in people.indexed) ...[
              if (i > 0) const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                child: Row(
                  spacing: 12,
                  children: [
                    Avatar(url: person.avatar, name: person.name, size: 38),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(person.name, style: AppType.body(weight: FontWeight.w600)),
                          Label(roleAndSkill(person), size: 16, color: Palette.mutedDark),
                        ],
                      ),
                    ),
                    OutlinedButton(onPressed: () => onAdd(person), child: const Text('Add')),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
}
