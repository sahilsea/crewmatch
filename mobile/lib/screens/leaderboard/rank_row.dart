import 'package:material_ui/material_ui.dart';

import '../../models/leaderboard.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';

/// One crew on the leaderboard: rank, name, members, what they did, points.
class RankRow extends StatelessWidget {
  const RankRow({super.key, required this.crew, required this.mine});

  final RankedCrew crew;

  /// The signed-in user's crew, drawn in pink.
  final bool mine;

  /// Podium colours for the top three.
  static const _podium = {1: Palette.pink, 2: Palette.blue, 3: Palette.desktop};

  @override
  Widget build(BuildContext context) {
    final podium = _podium[crew.rank];
    return Semantics(
      label: 'Rank ${crew.rank}, ${crew.name}, ${crew.points} points${mine ? ', your crew' : ''}',
      excludeSemantics: true,
      child: Container(
        color: mine ? Palette.pink.withValues(alpha: 0.55) : null,
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        child: Row(
          spacing: 10,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: podium ?? Palette.inset,
                border: podium == null ? null : Frame.border,
              ),
              child: Label('${crew.rank}', size: 28, color: Palette.ink),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Row(
                    spacing: 6,
                    children: [
                      Flexible(
                        child: Text(
                          crew.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.headline(size: 20),
                        ),
                      ),
                      if (mine) const InkBadge('You'),
                    ],
                  ),
                  Row(
                    spacing: 8,
                    children: [
                      AvatarStack(people: crew.members, size: 24),
                      Flexible(
                        child: Label(
                          '${plural(crew.events, 'event')} · ${plural(crew.challenges, 'challenge')}',
                          size: 15,
                          color: Palette.mutedDark,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Label('${crew.points}', size: 30, color: Palette.ink),
                const Label('pts', size: 15),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
