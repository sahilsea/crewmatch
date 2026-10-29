import 'package:material_ui/material_ui.dart';

import '../../models/crew.dart';
import '../../models/user.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';

/// The crew's name, size, score and members, with rename and leave.
class CrewWindow extends StatelessWidget {
  const CrewWindow({
    super.key,
    required this.crew,
    required this.myId,
    required this.onRename,
    required this.onLeave,
  });

  final Crew crew;
  final String? myId;
  final VoidCallback onRename;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final spots = crew.spotsLeft;
    return RetroWindow(
      title: 'Crew',
      inset: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(border: Border(bottom: Frame.side)),
            child: Halftone(
              color: Palette.blue,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(crew.name, style: AppType.headline(size: 34)),
                    Row(
                      children: [
                        Expanded(
                          child: Label(
                            '${crew.members.length} of ${Crew.maxSize}'
                            '${spots > 0 ? ' · ${plural(spots, 'spot')} left' : ' · full'}',
                            size: 18,
                            color: Palette.ink,
                          ),
                        ),
                        TextButton(onPressed: onRename, child: const Text('Rename')),
                        const SizedBox(width: 6),
                        DashedButton(label: 'Leave', onPressed: onLeave),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          _ScoreStrip(crew: crew),
          for (final (i, member) in crew.members.indexed) ...[
            if (i > 0) const DashedLine(),
            _MemberRow(member: member, isMe: member.id == myId),
          ],
        ],
      ),
    );
  }
}

/// Dark strip with the crew's hackathon points and leaderboard rank.
class _ScoreStrip extends StatelessWidget {
  const _ScoreStrip({required this.crew});

  final Crew crew;

  @override
  Widget build(BuildContext context) => Container(
        color: Palette.dark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Expanded(child: Label('Hackathon score', color: Palette.darkMuted)),
            Label('${crew.points} pts', size: 24, color: Palette.cream),
            if (crew.rank case final rank?) ...[
              const SizedBox(width: 10),
              InkBadge('Rank #$rank', inverted: true),
            ],
          ],
        ),
      );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.isMe});

  final User member;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final email = member.email;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        spacing: 12,
        children: [
          Avatar(url: member.avatar, name: member.name, size: 42),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: 6,
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(size: 15.5, weight: FontWeight.w600),
                      ),
                    ),
                    if (isMe) const InkBadge('You'),
                  ],
                ),
                Label(roleAndSkill(member), size: 16, color: Palette.mutedDark),
              ],
            ),
          ),
          if (!isMe && email != null) CopyText(email, label: 'Email'),
        ],
      ),
    );
  }
}
