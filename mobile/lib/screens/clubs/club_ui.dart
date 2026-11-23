import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/club.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';

/// "tech" -> "Tech".
String clubCategoryLabel(String c) => c.isEmpty ? c : '${c[0].toUpperCase()}${c.substring(1)}';

/// Fill and text colour for a club's tone.
(Color, Color) clubColors(String tone) => switch (tone) {
      'crimson' => (Palette.crimson, Palette.onCrimson),
      'gold' => (Palette.gold, Palette.onGold),
      'cream' => (Palette.pink, Palette.onPink),
      _ => (Palette.navy, Palette.cream),
    };

/// A club's square logo tile with its short name.
class ClubLogo extends StatelessWidget {
  const ClubLogo(this.club, {super.key, this.size = 44});

  final ClubTag club;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = clubColors(club.tone);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(size * 0.28)),
        child: Text(club.short, style: AppType.title(size: size * 0.36, color: ink)),
      ),
    );
  }
}

/// A club as a small rounded chip: logo and name. [highlight] fills it crimson.
class ClubChip extends StatelessWidget {
  const ClubChip(this.club, {super.key, this.onTap, this.highlight = false});

  final ClubTag club;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Material(
        color: highlight ? Palette.crimson : Palette.strip,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                ClubLogo(club, size: 20),
                Text(
                  club.name,
                  style: AppType.body(size: 12.5, weight: FontWeight.w500, color: highlight ? Palette.onCrimson : Palette.ink),
                ),
              ],
            ),
          ),
        ),
      );
}

/// The ✓ badge for a verified club.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Verified club',
        child: Icon(Icons.verified_rounded, size: size, color: Palette.link, semanticLabel: 'Verified club'),
      );
}

/// Pick up to five clubs for your card. Saves straight away.
Future<void> showClubPicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(heightFactor: 0.8, child: _ClubPicker()),
    );

class _ClubPicker extends StatefulWidget {
  const _ClubPicker();

  @override
  State<_ClubPicker> createState() => _ClubPickerState();
}

class _ClubPickerState extends State<_ClubPicker> {
  static const _max = 5;
  List<Club>? _clubs;
  late final _picked = <String>{...?SessionScope.read(context).user?.clubIds};
  final _query = TextEditingController();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
    context.api.clubs().then((c) {
      if (mounted) setState(() => _clubs = c);
    }, onError: (Object e) {
      if (mounted) showNotice(context, messageOf(e));
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final session = context.session;
    try {
      session.updateUser(await session.api.setMyClubs(_picked.toList()));
      if (!mounted) return;
      Navigator.of(context).pop();
      showNotice(context, 'Clubs saved to your card');
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final shown = [for (final c in _clubs ?? <Club>[]) if (q.isEmpty || c.name.toLowerCase().contains(q)) c];
    final full = _picked.length >= _max;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your clubs', style: AppType.title(size: 22))),
              Text(
                full ? '$_max of $_max · the most' : '${_picked.length} of $_max',
                style: AppType.body(size: 13, color: full ? Palette.link : Palette.muted),
              ),
            ],
          ),
          TextField(
            controller: _query,
            decoration: const InputDecoration(
              hintText: 'Search clubs',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(999))),
            ),
          ),
          Expanded(
            child: _clubs == null
                ? const LoadingView()
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in shown)
                          FilterChip(
                            avatar: ClubLogo(c, size: 24),
                            label: Text(c.name),
                            selected: _picked.contains(c.id),
                            onSelected: (on) {
                              if (on && full) return showNotice(context, 'Pick up to $_max clubs');
                              setState(() => on ? _picked.add(c.id) : _picked.remove(c.id));
                            },
                          ),
                      ],
                    ),
                  ),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
