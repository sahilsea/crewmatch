import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/hub_event.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/when.dart';

/// A student hosts their own event or challenge. It goes live straight away
/// as a community event; asking for points sends it to the organisers.
class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  /// Pops with the new event once it's published, or null.
  static Route<HubEvent> route() => MaterialPageRoute(builder: (_) => const CreateEventScreen());

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  static const _categories = {
    EventKind.event: ['workshop', 'talk', 'social', 'expo'],
    EventKind.challenge: ['build', 'design', 'pitch', 'quiz'],
  };
  static const _asks = [10, 20, 30, 50];

  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _where = TextEditingController();
  var _kind = EventKind.event;
  var _category = 'workshop';
  late DateTime _day;
  var _start = const TimeOfDay(hour: 18, minute: 0);
  var _end = const TimeOfDay(hour: 20, minute: 0);
  var _ask = false;
  var _askPoints = 20;
  var _busy = false;
  String? _error;
  HubEvent? _made;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day + 1);
    for (final c in [_title, _summary]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _where.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay t) => DateTime(_day.year, _day.month, _day.day, t.hour, t.minute);

  bool get _ready => _title.text.trim().length >= 2 && _summary.text.trim().isNotEmpty && !_busy;

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day != null) setState(() => _day = day);
  }

  Future<void> _pickTime(bool start) async {
    final time = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (time == null) return;
    setState(() => start ? _start = time : _end = time);
  }

  Future<void> _publish() async {
    final startsAt = _at(_start);
    var endsAt = _at(_end);
    // An end before the start means it runs past midnight.
    if (!endsAt.isAfter(startsAt)) endsAt = endsAt.add(const Duration(days: 1));
    if (!endsAt.isAfter(DateTime.now())) {
      setState(() => _error = 'Pick an end time in the future');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final made = await context.api.hostEvent({
        'kind': _kind.name,
        'title': _title.text.trim(),
        'summary': _summary.text.trim(),
        'category': _category,
        if (_where.text.trim().isNotEmpty) 'location': _where.text.trim(),
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'askPoints': _ask ? _askPoints : 0,
      });
      if (mounted) setState(() => _made = made);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _again() => setState(() {
    _made = null;
    _title.clear();
    _summary.clear();
    _where.clear();
    _ask = false;
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                title: _made == null ? 'New event' : 'Event posted',
                leading: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(_made),
                  icon: const Icon(Icons.close_rounded, color: Palette.ink),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.of(context, const Duration(milliseconds: 350)),
                  child: _made == null ? _form() : _Published(event: _made!, onAgain: _again),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _form() => Column(
    key: const ValueKey('form'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            Rise(
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
            LabeledField(
              label: 'Title',
              controller: _title,
              maxLength: 80,
              hint: _kind == EventKind.event ? 'e.g. Flutter study jam' : 'e.g. Build a bot in a day',
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'What happens',
              controller: _summary,
              maxLength: 140,
              maxLines: 2,
              hint: 'One line people see on the card',
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),
            Fieldset(
              legend: 'Category',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _categories[_kind]!)
                    OptionChip(label: _cap(c), selected: c == _category, onTap: () => setState(() => _category = c)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  flex: 4,
                  child: _PickField(label: 'Date', value: calendarDate(_day), onTap: _pickDay),
                ),
                Expanded(
                  flex: 3,
                  child: _PickField(label: 'Starts', value: _start.format(context), onTap: () => _pickTime(true)),
                ),
                Expanded(
                  flex: 3,
                  child: _PickField(label: 'Ends', value: _end.format(context), onTap: () => _pickTime(false)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LabeledField(label: 'Where', controller: _where, maxLength: 80, hint: 'Room, hall or Online'),
            const SizedBox(height: 16),
            _AskPoints(
              on: _ask,
              points: _askPoints,
              options: _asks,
              onToggle: (v) => setState(() => _ask = v),
              onPick: (p) => setState(() => _askPoints = p),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                const Icon(Icons.check_rounded, size: 18, color: Palette.link),
                Expanded(
                  child: Text('Goes live right away as a community event.', style: AppType.body(size: 14, color: Palette.muted)),
                ),
              ],
            ),
            if (_error case final error?) ...[const SizedBox(height: 12), ErrorNote(error)],
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: const BoxDecoration(border: Border(top: Frame.side)),
        child: FilledButton(
          onPressed: _ready ? _publish : null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(_busy ? 'Publishing…' : (_ask ? 'Publish and send for review' : 'Publish')),
        ),
      ),
    ],
  );
}

/// A field that opens a picker: the date and the two times.
class _PickField extends StatelessWidget {
  const _PickField({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 5,
    children: [
      Label(label, size: 18, color: Palette.ink),
      Semantics(
        button: true,
        label: '$label: $value',
        excludeSemantics: true,
        child: Material(
          color: Palette.field,
          shape: const RoundedRectangleBorder(borderRadius: Frame.buttonRadius, side: Frame.side),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 52,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 15)),
            ),
          ),
        ),
      ),
    ],
  );
}

/// The switch to ask organisers for leaderboard points, and how many.
class _AskPoints extends StatelessWidget {
  const _AskPoints({required this.on, required this.points, required this.options, required this.onToggle, required this.onPick});

  final bool on;
  final int points;
  final List<int> options;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Material(
    color: Palette.window,
    shape: const RoundedRectangleBorder(borderRadius: Frame.radius, side: Frame.side),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: on,
            onChanged: onToggle,
            title: Text('Ask for leaderboard points', style: AppType.body(size: 15, weight: FontWeight.w500)),
            subtitle: Text('An organiser approves points first', style: AppType.body(size: 13, color: Palette.muted)),
          ),
          SmoothSize(
            child: on
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final p in options) OptionChip(label: '+$p', selected: p == points, onTap: () => onPick(p))],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    ),
  );
}

/// "It's live": the new event as others will see it.
class _Published extends StatelessWidget {
  const _Published({required this.event, required this.onAgain});

  final HubEvent event;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final start = event.startsAt.toLocal();
    return ListView(
      key: const ValueKey('done'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        Center(
          child: PopIn(
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: Palette.gold, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 44, color: Palette.onGold),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Rise(
          child: Text("It's live", textAlign: TextAlign.center, style: AppType.title(size: 22)),
        ),
        const SizedBox(height: 18),
        Rise(
          delay: Motion.stagger(1),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Palette.window, borderRadius: Frame.radius, border: Frame.border),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Text(
                  '${_cap(event.kind.name)} · by you',
                  style: AppType.body(size: 12, weight: FontWeight.w500, color: Palette.muted),
                ),
                Text(event.title, style: AppType.body(size: 17, weight: FontWeight.w700)),
                Text('${event.location} · ${calendarDate(start)} · ${clock(start)}', style: AppType.body(size: 13, color: Palette.muted)),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const InfoTag('Community', color: Palette.high, textColor: Palette.ink),
                    if (event.isPending) InfoTag('+${event.askedPoints} pending review', icon: Icons.schedule_rounded),
                    if (event.checkinCode case final code?) InfoTag('Code $code', color: Palette.navy, textColor: Palette.cream),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(event),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('See it in events'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onAgain, child: const Text('Create another')),
      ],
    );
  }
}

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
