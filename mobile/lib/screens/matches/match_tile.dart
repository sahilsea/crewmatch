import 'package:material_ui/material_ui.dart';

import '../../models/crew.dart';
import '../../models/user.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';

/// One match: who they are, how to reach them, and what you can do.
class MatchTile extends StatelessWidget {
  const MatchTile({
    super.key,
    required this.person,
    required this.crew,
    required this.onAddToCrew,
    required this.onUnmatch,
  });

  final User person;

  /// Your crew, if you have one.
  final Crew? crew;
  final VoidCallback onAddToCrew;
  final VoidCallback onUnmatch;

  @override
  Widget build(BuildContext context) {
    final crew = this.crew;
    final email = person.email;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Avatar(url: person.avatar, name: person.name, size: 50),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(person.name, style: AppType.body(size: 16, weight: FontWeight.w600)),
                    Label(personMeta(person), size: 16, color: Palette.mutedDark),
                    if (person.skills.isNotEmpty)
                      Label(person.skills.join(' · '), size: 16, color: Palette.ink, maxLines: 1),
                  ],
                ),
              ),
              if (person.score case final score?) FitBadge(score, size: 17),
            ],
          ),
          if (person.bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(person.bio, style: AppType.body(size: 14.5)),
            ),
          const SizedBox(height: 4),
          if (email != null) CopyText(email),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (crew != null && crew.hasMember(person.id))
                const InkBadge('In your crew')
              else if (person.inCrew)
                const Label('In another crew', color: Palette.mutedDark)
              else if (crew != null && crew.spotsLeft > 0)
                OutlinedButton(onPressed: onAddToCrew, child: const Text('+ Add to crew')),
              const SizedBox(width: 4),
              TextButton(onPressed: onUnmatch, child: const Text('Unmatch')),
            ],
          ),
        ],
      ),
    );
  }
}
