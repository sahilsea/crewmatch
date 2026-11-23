import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/club.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import '../../util/validators.dart';
import '../clubs/club_ui.dart';
import 'admin_common.dart';

/// Organisers create and edit campus clubs, verify them and name their leads.
class AdminClubsScreen extends StatefulWidget {
  const AdminClubsScreen({super.key, required this.wide});

  final bool wide;

  @override
  State<AdminClubsScreen> createState() => _AdminClubsScreenState();
}

class _AdminClubsScreenState extends State<AdminClubsScreen> {
  List<Club>? _clubs;
  Object? _error;
  String? _selectedId;
  var _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final clubs = await context.api.adminClubs();
      if (!mounted) return;
      setState(() {
        _clubs = clubs;
        _error = null;
        if (widget.wide && _selectedId == null && !_creating && clubs.isNotEmpty) _selectedId = clubs.first.id;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _saved(Club c) => setState(() {
        final list = _clubs ?? [];
        _clubs = list.any((x) => x.id == c.id) ? [for (final x in list) x.id == c.id ? c : x] : [c, ...list];
        _selectedId = c.id;
        _creating = false;
      });

  void _deleted(String id) => setState(() {
        _clubs = [for (final x in _clubs ?? <Club>[]) if (x.id != id) x];
        _selectedId = widget.wide && _clubs!.isNotEmpty ? _clubs!.first.id : null;
      });

  Future<void> _open(Club? club) async {
    if (widget.wide) {
      setState(() => (_selectedId = club?.id, _creating = club == null));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: _ClubEditor(
            club: club,
            onClose: () => Navigator.of(context).pop(),
            onSaved: (c) {
              _saved(c);
              Navigator.of(context).pop();
            },
            onDeleted: (id) {
              _deleted(id);
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final header = AdminHeader(
      title: 'Clubs',
      trailing: FilledButton.icon(onPressed: () => _open(null), icon: const Icon(Icons.add_rounded, size: 20), label: const Text('New club')),
    );
    final clubs = _clubs;
    if (clubs == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, Expanded(child: _error == null ? const LoadingView() : ErrorView(error: _error!, onRetry: _load))],
      );
    }
    final list = RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
        itemCount: clubs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          final c = clubs[i];
          final selected = widget.wide && !_creating && c.id == _selectedId;
          return Material(
            color: selected ? Palette.high : Palette.window,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: selected ? Palette.dashed : Palette.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(c),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  spacing: 12,
                  children: [
                    ClubLogo(c),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Row(spacing: 5, children: [Flexible(child: Text(c.name, style: AppType.body(size: 15, weight: FontWeight.w500))), if (c.verified) const VerifiedBadge()]),
                          Text(
                            '${clubCategoryLabel(c.category)} · ${plural(c.memberCount, 'member')} · ${plural(c.leads.length, 'lead')}',
                            style: AppType.body(size: 12, color: Palette.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (!widget.wide) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, Expanded(child: list)]);
    Club? selected;
    for (final c in clubs) {
      if (c.id == _selectedId) selected = c;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [
                SizedBox(width: 380, child: list),
                Expanded(
                  child: _creating || selected != null
                      ? Container(
                          key: ValueKey(_creating ? 'new' : selected!.id),
                          decoration: BoxDecoration(
                            color: Palette.window,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            border: Border.all(color: Palette.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _ClubEditor(club: _creating ? null : selected, onSaved: _saved, onDeleted: _deleted),
                        )
                      : const EmptyState(title: 'Pick a club', message: 'Or make a new one.'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ClubEditor extends StatefulWidget {
  const _ClubEditor({required this.club, required this.onSaved, required this.onDeleted, this.onClose});

  /// Null for a new club.
  final Club? club;
  final ValueChanged<Club> onSaved;
  final ValueChanged<String> onDeleted;
  final VoidCallback? onClose;

  @override
  State<_ClubEditor> createState() => _ClubEditorState();
}

class _ClubEditorState extends State<_ClubEditor> {
  late final _name = TextEditingController(text: widget.club?.name ?? '');
  late final _short = TextEditingController(text: widget.club?.short ?? '');
  late final _about = TextEditingController(text: widget.club?.description ?? '');
  final _lead = TextEditingController();
  late var _category = widget.club?.category ?? 'tech';
  late var _tone = widget.club?.tone ?? 'navy';
  late var _verified = widget.club?.verified ?? false;
  late final _leads = [...?widget.club?.leads];
  var _busy = false;
  var _confirmDelete = false;
  String? _error;

  bool get _isNew => widget.club == null;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _short]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _short, _about, _lead]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addLead() {
    final email = _lead.text.trim().toLowerCase();
    final problem = Validators.email(email);
    if (problem != null) return setState(() => _error = problem);
    setState(() {
      if (!_leads.contains(email)) _leads.add(email);
      _lead.clear();
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() => (_busy = true, _error = null, _confirmDelete = false));
    final fields = {
      'name': _name.text.trim(),
      'short': _short.text.trim().toUpperCase(),
      'category': _category,
      'tone': _tone,
      'description': _about.text.trim(),
      'verified': _verified,
      'leads': _leads,
    };
    try {
      final api = context.api;
      final saved = _isNew ? await api.createClub(fields) : await api.updateClub(widget.club!.id, fields);
      if (!mounted) return;
      showNotice(context, _isNew ? 'Created ${saved.name}' : 'Saved ${saved.name}');
      widget.onSaved(saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!_confirmDelete) return setState(() => _confirmDelete = true);
    setState(() => _busy = true);
    try {
      await context.api.deleteClub(widget.club!.id);
      if (!mounted) return;
      showNotice(context, 'Deleted ${widget.club!.name}');
      widget.onDeleted(widget.club!.id);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ClubTag(id: '', name: _name.text, short: _short.text.isEmpty ? '?' : _short.text.toUpperCase(), tone: _tone);
    final ready = _name.text.trim().length >= 2 && _short.text.trim().isNotEmpty && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              Row(
                spacing: 12,
                children: [
                  if (widget.onClose != null) IconButton(tooltip: 'Close', onPressed: widget.onClose, icon: const Icon(Icons.close_rounded)),
                  ClubLogo(preview, size: 56),
                  Expanded(child: Text(_isNew ? 'New club' : 'Edit club', style: AppType.body(size: 19, weight: FontWeight.w700))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 14,
                children: [
                  Expanded(flex: 3, child: LabeledField(label: 'Name', controller: _name, maxLength: 40, hint: 'e.g. Robotics Society')),
                  Expanded(child: LabeledField(label: 'Short', controller: _short, maxLength: 3, hint: 'RS', textCapitalization: TextCapitalization.characters)),
                ],
              ),
              const SizedBox(height: 14),
              Fieldset(
                legend: 'Category',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in Club.categories)
                      OptionChip(label: clubCategoryLabel(c), selected: c == _category, onTap: () => setState(() => _category = c)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Fieldset(
                legend: 'Colour',
                child: Wrap(
                  spacing: 12,
                  children: [
                    for (final t in Club.tones)
                      Semantics(
                        button: true,
                        selected: t == _tone,
                        label: t,
                        child: InkResponse(
                          onTap: () => setState(() => _tone = t),
                          child: AnimatedContainer(
                            duration: Motion.of(context, const Duration(milliseconds: 200)),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: clubColors(t).$1,
                              shape: BoxShape.circle,
                              border: Border.all(color: t == _tone ? Palette.ink : Palette.border, width: t == _tone ? 3 : 1),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              LabeledField(label: 'About', controller: _about, maxLength: 140, maxLines: 2, hint: 'One line about the club'),
              const SizedBox(height: 14),
              Material(
                color: Palette.strip,
                borderRadius: Frame.radius,
                child: SwitchListTile(
                  value: _verified,
                  onChanged: (v) => setState(() => _verified = v),
                  title: Text('Verified club', style: AppType.body(size: 15, weight: FontWeight.w500)),
                  subtitle: Text('Its events count for points without review', style: AppType.body(size: 13, color: Palette.muted)),
                ),
              ),
              const SizedBox(height: 14),
              Fieldset(
                legend: 'Club leads (can post events for the club)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    if (_leads.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final l in _leads) InputChip(label: Text(l), onDeleted: () => setState(() => _leads.remove(l)))],
                      ),
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _lead,
                            keyboardType: TextInputType.emailAddress,
                            onSubmitted: (_) => _addLead(),
                            decoration: const InputDecoration(hintText: 'lead@college.edu'),
                          ),
                        ),
                        OutlinedButton(onPressed: _addLead, child: const Text('Add')),
                      ],
                    ),
                  ],
                ),
              ),
              if (_error case final error?) ...[const SizedBox(height: 14), ErrorNote(error)],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(border: Border(top: Frame.side)),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              if (!_isNew)
                _confirmDelete
                    ? FilledButton.icon(
                        onPressed: _busy ? null : _delete,
                        style: FilledButton.styleFrom(backgroundColor: Palette.danger),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Tap again to delete'),
                      )
                    : TextButton.icon(onPressed: _busy ? null : _delete, icon: const Icon(Icons.delete_outline_rounded, size: 18), label: const Text('Delete')),
              FilledButton(
                onPressed: ready ? _save : null,
                style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
                child: Text(_busy ? 'Saving…' : (_isNew ? 'Create club' : 'Save changes')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
