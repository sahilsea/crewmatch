import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/hub_event.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/when.dart';
import 'admin_common.dart';

enum _Filter { all, live, upcoming, challenges, students }

const _filterLabels = {
  _Filter.all: 'All',
  _Filter.live: 'Live',
  _Filter.upcoming: 'Upcoming',
  _Filter.challenges: 'Challenges',
  _Filter.students: 'Community',
};

/// Every event and challenge: a list on the left and the editor on the right
/// (on phones the editor opens as its own page).
class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({
    super.key,
    required this.wide,
    required this.onOpen,
    required this.onChanged,
    this.startNew = false,
  });

  final bool wide;
  final OpenAdminTab onOpen;
  final VoidCallback onChanged;

  /// Opens with a blank "New event" form.
  final bool startNew;

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  List<HubEvent>? _events;
  Object? _error;
  var _filter = _Filter.all;
  final _search = TextEditingController();

  /// The event in the editor; null with [_creating] for a new one.
  String? _selectedId;
  late var _creating = widget.startNew;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
    if (widget.startNew && !widget.wide) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openEditor(null));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final events = await context.api.adminEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _error = null;
        if (widget.wide && _selectedId == null && !_creating && events.isNotEmpty) _selectedId = events.first.id;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  bool _keep(HubEvent e) {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty && !e.title.toLowerCase().contains(q)) return false;
    return switch (_filter) {
      _Filter.all => true,
      _Filter.live => e.state == EventState.live,
      _Filter.upcoming => e.state == EventState.upcoming && e.isOfficial,
      _Filter.challenges => e.isChallenge,
      _Filter.students => !e.isOfficial,
    };
  }

  void _saved(HubEvent saved) {
    setState(() {
      final list = _events ?? [];
      final known = list.any((e) => e.id == saved.id);
      _events = known ? [for (final e in list) e.id == saved.id ? saved : e] : [saved, ...list];
      _selectedId = saved.id;
      _creating = false;
    });
    widget.onChanged();
  }

  void _deleted(String id) {
    setState(() {
      _events = [for (final e in _events ?? <HubEvent>[]) if (e.id != id) e];
      _selectedId = widget.wide && _events!.isNotEmpty ? _events!.first.id : null;
    });
    widget.onChanged();
  }

  Future<void> _openEditor(HubEvent? event) async {
    if (widget.wide) {
      setState(() {
        _selectedId = event?.id;
        _creating = event == null;
      });
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: EventEditor(
              event: event,
              onSaved: (e) {
                _saved(e);
                Navigator.of(context).pop();
              },
              onDeleted: (id) {
                _deleted(id);
                Navigator.of(context).pop();
              },
              onReview: () {
                Navigator.of(context).pop();
                widget.onOpen(AdminTab.review);
              },
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    final header = AdminHeader(
      title: 'Events',
      trailing: FilledButton.icon(
        onPressed: () => _openEditor(null),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('New event'),
      ),
    );
    if (events == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(child: _error == null ? const LoadingView() : ErrorView(error: _error!, onRetry: _load)),
        ],
      );
    }
    final shown = events.where(_keep).toList();
    final list = _EventList(
      events: shown,
      selectedId: widget.wide ? (_creating ? null : _selectedId) : null,
      search: _search,
      filter: _filter,
      onFilter: (f) => setState(() => _filter = f),
      onPick: _openEditor,
      onRefresh: _load,
    );
    if (!widget.wide) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, Expanded(child: list)]);
    }
    HubEvent? selected;
    for (final e in events) {
      if (e.id == _selectedId) selected = e;
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
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, const Duration(milliseconds: 300)),
                    child: _creating || selected != null
                        ? Container(
                            key: ValueKey(_creating ? 'new' : selected!.id),
                            decoration: BoxDecoration(
                              color: Palette.window,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              border: Border.all(color: Palette.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: EventEditor(
                              event: _creating ? null : selected,
                              onSaved: _saved,
                              onDeleted: _deleted,
                              onReview: () => widget.onOpen(AdminTab.review),
                            ),
                          )
                        : const EmptyState(title: 'Pick an event', message: 'Or make a new one.'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({
    required this.events,
    required this.selectedId,
    required this.search,
    required this.filter,
    required this.onFilter,
    required this.onPick,
    required this.onRefresh,
  });

  final List<HubEvent> events;
  final String? selectedId;
  final TextEditingController search;
  final _Filter filter;
  final ValueChanged<_Filter> onFilter;
  final ValueChanged<HubEvent> onPick;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: search,
              decoration: const InputDecoration(hintText: 'Search events', prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterTabs<_Filter>(tabs: _filterLabels, selected: filter, onChanged: onFilter),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: events.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [EmptyState(title: 'No events match', message: 'Try another filter.')],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
                      itemCount: events.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) => SlideIn(
                        key: ValueKey(events[i].id),
                        delay: Motion.stagger(i.clamp(0, 6)),
                        child: _EventRow(event: events[i], selected: events[i].id == selectedId, onTap: () => onPick(events[i])),
                      ),
                    ),
            ),
          ),
        ],
      );
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.selected, required this.onTap});

  final HubEvent event;
  final bool selected;
  final VoidCallback onTap;

  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    final e = event;
    final start = e.startsAt.toLocal();
    final live = e.state == EventState.live;
    final what = e.isChallenge ? 'Challenge' : capitalized(e.category);
    final by = e.host == null ? '' : ' · by ${e.host!.name.split(' ').first}';
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? Palette.high : Palette.window,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: selected ? Palette.dashed : Palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              spacing: 12,
              children: [
                Container(
                  width: 46,
                  height: 50,
                  decoration: BoxDecoration(color: live ? Palette.pink : Palette.high, borderRadius: Frame.buttonRadius),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_days[start.weekday - 1], style: AppType.body(size: 10, weight: FontWeight.w500)),
                      Text('${start.day}', style: AppType.body(size: 18, weight: FontWeight.w700, height: 1.1)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3,
                    children: [
                      Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 15, weight: FontWeight.w500)),
                      Text('$what · ${e.location}$by', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 12, color: Palette.muted)),
                    ],
                  ),
                ),
                StatusPill(e),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Creates or edits one event or challenge.
class EventEditor extends StatefulWidget {
  const EventEditor({
    super.key,
    required this.event,
    required this.onSaved,
    required this.onDeleted,
    required this.onReview,
    this.onClose,
  });

  /// Null for a new event.
  final HubEvent? event;
  final ValueChanged<HubEvent> onSaved;
  final ValueChanged<String> onDeleted;
  final VoidCallback onReview;

  /// Shows a close button (the phone page).
  final VoidCallback? onClose;

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  static const _categories = {
    EventKind.event: ['workshop', 'talk', 'social', 'expo'],
    EventKind.challenge: ['build', 'design', 'pitch', 'quiz'],
  };
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  late final _title = TextEditingController(text: widget.event?.title ?? '');
  late final _summary = TextEditingController(text: widget.event?.summary ?? '');
  late final _where = TextEditingController(text: widget.event?.location ?? '');
  late final _capacity = TextEditingController(text: widget.event?.capacity?.toString() ?? '');
  late var _kind = widget.event?.kind ?? EventKind.event;
  late var _category = widget.event?.category ?? 'workshop';
  late var _starts = widget.event?.startsAt.toLocal() ?? _defaultStart();
  late var _ends = widget.event?.endsAt.toLocal() ?? _defaultStart().add(const Duration(hours: 2));
  late var _points = widget.event?.points ?? 50;
  late var _code = widget.event?.checkinCode ?? _newCode();
  var _busy = false;
  var _confirmDelete = false;
  String? _error;

  static DateTime _defaultStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 10);
  }

  static String _newCode() {
    final r = Random();
    return List.generate(4, (_) => _codeChars[r.nextInt(_codeChars.length)]).join();
  }

  bool get _isNew => widget.event == null;

  /// Students' events earn points only once approved in Review.
  bool get _studentEvent => widget.event != null && !widget.event!.isOfficial;

  @override
  void initState() {
    super.initState();
    for (final c in [_title, _summary]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _summary, _where, _capacity]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _ready => _title.text.trim().length >= 2 && _summary.text.trim().isNotEmpty && !_busy;

  Future<DateTime?> _pick(DateTime from) async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: from,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(from));
    if (time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
      _confirmDelete = false;
    });
    final capacity = int.tryParse(_capacity.text.trim());
    final fields = <String, Object?>{
      'kind': _kind.name,
      'title': _title.text.trim(),
      'summary': _summary.text.trim(),
      'category': _category,
      'location': _where.text.trim(),
      'startsAt': _starts.toUtc().toIso8601String(),
      'endsAt': _ends.toUtc().toIso8601String(),
      'capacity': capacity,
      if (!_studentEvent) 'points': _points,
      if (_kind == EventKind.event) 'checkinCode': _code,
    };
    try {
      final api = context.api;
      final saved = _isNew ? await api.createEvent(fields) : await api.updateEvent(widget.event!.id, fields);
      if (!mounted) return;
      showNotice(context, _isNew ? (saved.checkinCode == null ? 'Challenge created' : 'Created · code ${saved.checkinCode}') : 'Saved ${saved.title}');
      widget.onSaved(saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!_confirmDelete) {
      setState(() => _confirmDelete = true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.api.deleteEvent(widget.event!.id);
      if (!mounted) return;
      showNotice(context, 'Deleted ${widget.event!.title}');
      widget.onDeleted(widget.event!.id);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              Row(
                spacing: 8,
                children: [
                  if (widget.onClose != null)
                    IconButton(tooltip: 'Close', onPressed: widget.onClose, icon: const Icon(Icons.close_rounded)),
                  Expanded(child: Text(_isNew ? 'New event' : 'Edit event', style: AppType.body(size: 19, weight: FontWeight.w700))),
                  if (e != null) StatusPill(e),
                ],
              ),
              const SizedBox(height: 14),
              if (e != null && e.host != null) ...[
                PopIn(child: _HostBanner(event: e, onReview: widget.onReview)),
                const SizedBox(height: 14),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<EventKind>(
                  segments: const [
                    ButtonSegment(value: EventKind.event, label: Text('Event')),
                    ButtonSegment(value: EventKind.challenge, label: Text('Challenge')),
                  ],
                  selected: {_kind},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() {
                    _kind = s.first;
                    _category = _categories[_kind]!.first;
                  }),
                ),
              ),
              const SizedBox(height: 16),
              LabeledField(label: 'Title', controller: _title, maxLength: 80, hint: 'e.g. Wireframes to Widgets'),
              const SizedBox(height: 14),
              LabeledField(label: 'Summary', controller: _summary, maxLength: 140, hint: 'One line people see on the card'),
              const SizedBox(height: 14),
              Fieldset(
                legend: 'Category',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in _categories[_kind]!)
                      OptionChip(label: capitalized(c), selected: c == _category, onTap: () => setState(() => _category = c)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Pair(
                LabeledField(label: 'Location', controller: _where, maxLength: 80, hint: 'Room, hall or Online'),
                LabeledField(label: 'Capacity', controller: _capacity, hint: 'No limit', keyboardType: TextInputType.number),
              ),
              const SizedBox(height: 14),
              _Pair(
                _WhenField(
                  label: _kind == EventKind.challenge ? 'Opens' : 'Starts',
                  value: _starts,
                  onTap: () async {
                    final t = await _pick(_starts);
                    if (t != null) setState(() => _starts = t);
                  },
                ),
                _WhenField(
                  label: _kind == EventKind.challenge ? 'Deadline' : 'Ends',
                  value: _ends,
                  onTap: () async {
                    final t = await _pick(_ends);
                    if (t != null) setState(() => _ends = t);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _Pair(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Label('Points', size: 18, color: Palette.ink),
                    PointsStepper(value: _studentEvent ? 0 : _points, onChanged: _studentEvent ? null : (p) => setState(() => _points = p)),
                    if (_studentEvent) Text('Approve it in Review to award points', style: AppType.body(size: 12.5, color: Palette.muted)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Label(_kind == EventKind.event ? 'Check-in code' : 'Entries', size: 18, color: Palette.ink),
                    if (_kind == EventKind.event)
                      Row(
                        spacing: 8,
                        children: [
                          CodeTiles(_code, size: 42),
                          IconButton.outlined(
                            tooltip: 'New code',
                            onPressed: () => setState(() => _code = _newCode()),
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        height: 42,
                        child: Row(
                          spacing: 6,
                          children: [
                            const Icon(Icons.link_rounded, size: 18, color: Palette.muted),
                            Text('Crews submit a link', style: AppType.body(size: 14, color: Palette.muted)),
                          ],
                        ),
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
                    : TextButton.icon(
                        onPressed: _busy ? null : _delete,
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete'),
                      ),
              FilledButton(
                onPressed: _ready ? _save : null,
                style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
                child: Text(_busy ? 'Saving…' : (_isNew ? 'Create event' : 'Save changes')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Two fields side by side, stacked when narrow.
class _Pair extends StatelessWidget {
  const _Pair(this.a, this.b);

  final Widget a;
  final Widget b;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => c.maxWidth < 440
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 14, children: [a, b])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 14,
                children: [Expanded(child: a), Expanded(child: b)],
              ),
      );
}

class _WhenField extends StatelessWidget {
  const _WhenField({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = '${calendarDate(value)} · ${clock(value)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 5,
      children: [
        Label(label, size: 18, color: Palette.ink),
        Semantics(
          button: true,
          label: '$label: $text',
          excludeSemantics: true,
          child: Material(
            color: Palette.field,
            shape: const RoundedRectangleBorder(borderRadius: Frame.buttonRadius, side: Frame.side),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  spacing: 8,
                  children: [
                    const Icon(Icons.schedule_rounded, size: 18, color: Palette.muted),
                    Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 15))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Who made a student's event and what they asked for.
class _HostBanner extends StatelessWidget {
  const _HostBanner({required this.event, required this.onReview});

  final HubEvent event;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: const BoxDecoration(color: Palette.pink, borderRadius: Frame.buttonRadius),
        child: Row(
          spacing: 12,
          children: [
            Avatar(url: '', name: event.host!.name, size: 36, background: Palette.gold),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: event.host!.name, style: AppType.body(size: 14, weight: FontWeight.w700, color: Palette.onPink)),
                    TextSpan(text: event.isPending ? ' created this · asks for ${event.askedPoints} pts' : ' created this · no points'),
                  ],
                ),
                style: AppType.body(size: 14, color: Palette.onPink),
              ),
            ),
            if (event.isPending) FilledButton(onPressed: onReview, child: const Text('Review')),
          ],
        ),
      );
}
