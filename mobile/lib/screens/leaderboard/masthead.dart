import 'package:material_ui/material_ui.dart';

import '../../models/leaderboard.dart';
import '../../ui/ui.dart';
import '../../util/when.dart';

/// The dark hackathon banner at the top of the leaderboard.
class Masthead extends StatelessWidget {
  const Masthead({super.key, required this.board});

  final Leaderboard board;

  @override
  Widget build(BuildContext context) {
    final mine = board.myCrew;
    final updated = board.updatedAt;
    return Container(
      color: Palette.dark,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            spacing: 8,
            children: [
              const LivePill(inverted: true),
              Expanded(
                child: Label(
                  updated == null ? 'Leaderboard' : 'Leaderboard · updated ${clock(updated)}',
                  color: Palette.darkMuted,
                ),
              ),
            ],
          ),
          Text(board.title.toUpperCase(), style: AppType.title(size: 34, color: Palette.cream)),
          if (mine != null)
            Label(
              'Your crew: ${mine.name} · #${mine.rank} · ${mine.points} pts',
              size: 19,
              color: Palette.pink,
            ),
        ],
      ),
    );
  }
}
