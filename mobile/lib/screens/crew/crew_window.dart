import 'package:material_ui/material_ui.dart';

import '../../models/crew.dart';
import '../../models/user.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';

enum _CrewAction { rename, leave }

/// The crew's summary card (name, points, rank, size) and its members, with
/// rename and leave in the card's menu.
class CrewWindow extends StatelessWidget {
  const CrewWindow({
    super.key,
    required this.crew,
    required this.myId,
    required this.onRename,
    required this.onLeave,
    required this.onRemove,
    this.chat,
  });

  /// The crew chat card, under the summary.
  final Widget? chat;

  final Crew crew;
  final String? myId;
  final VoidCallback onRename;
  final VoidCallback onLeave;

  /// Takes another member out. Only offered while the crew has more than two.
  final ValueChanged<User> onRemove;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Rise(
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 8, 18),
              decoration: const BoxDecoration(color: Palette.pink, borderRadius: Frame.radius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          crew.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.title(size: 26, color: Palette.onPink),
                        ),
                      ),
                      PopupMenuButton<_CrewAction>(
                        tooltip: 'Crew options',
                        icon: const Icon(Icons.more_vert_rounded, color: Palette.muted),
                        onSelected: (action) => switch (action) {
                          _CrewAction.rename => onRename(),
                          _CrewAction.leave => onLeave(),
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: _CrewAction.rename, child: Text('Rename crew')),
                          PopupMenuItem(value: _CrewAction.leave, child: Text('Leave crew')),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Row(
                      spacing: 8,
                      children: [
                        Expanded(child: _Stat(label: 'Points', child: CountUp(crew.points, style: _statStyle))),
                        Expanded(child: _Stat(label: 'Rank', child: Text(crew.rank == null ? '–' : '#${crew.rank}', style: _statStyle))),
                        Expanded(
                          child: _Stat(
                            label: 'Members',
                            child: Text('${crew.members.length}/${Crew.maxSize}', style: _statStyle),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ?chat,
          Column(
            children: [
              for (final (i, member) in crew.members.indexed)
                Rise(
                  key: ValueKey(member.id),
                  delay: Motion.stagger(i + 1),
                  child: _MemberRow(
                    member: member,
                    isMe: member.id == myId,
                    onRemove: member.id != myId && crew.members.length > 2 ? () => onRemove(member) : null,
                  ),
                ),
              for (var i = 0; i < crew.spotsLeft; i++)
                Rise(delay: Motion.stagger(crew.members.length + i + 1), child: const _OpenSpot()),
            ],
          ),
        ],
      );

  static final _statStyle = AppType.body(size: 22, weight: FontWeight.w700);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(color: Palette.desktop, borderRadius: Frame.buttonRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [child, Text(label, style: AppType.body(size: 12, color: Palette.muted))],
        ),
      );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.isMe, this.onRemove});

  final User member;
  final bool isMe;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final email = member.email;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        spacing: 14,
        children: [
          Avatar(url: member.avatar, name: member.name, size: 44, background: isMe ? Palette.gold : Palette.pink),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(size: 16, weight: FontWeight.w500),
                      ),
                    ),
                    if (isMe) const InkBadge('You'),
                  ],
                ),
                Text(roleAndSkill(member), style: AppType.body(size: 14, color: Palette.muted)),
              ],
            ),
          ),
          if (!isMe && email != null) CopyText(email, label: 'Email'),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove ${member.name}',
              onPressed: onRemove,
              icon: const Icon(Icons.person_remove_outlined, size: 22, color: Palette.muted),
            ),
        ],
      ),
    );
  }
}

/// An empty seat: a dashed circle whose outline glows gold now and then.
class _OpenSpot extends StatelessWidget {
  const _OpenSpot();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          spacing: 14,
          children: [
            const Pulse(
              minScale: 0.92,
              period: Duration(milliseconds: 1000),
              child: DashedBorder(
                radius: 22,
                color: Palette.dashed,
                child: SizedBox.square(dimension: 44),
              ),
            ),
            Text('Open', style: AppType.body(size: 15, color: Palette.muted)),
          ],
        ),
      );
}
