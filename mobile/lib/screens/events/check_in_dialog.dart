import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/hub_event.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';

/// Asks for the code the organisers show at the venue and checks the crew in.
/// Resolves to the result, or null when cancelled.
Future<CheckInResult?> showCheckInDialog(BuildContext context, HubEvent event) =>
    showWindowDialog<CheckInResult>(
      context,
      title: 'Check in',
      builder: (_) => _CheckInForm(event: event),
    );

class _CheckInForm extends StatefulWidget {
  const _CheckInForm({required this.event});

  final HubEvent event;

  @override
  State<_CheckInForm> createState() => _CheckInFormState();
}

class _CheckInFormState extends State<_CheckInForm> {
  final _code = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await context.api.checkIn(widget.event.id, _code.text.trim());
      if (mounted) Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fieldErrors['code'] ?? e.message);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Text(widget.event.title, style: AppType.headline(size: 24)),
                Text(
                  'Type the code the organisers show on screen at '
                  '${widget.event.location}. It earns your crew '
                  '${widget.event.points} points.',
                  style: AppType.body(size: 14.5),
                ),
                LabeledField(
                  label: 'Check-in code',
                  controller: _code,
                  error: _error,
                  hint: 'ABCD',
                  maxLength: 20,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  // Codes are shown in capitals; the API matches any case anyway.
                  inputFormatters: [
                    TextInputFormatter.withFunction(
                      (_, value) => value.copyWith(text: value.text.toUpperCase()),
                    ),
                  ],
                  textInputAction: TextInputAction.done,
                  style: AppType.label(size: 34, color: Palette.ink).copyWith(letterSpacing: 8),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
          SegmentRow(
            segments: [
              Segment(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
              Segment(
                label: _busy ? 'Checking…' : 'Check in',
                color: Palette.pink,
                onPressed: _busy || _code.text.trim().isEmpty ? null : _submit,
              ),
            ],
          ),
        ],
      );
}
