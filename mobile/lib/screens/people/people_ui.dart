import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../config.dart';
import '../../models/team_request.dart';
import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';

/// Someone's profile link: `https://crewmatch.netlify.app/u/tara-fernandes`.
/// In the browser it uses the page's own address.
String profileLink(String handle) => '${kIsWeb ? Uri.base.origin : webUrl}/u/$handle';

/// The handle in a profile link or QR code, or a bare handle someone typed.
String? handleFromLink(String text) {
  final t = text.trim().toLowerCase();
  final inLink = RegExp(r'/u/([a-z0-9-]{1,40})').firstMatch(t);
  if (inLink != null) return inLink.group(1);
  return RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(t) && t.length >= 2 ? t : null;
}

/// "Backend · Node.js, MongoDB"
String roleAndSkills(User u) => [
      if (u.role != null) optionLabel(u.role!),
      if (u.skills.isNotEmpty) u.skills.take(2).join(', '),
    ].join(' · ');

/// "In Night Shift" or "Looking for a crew".
String crewStatus(User u) => u.crewName == null ? 'Looking for a crew' : 'In ${u.crewName}';

/// Asks for an optional note and sends the request. Returns what happened,
/// or null if they backed out or it failed (the reason is shown).
Future<SendResult?> showRequestSheet(BuildContext context, User person, RequestSource source) =>
    showModalBottomSheet<SendResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RequestSheet(person: person, source: source),
    );

class _RequestSheet extends StatefulWidget {
  const _RequestSheet({required this.person, required this.source});

  final User person;
  final RequestSource source;

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  static const _quick = ['Want to team up?', 'Need your skills on our idea', 'Looking for a crew too?'];
  final _note = TextEditingController();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final result = await context.api.sendRequest(widget.person.id, note: _note.text, source: widget.source);
      if (mounted) Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showNotice(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.person.name.split(' ').first;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            spacing: 12,
            children: [
              Avatar(url: widget.person.avatar, name: widget.person.name, size: 44, background: Palette.pink),
              Expanded(child: Text('Team up with $first', style: AppType.title(size: 20))),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final q in _quick) ActionChip(label: Text(q), onPressed: () => _note.text = q)],
          ),
          LabeledField(
            label: 'Add a note (optional)',
            controller: _note,
            maxLength: 140,
            maxLines: 3,
            hint: "Say what you're building or what you need",
            textCapitalization: TextCapitalization.sentences,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${140 - _note.text.length} left', style: AppType.body(size: 12, color: Palette.muted)),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _send,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(_busy ? 'Sending…' : 'Send request'),
          ),
        ],
      ),
    );
  }
}

/// Tells you how a sent request went.
void announceSent(BuildContext context, User person, SendResult result) => showNotice(
      context,
      result.match ? 'You and ${person.name.split(' ').first} are a match' : 'Request sent to ${person.name.split(' ').first}',
    );

/// A person in a list: photo, name and fit, role and skills, crew status.
class PersonRow extends StatelessWidget {
  const PersonRow({super.key, required this.person, required this.onTap, this.trailing, this.selected = false});

  final User person;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? Palette.high : Colors.transparent,
        borderRadius: Frame.radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              spacing: 12,
              children: [
                Avatar(url: person.avatar, name: person.name, size: 48, background: Palette.pink),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          Flexible(child: Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 15.5, weight: FontWeight.w500))),
                          if (person.score case final score?) _FitPill(score),
                        ],
                      ),
                      Text(roleAndSkills(person), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13, color: Palette.muted)),
                      Text(
                        crewStatus(person),
                        style: AppType.body(size: 12, weight: FontWeight.w500, color: person.crewName == null ? Palette.link : Palette.muted),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      );
}

class _FitPill extends StatelessWidget {
  const _FitPill(this.score);

  final int score;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: const BoxDecoration(color: Palette.gold, borderRadius: Frame.tagRadius),
        child: Text('$score%', style: AppType.body(size: 11, weight: FontWeight.w700, color: Palette.onGold)),
      );
}
