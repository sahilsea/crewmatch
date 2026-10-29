import 'package:material_ui/material_ui.dart';

import '../../models/leaderboard.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import '../shell/app_tab.dart';
import 'masthead.dart';
import 'rank_row.dart';

/// Crews ranked by hackathon points, with yours highlighted.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.onOpen});

  final OpenTab onOpen;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Leaderboard? _board;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final board = await context.api.leaderboard();
      if (mounted) {
        setState(() {
          _board = board;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: RetroWindow(
        title: 'Ranks',
        fill: true,
        status: board == null ? null : '${plural(board.crews.length, 'crew')} · sorted by points',
        child: board == null
            ? (_error == null
                ? const LoadingView(message: 'Counting points…')
                : ErrorView(
                    error: _error!,
                    onRetry: () {
                      setState(() => _error = null);
                      _load();
                    },
                  ))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Masthead(board: board),
                    if (board.myCrewId == null)
                      _JoinPrompt(onTap: () => widget.onOpen(AppTab.crew)),
                    if (board.crews.isEmpty)
                      const EmptyState(
                        title: 'No crews yet',
                        message: 'Crews show up here as soon as they form.',
                      ),
                    for (final (i, crew) in board.crews.indexed) ...[
                      if (i > 0) const Divider(),
                      RankRow(crew: crew, mine: crew.id == board.myCrewId),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _JoinPrompt extends StatelessWidget {
  const _JoinPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        color: Palette.strip,
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        child: Row(
          children: [
            const Expanded(
              child: Label('Your crew is not on the board yet', color: Palette.ink, maxLines: 2),
            ),
            TextButton(onPressed: onTap, child: const Text('Form a crew')),
          ],
        ),
      );
}
