import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/crew.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';

/// Asks for a new crew name and saves it. Resolves to the renamed crew, or
/// null when cancelled.
Future<Crew?> showRenameCrewDialog(BuildContext context, Crew crew) =>
    showWindowDialog<Crew>(
      context,
      title: 'Rename crew',
      builder: (_) => _RenameForm(crew: crew),
    );

class _RenameForm extends StatefulWidget {
  const _RenameForm({required this.crew});

  final Crew crew;

  @override
  State<_RenameForm> createState() => _RenameFormState();
}

class _RenameFormState extends State<_RenameForm> {
  /// Starts with the whole current name selected, so typing replaces it.
  late final _name = TextEditingController.fromValue(
    TextEditingValue(
      text: widget.crew.name,
      selection: TextSelection(baseOffset: 0, extentOffset: widget.crew.name.length),
    ),
  );
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final crew = await context.api.renameCrew(_name.text.trim());
      if (mounted) Navigator.of(context).pop(crew);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fieldErrors['name'] ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: LabeledField(
              label: 'Crew name',
              controller: _name,
              error: _error,
              maxLength: 50,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
          ),
          SegmentRow(
            segments: [
              Segment(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
              Segment(
                label: _busy ? 'Saving…' : 'Save',
                color: Palette.pink,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ],
      );
}
