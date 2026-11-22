import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/api_exception.dart';
import '../../models/team_request.dart';
import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import 'people_ui.dart';
import 'share_card_screen.dart';

/// Someone's profile as its own page: from search, a link or a QR code.
class PersonScreen extends StatelessWidget {
  const PersonScreen({super.key, required this.handle, this.preview, this.source = RequestSource.profile});

  final String handle;
  final User? preview;
  final RequestSource source;

  static Route<void> route(String handle, {User? preview, RequestSource source = RequestSource.profile}) =>
      MaterialPageRoute(builder: (_) => PersonScreen(handle: handle, preview: preview, source: source));

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: PersonView(handle: handle, preview: preview, source: source, onBack: () => Navigator.of(context).pop()),
            ),
          ),
        ),
      );
}

/// The profile: cover, photo, fit, skills, their link, and the team-up action.
/// Also used beside the search results in wide windows.
class PersonView extends StatefulWidget {
  const PersonView({super.key, required this.handle, this.preview, this.source = RequestSource.profile, this.onBack, this.onChanged});

  final String handle;
  final User? preview;
  final RequestSource source;
  final VoidCallback? onBack;

  /// A request was sent, answered or withdrawn (search refreshes its row).
  final ValueChanged<User>? onChanged;

  @override
  State<PersonView> createState() => _PersonViewState();
}

class _PersonViewState extends State<PersonView> {
  late User? _person = widget.preview;
  var _isMe = false;
  var _busy = false;
  var _copied = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final found = await context.api.personByHandle(widget.handle);
      if (!mounted) return;
      setState(() {
        _person = found.user;
        _isMe = found.isMe;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _changed(User p) {
    setState(() => _person = p);
    widget.onChanged?.call(p);
  }

  Future<void> _request() async {
    final p = _person!;
    final result = await showRequestSheet(context, p, widget.source);
    if (result == null || !mounted) return;
    announceSent(context, p, result);
    if (result.match) return _changed(p.copyWith(relation: Relation.matched));
    await _load();
    if (mounted && _person != null) widget.onChanged?.call(_person!);
  }

  Future<void> _run(Future<void> Function() action, Relation next, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _changed(_person!.copyWith(relation: next));
      showNotice(context, done);
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: profileLink(widget.handle)));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _person;
    if (p == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.onBack != null) Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: widget.onBack)),
          Expanded(child: _error == null ? const LoadingView() : ErrorView(error: _error!, onRetry: _load)),
        ],
      );
    }
    final first = p.name.split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Cover(
                onBack: widget.onBack,
                onShare: () => SharePlus.instance.share(ShareParams(text: '${p.name} on CrewMatch: ${profileLink(widget.handle)}')),
              ),
              Transform.translate(
                offset: const Offset(0, -48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      PopIn(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Palette.desktop, shape: BoxShape.circle),
                          child: Avatar(url: p.avatar, name: p.name, size: 96, background: Palette.pink),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(p.name, style: AppType.title(size: 26)),
                      Text(
                        [if (p.role != null) optionLabel(p.role!), if (p.experienceLevel != null) optionLabel(p.experienceLevel!)].join(' · '),
                        style: AppType.body(size: 14, color: Palette.muted),
                      ),
                      InfoTag(crewStatus(p), color: Palette.strip, textColor: p.crewName == null ? Palette.link : Palette.ink),
                      if (p.headline.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(p.headline, style: AppType.body(size: 16, height: 1.5)),
                      ],
                      const SizedBox(height: 10),
                      if (!_isMe && p.score != null) Rise(child: _FitCard(person: p)),
                      if (p.skills.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(spacing: 8, runSpacing: 8, children: [for (final s in p.skills) Chip(label: Text(s))]),
                      ],
                      const SizedBox(height: 10),
                      _LinkRow(link: profileLink(widget.handle), copied: _copied, onCopy: _copy),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(border: Border(top: Frame.side)),
          child: AnimatedSwitcher(
            duration: Motion.of(context, const Duration(milliseconds: 250)),
            child: KeyedSubtree(key: ValueKey((_isMe, p.relation)), child: _action(p, first)),
          ),
        ),
      ],
    );
  }

  Widget _action(User p, String first) {
    final api = context.api;
    if (_isMe) {
      return OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(ShareCardScreen.route()),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        icon: const Icon(Icons.qr_code_rounded),
        label: const Text('This is you · share your card'),
      );
    }
    final id = p.requestId;
    return switch (p.relation) {
      Relation.matched => FilledButton.tonalIcon(
          onPressed: null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.check_rounded),
          label: Text("You're matched with $first"),
        ),
      Relation.sent => Row(
          spacing: 10,
          children: [
            const Icon(Icons.schedule_rounded, color: Palette.muted),
            Expanded(child: Text('Waiting for $first', style: AppType.body(size: 15, weight: FontWeight.w500))),
            if (id != null)
              TextButton(
                onPressed: _busy ? null : () => _run(() => api.withdrawRequest(id), Relation.none, 'Request withdrawn'),
                child: const Text('Withdraw'),
              ),
          ],
        ),
      Relation.received when id != null => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Text('$first asked to team up with you', style: AppType.body(size: 14, color: Palette.muted)),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _run(() => api.declineRequest(id), Relation.none, 'Declined'),
                    child: const Text('Decline', maxLines: 1, softWrap: false),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _run(() => api.acceptRequest(id), Relation.matched, 'You and $first are a match'),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      _ => FilledButton.icon(
          onPressed: _request,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Request to team up'),
        ),
    };
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.onBack, required this.onShare});

  final VoidCallback? onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 140,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned.fill(child: ColoredBox(color: Palette.navy)),
            Positioned(right: -40, top: -60, child: _Blob(200, Palette.gold.withValues(alpha: .25))),
            Positioned(left: 120, bottom: -80, child: _Blob(150, Palette.crimson.withValues(alpha: .45))),
            Positioned(
              left: 4,
              right: 4,
              top: 4,
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(tooltip: 'Back', onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Palette.cream)),
                  const Spacer(),
                  IconButton(tooltip: 'Share profile', onPressed: onShare, icon: const Icon(Icons.share_rounded, color: Palette.cream)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Blob extends StatelessWidget {
  const _Blob(this.size, this.color);

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _FitCard extends StatelessWidget {
  const _FitCard({required this.person});

  final User person;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Palette.window, borderRadius: Frame.radius, border: Frame.border),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              spacing: 8,
              children: [
                Text('${person.score}%', style: AppType.title(size: 30)),
                Text('fit with your crew', style: AppType.body(size: 14, color: Palette.muted)),
              ],
            ),
            for (final tag in person.tags)
              Row(
                spacing: 8,
                children: [
                  const Icon(Icons.check_rounded, size: 18, color: Palette.link),
                  Expanded(child: Text(tag, style: AppType.body(size: 14))),
                ],
              ),
          ],
        ),
      );
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link, required this.copied, required this.onCopy});

  final String link;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: const BoxDecoration(color: Palette.strip, borderRadius: Frame.buttonRadius),
        child: Row(
          spacing: 10,
          children: [
            const Icon(Icons.link_rounded, size: 18, color: Palette.muted),
            Expanded(child: Text(link.replaceFirst(RegExp('^https?://'), ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13))),
            TextButton.icon(onPressed: onCopy, icon: Icon(copied ? Icons.check_rounded : Icons.copy_rounded, size: 16), label: Text(copied ? 'Copied' : 'Copy')),
          ],
        ),
      );
}
