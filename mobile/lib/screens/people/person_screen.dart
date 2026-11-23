import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/api_exception.dart';
import '../../models/team_request.dart';
import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../clubs/club_screen.dart';
import '../clubs/club_ui.dart';
import '../../util/labels.dart';
import '../discover/fit_details.dart';
import '../discover/profile_card.dart';
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
              constraints: const BoxConstraints(maxWidth: 1040),
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

  /// Their handle once loaded; until then whatever opened the page (a handle or an id).
  String get _key => _person?.handle ?? widget.handle;

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
    await Clipboard.setData(ClipboardData(text: profileLink(_key)));
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
                person: p,
                onBack: widget.onBack,
                onShare: () => SharePlus.instance.share(ShareParams(text: '${p.name} on CrewMatch: ${profileLink(_key)}')),
              ),
              Transform.translate(
                offset: const Offset(0, -48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LayoutBuilder(builder: (context, box) => _body(p, wide: box.maxWidth >= 720)),
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

  Widget _body(User p, {required bool wide}) {
    final about = p.bio.isNotEmpty && p.bio != p.headline ? p.bio : null;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        PopIn(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Palette.desktop, shape: BoxShape.circle),
            child: Avatar(url: p.avatar, name: p.name, size: wide ? 112 : 96, background: Palette.pink),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          spacing: 10,
          children: [
            Flexible(child: Text(p.name, style: AppType.title(size: wide ? 30 : 26))),
            if (p.demo) const DemoBadge(),
            if (!_isMe && p.score != null) InfoTag('${p.score}% fit', color: Palette.gold, textColor: Palette.onGold),
          ],
        ),
        Text(
          [if (p.role != null) optionLabel(p.role!), if (p.experienceLevel != null) optionLabel(p.experienceLevel!)].join(' · '),
          style: AppType.body(size: 14, color: Palette.muted),
        ),
        InfoTag(crewStatus(p), color: Palette.strip, textColor: p.crewName == null ? Palette.link : Palette.ink),
        if (p.headline.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(p.headline, style: AppType.body(size: 17, height: 1.5)),
        ],
      ],
    );
    Widget chips(List<String> items, Color color, Color text) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final i in items) InfoTag(optionLabel(i), color: color, textColor: text)],
        );
    final main = [
      if (about != null) DetailSection(title: 'About', children: [Text(about, style: AppType.body(size: 15.5, height: 1.55))]),
      if (!_isMe) WhyFitSection(p),
      WorkStyleSection(p, compare: !_isMe),
    ];
    final side = [
      RecordSection(p),
      if (p.clubs.isNotEmpty)
        DetailSection(title: 'Clubs', children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final c in p.clubs) ClubChip(c, onTap: () => Navigator.of(context).push(ClubScreen.route(c.id)))],
          ),
        ]),
      if (p.superpowers.isNotEmpty) DetailSection(title: 'Superpowers', children: [chips(p.superpowers, Palette.navy, Palette.cream)]),
      if (p.skills.isNotEmpty) DetailSection(title: 'Skills', children: [chips(p.skills, Palette.strip, Palette.ink)]),
      if (p.interests.isNotEmpty) DetailSection(title: 'Interests', children: [chips(p.interests, Palette.pink, Palette.onPink)]),
      _LinkRow(link: profileLink(_key), copied: _copied, onCopy: _copy),
    ];
    Widget column(List<Widget> items) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 26, children: items);
    Widget card(List<Widget> items) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Palette.window, borderRadius: Frame.radius, border: Frame.border),
          child: column(items),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        header,
        Rise(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 20,
                  children: [Expanded(flex: 6, child: card(main)), Expanded(flex: 5, child: card(side))],
                )
              : column([...main, ...side]),
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
  const _Cover({required this.person, required this.onBack, required this.onShare});

  final User person;
  final VoidCallback? onBack;
  final VoidCallback onShare;

  static final _scrim = IconButton.styleFrom(backgroundColor: const Color(0x59000000));

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 170,
        child: DecoratedBox(
          decoration: CardStyle.cover(person.cover, photoUrl: person.coverUrl),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (person.coverUrl == null) const CustomPaint(painter: DotsPainter()),
              Positioned(
                left: 10,
                right: 10,
                top: 10,
                child: Row(
                  children: [
                    if (onBack != null)
                      IconButton(tooltip: 'Back', onPressed: onBack, style: _scrim, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                    const Spacer(),
                    IconButton(tooltip: 'Share profile', onPressed: onShare, style: _scrim, icon: const Icon(Icons.share_rounded, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
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
