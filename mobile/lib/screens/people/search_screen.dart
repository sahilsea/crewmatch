import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/club.dart';
import '../../models/team_request.dart';
import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import 'people_ui.dart';
import 'person_screen.dart';
import 'share_card_screen.dart';
import '../clubs/club_ui.dart';

/// Find people by name, skill or role, and send a team-up request.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.club});

  /// Starts filtered to one club's members.
  final ClubTag? club;

  static Route<void> route({ClubTag? club}) => MaterialPageRoute(builder: (_) => SearchScreen(club: club));

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _roles = ['backend', 'frontend', 'fullstack', 'designer', 'ml', 'pm'];

  final _query = TextEditingController();
  Timer? _debounce;
  List<User>? _results;
  Object? _error;
  var _noCrew = false;
  String? _role;
  String? _selectedHandle;
  late ClubTag? _club = widget.club;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _query.addListener(() {
      setState(() {});
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), _load);
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await context.api.searchPeople(query: _query.text, noCrew: _noCrew, role: _role, clubId: _club?.id);
      if (!mounted) return;
      setState(() {
        _results = results;
        _error = null;
        if (_selectedHandle == null || !results.any((r) => r.handle == _selectedHandle)) {
          _selectedHandle = results.isEmpty ? null : results.first.handle;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Filter to one club's members.
  Future<void> _pickClub() async {
    final clubs = await context.api.clubs().catchError((Object _) => <Club>[]);
    if (!mounted || clubs.isEmpty) return;
    final picked = await showModalBottomSheet<Club>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final c in clubs)
            ListTile(
              leading: ClubLogo(c, size: 36),
              title: Text(c.name),
              subtitle: Text(plural(c.memberCount, 'member')),
              onTap: () => Navigator.of(context).pop(c),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _club = picked);
    _load();
  }

  void _replace(User updated) => setState(() {
        _results = [for (final r in _results ?? <User>[]) r.id == updated.id ? updated : r];
      });

  /// The quick Request button on a row: sends without a note.
  Future<void> _quickRequest(User p) async {
    setState(() => _busy.add(p.id));
    try {
      final result = await context.api.sendRequest(p.id, source: RequestSource.search);
      if (!mounted) return;
      announceSent(context, p, result);
      _replace(p.copyWith(relation: result.match ? Relation.matched : Relation.sent));
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  void _open(User p, bool wide) {
    final handle = p.handle;
    if (handle == null) return;
    if (wide) {
      setState(() => _selectedHandle = handle);
      return;
    }
    Navigator.of(context).push(PersonScreen.route(handle, preview: p, source: RequestSource.search)).then((_) => _load());
  }

  Widget _rowAction(User p) {
    final busy = _busy.contains(p.id);
    return switch (p.relation) {
      Relation.matched => const InfoTag('Matched', icon: Icons.check_rounded, color: Palette.navy, textColor: Palette.cream),
      Relation.sent => const InfoTag('Sent', icon: Icons.check_rounded, color: Palette.strip, textColor: Palette.ink),
      Relation.received => const InfoTag('Asked you', color: Palette.gold),
      _ => OutlinedButton.icon(
          onPressed: busy ? null : () => _quickRequest(p),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12)),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text('Request'),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final wide = WindowSize.of(context).twoPane;
    final results = _results;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 8, 4),
      child: Row(
        children: [
          IconButton(tooltip: 'Back', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
          if (wide) Padding(padding: const EdgeInsets.only(left: 4, right: 20), child: Text('Find people', style: AppType.title(size: 26))),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: TextField(
                controller: _query,
                autofocus: !wide,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Name, skill or role',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.text.isEmpty ? null : IconButton(tooltip: 'Clear', onPressed: _query.clear, icon: const Icon(Icons.close_rounded)),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(999))),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Scan a QR code',
            onPressed: () => Navigator.of(context).push(ShareCardScreen.route(scan: true)),
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
    );
    final filters = SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          if (_club case final club?)
            InputChip(
              avatar: ClubLogo(club, size: 22),
              label: Text(club.name),
              selected: true,
              showCheckmark: false,
              onDeleted: () {
                setState(() => _club = null);
                _load();
              },
              deleteButtonTooltipMessage: 'Remove the club filter',
            )
          else
            ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: const Text('Club'), onPressed: _pickClub),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('No crew yet'),
            selected: _noCrew,
            onSelected: (v) {
              setState(() => _noCrew = v);
              _load();
            },
          ),
          for (final r in _roles) ...[
            const SizedBox(width: 8),
            FilterChip(
              label: Text(optionLabel(r)),
              selected: _role == r,
              onSelected: (v) {
                setState(() => _role = v ? r : null);
                _load();
              },
            ),
          ],
        ],
      ),
    );
    final list = switch (results) {
      null when _error != null => ErrorView(error: _error!, onRetry: _load),
      null => const LoadingView(message: 'Finding people…'),
      [] => const EmptyState(title: 'No one matches', message: 'Try a skill like Flutter or Figma.'),
      final List<User> found => RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            itemCount: found.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                  child: Text(_club == null ? plural(found.length, 'person', 'people') : '${plural(found.length, 'member')} of ${_club!.name}', style: AppType.body(size: 13, color: Palette.muted)),
                );
              }
              final p = found[i - 1];
              return SlideIn(
                key: ValueKey(p.id),
                delay: Motion.stagger((i - 1).clamp(0, 8)),
                child: PersonRow(
                  person: p,
                  highlightClubId: _club?.id,
                  selected: wide && p.handle == _selectedHandle,
                  onTap: () => _open(p, wide),
                  trailing: wide ? null : _rowAction(p),
                ),
              );
            },
          ),
        ),
    };
    final selected = _selectedHandle;
    User? preview;
    for (final r in results ?? const <User>[]) {
      if (r.handle == selected) preview = r;
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                filters,
                Expanded(
                  child: !wide
                      ? list
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 20,
                            children: [
                              SizedBox(width: 440, child: list),
                              Expanded(
                                child: selected == null
                                    ? const SizedBox.shrink()
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: Palette.window,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                          border: Border.all(color: Palette.border),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: PersonView(
                                          key: ValueKey(selected),
                                          handle: selected,
                                          preview: preview,
                                          source: RequestSource.search,
                                          onChanged: _replace,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
