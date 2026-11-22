import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/team_request.dart';
import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/when.dart';
import 'people_ui.dart';
import 'person_screen.dart';
import 'share_card_screen.dart';

/// Team-up requests waiting for you (accept or decline) and the ones you've sent.
class RequestsPane extends StatefulWidget {
  const RequestsPane({super.key, required this.lists, required this.onChanged, required this.onMatched});

  final RequestLists lists;

  /// Something was answered or withdrawn: reload.
  final VoidCallback onChanged;

  /// Accepted: a new match.
  final ValueChanged<User> onMatched;

  @override
  State<RequestsPane> createState() => _RequestsPaneState();
}

class _RequestsPaneState extends State<RequestsPane> {
  final _busy = <String>{};
  final _gone = <String>{};

  Future<void> _answer(TeamRequest r, bool accept) async {
    setState(() => _busy.add(r.id));
    final api = context.api;
    final first = r.user.name.split(' ').first;
    try {
      if (accept) {
        final user = await api.acceptRequest(r.id);
        if (!mounted) return;
        showNotice(context, 'You and $first are a match');
        widget.onMatched(user);
      } else {
        await api.declineRequest(r.id);
        if (!mounted) return;
        showNotice(context, "Declined. $first won't be told");
      }
      setState(() => _gone.add(r.id));
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<void> _withdraw(TeamRequest r) async {
    try {
      await context.api.withdrawRequest(r.id);
      if (!mounted) return;
      setState(() => _gone.add(r.id));
      showNotice(context, 'Request withdrawn');
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    }
  }

  void _open(User u) {
    if (u.handle case final handle?) Navigator.of(context).push(PersonScreen.route(handle, preview: u)).then((_) => widget.onChanged());
  }

  @override
  Widget build(BuildContext context) {
    final incoming = [for (final r in widget.lists.incoming) if (!_gone.contains(r.id)) r];
    final sent = [for (final r in widget.lists.sent) if (!_gone.contains(r.id)) r];
    final now = DateTime.now();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (incoming.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              spacing: 10,
              children: [
                PopIn(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: Palette.gold, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: Palette.onGold),
                  ),
                ),
                Text('No new requests', style: AppType.body(size: 16, weight: FontWeight.w700)),
                TextButton(onPressed: () => Navigator.of(context).push(ShareCardScreen.route()), child: const Text('Share your card to get some ›')),
              ],
            ),
          ),
        for (final (i, r) in incoming.indexed)
          Padding(
            key: ValueKey(r.id),
            padding: const EdgeInsets.only(bottom: 12),
            child: Rise(
              delay: Motion.stagger(i),
              child: _RequestCard(
                request: r,
                ago: r.createdAt == null ? '' : timeAgo(r.createdAt!.toLocal(), now),
                busy: _busy.contains(r.id),
                onOpen: () => _open(r.user),
                onAccept: () => _answer(r, true),
                onDecline: () => _answer(r, false),
              ),
            ),
          ),
        if (sent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text('Sent · ${sent.length}', style: AppType.body(size: 14, weight: FontWeight.w700, color: Palette.muted)),
          ),
          for (final r in sent)
            ListTile(
              key: ValueKey(r.id),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              onTap: () => _open(r.user),
              leading: Avatar(url: r.user.avatar, name: r.user.name, size: 40, background: Palette.pink),
              title: Text(r.user.name, style: AppType.body(size: 15, weight: FontWeight.w500)),
              subtitle: Text(
                'Waiting${r.createdAt == null ? '' : ' · ${timeAgo(r.createdAt!.toLocal(), now)}'}',
                style: AppType.body(size: 12.5, color: Palette.muted),
              ),
              trailing: TextButton(onPressed: () => _withdraw(r), child: const Text('Withdraw')),
            ),
        ],
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.ago,
    required this.busy,
    required this.onOpen,
    required this.onAccept,
    required this.onDecline,
  });

  final TeamRequest request;
  final String ago;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  static IconData _icon(RequestSource s) => switch (s) {
        RequestSource.qr => Icons.qr_code_rounded,
        RequestSource.search => Icons.search_rounded,
        RequestSource.discover => Icons.style_outlined,
        RequestSource.link => Icons.link_rounded,
        RequestSource.profile => Icons.person_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final u = request.user;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Palette.window, borderRadius: BorderRadius.circular(18), border: Frame.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: Frame.buttonRadius,
            child: Row(
              spacing: 12,
              children: [
                Avatar(url: u.avatar, name: u.name, size: 52, background: Palette.pink),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          Flexible(child: Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 16, weight: FontWeight.w500))),
                          if (u.score case final s?)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: const BoxDecoration(color: Palette.gold, borderRadius: Frame.tagRadius),
                              child: Text('$s%', style: AppType.body(size: 11, weight: FontWeight.w700, color: Palette.onGold)),
                            ),
                        ],
                      ),
                      Text(
                        [roleAndSkills(u), if (ago.isNotEmpty) ago].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(size: 13, color: Palette.muted),
                      ),
                    ],
                  ),
                ),
                InfoTag(request.source.label, icon: _icon(request.source), color: Palette.strip, textColor: Palette.ink),
              ],
            ),
          ),
          if (request.note.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(color: Palette.desktop, borderRadius: Frame.buttonRadius),
              child: Text('“${request.note}”', style: AppType.body(size: 15, height: 1.45)),
            ),
          Row(
            spacing: 10,
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(onPressed: busy ? null : onDecline, child: const Text('Decline', maxLines: 1, softWrap: false)),
              ),
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: busy ? null : onAccept,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
