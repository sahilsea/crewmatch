import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/hub_event.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';

/// Sends (or replaces) a challenge submission: a link and an optional note.
/// Resolves to the updated challenge, or null when cancelled.
Future<HubEvent?> showSubmitDialog(BuildContext context, HubEvent challenge) =>
    showWindowDialog<HubEvent>(
      context,
      title: 'Submit',
      builder: (_) => _SubmitForm(challenge: challenge),
    );

class _SubmitForm extends StatefulWidget {
  const _SubmitForm({required this.challenge});

  final HubEvent challenge;

  @override
  State<_SubmitForm> createState() => _SubmitFormState();
}

class _SubmitFormState extends State<_SubmitForm> {
  late final EventEntry? _entry = widget.challenge.myEntry;
  late final _url = TextEditingController(text: _entry?.submissionUrl ?? '');

  /// Prefilled with the crew's own note while in review; a sent-back entry's
  /// note is the reviewer's, so that one starts empty.
  late final _note = TextEditingController(
    text: _entry?.status == EntryStatus.submitted ? _entry?.note ?? '' : '',
  );

  var _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _url.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await context.api.submitChallenge(
        widget.challenge.id,
        url: _url.text.trim(),
        note: _note.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final errors = _error?.fieldErrors ?? const {};
    final formError = _error != null && errors.isEmpty ? _error!.message : null;
    final sentBack = _entry?.wasSentBack ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text(challenge.title, style: AppType.headline(size: 24)),
              Text(
                challenge.details.isNotEmpty ? challenge.details : challenge.summary,
                style: AppType.body(size: 14.5),
              ),
              if (sentBack && _entry?.note != null) ErrorNote('Sent back: ${_entry!.note}'),
              LabeledField(
                label: 'Link',
                controller: _url,
                hint: 'https://github.com/…',
                error: errors['url'],
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              LabeledField(
                label: 'Note for the judges (optional)',
                controller: _note,
                error: errors['note'],
                maxLength: 280,
                maxLines: 3,
              ),
              if (formError != null) ErrorNote(formError),
            ],
          ),
        ),
        SegmentRow(
          segments: [
            Segment(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
            Segment(
              label: _busy ? 'Sending…' : 'Send for review',
              color: Palette.pink,
              onPressed: _busy || _url.text.trim().isEmpty ? null : _submit,
            ),
          ],
        ),
      ],
    );
  }
}
