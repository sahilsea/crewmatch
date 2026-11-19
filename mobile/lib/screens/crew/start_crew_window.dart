import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/crew.dart';
import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';

/// Start a crew: name it and pick up to three matches who aren't in one yet.
class StartCrewWindow extends StatefulWidget {
  const StartCrewWindow({
    super.key,
    required this.matches,
    required this.onCreated,
    required this.onFindPeople,
  });

  final List<User> matches;
  final ValueChanged<Crew> onCreated;
  final VoidCallback onFindPeople;

  @override
  State<StartCrewWindow> createState() => _StartCrewWindowState();
}

class _StartCrewWindowState extends State<StartCrewWindow> {
  static const _maxPicks = Crew.maxSize - 1;

  final _name = TextEditingController();
  final _picked = <String>{};
  var _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toggle(String id) => setState(() {
        if (!_picked.remove(id) && _picked.length < _maxPicks) _picked.add(id);
      });

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final crew = await context.api.createCrew(_name.text.trim(), _picked.toList());
      widget.onCreated(crew);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.matches.isEmpty) {
      return RetroWindow(
        title: 'Start a crew',
        child: EmptyState(
          title: 'Match with people first',
          message: 'Crews are built from matches.',
          actions: [
            FilledButton(onPressed: widget.onFindPeople, child: const Text('Start swiping')),
          ],
        ),
      );
    }

    final free = [for (final m in widget.matches) if (!m.inCrew) m];
    final errors = _error?.fieldErrors ?? const {};
    final formError = _error != null && errors.isEmpty ? _error!.message : null;

    return RetroWindow(
      title: 'Start a crew',
      inset: false,
      status: '${_picked.length} of $_maxPicks picked',
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            LabeledField(
              label: 'Crew name',
              controller: _name,
              hint: 'e.g. Night Owls',
              maxLength: 50,
              error: errors['name'],
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            Fieldset(
              legend: 'Members',
              error: errors['memberIds'],
              child: free.isEmpty
                  ? Text(
                      'All your matches are in crews already. You can start one on your own.',
                      style: AppType.body(size: 14, color: Palette.mutedDark),
                    )
                  : Column(
                      children: [
                        for (final person in free)
                          _PickRow(
                            person: person,
                            picked: _picked.contains(person.id),
                            enabled: _picked.contains(person.id) || _picked.length < _maxPicks,
                            onTap: () => _toggle(person.id),
                          ),
                      ],
                    ),
            ),
            if (formError != null) ErrorNote(formError),
            FilledButton(
              onPressed: _busy || _name.text.trim().length < 2 ? null : _create,
              child: Text(_busy ? 'Creating…' : 'Create crew'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.person,
    required this.picked,
    required this.enabled,
    required this.onTap,
  });

  final User person;
  final bool picked;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            spacing: 8,
            children: [
              Checkbox(value: picked, onChanged: enabled ? (_) => onTap() : null),
              Avatar(url: person.avatar, name: person.name, size: 36),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.name, style: AppType.body(weight: FontWeight.w600)),
                    Label(roleAndSkill(person), size: 16, color: Palette.mutedDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
