import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/crew.dart';
import '../../models/user.dart';
import '../../models/post.dart';
import '../../state/chat_read.dart';
import '../../state/session.dart';
import '../chat/chat_screen.dart';
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

  /// The newest chat line and how many came in since you last read.
  ChatMessage? _lastMessage;
  var _unread = 0;
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
      if (crew != null) _loadChat(crew);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadChat(Crew crew) async {
    try {
      final me = context.session.user?.id;
      final (messages, read) = await waitBoth(context.api.messages(), ChatRead.lastRead(crew.id));
      if (!mounted) return;
      setState(() {
        _lastMessage = messages.lastOrNull;
        _unread = messages.where((m) => m.author?.id != me && (read == null || m.createdAt.isAfter(read))).length;
      });
    } catch (_) {
      // The card just shows no preview.
    }
  }

  Future<void> _openChat(Crew crew) async {
    await Navigator.of(context).push(ChatScreen.route(crew));
    if (mounted) _loadChat(crew);
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

  Future<void> _remove(User person) async {
    final confirmed = await confirmAction(
      context,
      title: 'Remove from crew',
      message: 'Take ${person.name} out of ${_crew?.name ?? 'your crew'}?',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;
    await _act(() async {
      final crew = await context.api.removeCrewMember(person.id);
      if (!mounted) return;
      setState(() {
        _crew = crew;
        _matches = [
          for (final m in _matches) m.id == person.id ? m.copyWith(inCrew: false) : m,
        ];
      });
    });
  }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: crew == null ? 'Start a crew' : 'Your crew',
          subtitle: crew == null ? null : '${crew.members.length} of ${Crew.maxSize}',
          trailing: crew == null
              ? null
              : IconButton(
                  tooltip: _unread > 0 ? 'Crew chat, $_unread new' : 'Crew chat',
                  onPressed: () => _openChat(crew),
                  icon: Badge(
                    isLabelVisible: _unread > 0,
                    label: Text('$_unread'),
                    backgroundColor: Palette.crimson,
                    textColor: Palette.onCrimson,
                    child: const Icon(Icons.chat_bubble_outline_rounded, color: Palette.ink),
                  ),
                ),
        ),
        Expanded(
          child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
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
              onRemove: _remove,
              chat: Rise(
                delay: const Duration(milliseconds: 80),
                child: _ChatCard(last: _lastMessage, unread: _unread, onTap: () => _openChat(crew)),
              ),
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
          ),
        ),
      ],
    );
  }
}

/// "Crew chat" with the latest line and an unread count; opens the chat.
class _ChatCard extends StatelessWidget {
  const _ChatCard({required this.last, required this.unread, required this.onTap});

  final ChatMessage? last;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = this.last;
    final preview = last == null
        ? 'Only your crew can see it'
        : last.system
            ? last.text
            : '${last.author?.name.split(' ').first ?? 'Someone'}: ${last.text}';
    return Material(
      color: Palette.strip,
      shape: const RoundedRectangleBorder(borderRadius: Frame.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            spacing: 12,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Palette.crimson, borderRadius: Frame.buttonRadius),
                child: const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: Palette.onCrimson),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text('Crew chat', style: AppType.body(size: 15, weight: FontWeight.w500)),
                    Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13, color: Palette.muted)),
                  ],
                ),
              ),
              if (unread > 0) CountBadge(unread) else const Icon(Icons.chevron_right_rounded, color: Palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}
