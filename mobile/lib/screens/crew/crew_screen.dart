import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/crew.dart';
import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/parallel.dart';
import '../shell/app_tab.dart';
import 'add_members_window.dart';
import 'coverage_window.dart';
import 'crew_window.dart';
import 'rename_crew_dialog.dart';
import 'start_crew_window.dart';

/// Your crew of up to four: who's in it, what it covers, its hackathon score.
/// Without a crew, a form to start one from your matches.
class CrewScreen extends StatefulWidget {
  const CrewScreen({super.key, required this.onOpen});

  final OpenTab onOpen;

  @override
  State<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends State<CrewScreen> {
  Crew? _crew;
  List<User> _matches = const [];
  var _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.api;
    try {
      final (crew, matches) = await waitBoth(api.myCrew(), api.matches());
      if (!mounted) return;
      setState(() {
        _crew = crew;
        _matches = matches;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Runs a crew action and shows any API error as a notice.
  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    }
  }

  Future<void> _created(Crew crew) async {
    setState(() => _crew = crew);
    await context.session.refreshUser();
    await _load();
  }

  Future<void> _add(User person) => _act(() async {
        final crew = await context.api.addCrewMember(person.id);
        if (!mounted) return;
        setState(() {
          _crew = crew;
          _matches = [
            for (final m in _matches) m.id == person.id ? m.copyWith(inCrew: true) : m,
          ];
        });
      });

  Future<void> _rename(Crew crew) async {
    final renamed = await showRenameCrewDialog(context, crew);
    if (renamed != null && mounted) setState(() => _crew = renamed);
  }

  Future<void> _leave(Crew crew) async {
    final confirmed = await confirmAction(
      context,
      title: 'Leave crew',
      message: crew.members.length <= 2
          ? 'Leave ${crew.name}? With one person left, the crew will be dissolved.'
          : 'Leave ${crew.name}? The others keep the crew and its points.',
      confirmLabel: 'Leave',
    );
    if (!confirmed || !mounted) return;
    final session = context.session;
    await _act(() async {
      await session.api.leaveCrew();
      await session.refreshUser();
      if (mounted) setState(() => _crew = null);
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: RetroWindow(
          title: 'Crew',
          fill: true,
          child: _error == null
              ? const LoadingView()
              : ErrorView(
                  error: _error!,
                  onRetry: () {
                    setState(() => _error = null);
                    _load();
                  },
                ),
        ),
      );
    }

    final crew = _crew;
    final me = context.session.user;
    final addable = [
      for (final m in _matches)
        if (!m.inCrew && !(crew?.hasMember(m.id) ?? false)) m,
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          if (crew == null)
            StartCrewWindow(
              matches: _matches,
              onCreated: _created,
              onFindPeople: () => widget.onOpen(AppTab.discover),
            )
          else ...[
            CrewWindow(
              crew: crew,
              myId: me?.id,
              onRename: () => _rename(crew),
              onLeave: () => _leave(crew),
            ),
            const SizedBox(height: 14),
            CoverageWindow(crew: crew),
            if (crew.spotsLeft > 0 && addable.isNotEmpty) ...[
              const SizedBox(height: 14),
              AddMembersWindow(people: addable, onAdd: _add),
            ],
          ],
        ],
      ),
    );
  }
}
