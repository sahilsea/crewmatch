import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/hub_event.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';

/// A bottom sheet that asks for the code shown at the venue and checks the
/// crew in. Resolves to the result, or null when dismissed.
Future<CheckInResult?> showCheckInDialog(BuildContext context, HubEvent event) =>
    showModalBottomSheet<CheckInResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CheckInSheet(event: event),
    );

class _CheckInSheet extends StatefulWidget {
  const _CheckInSheet({required this.event});

  final HubEvent event;

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> with SingleTickerProviderStateMixin {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  var _busy = false;
  String? _error;
  CheckInResult? _result;

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    _shake.dispose();
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
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _result = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _error = e.fieldErrors['code'] ?? e.message);
      _code.clear();
      if (Motion.on(context)) _shake.forward(from: 0);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: SmoothSize(
            child: _result == null ? _form() : _Success(result: _result!),
          ),
        ),
      );

  Widget _form() {
    final e = widget.event;
    final text = _code.text;
    final boxes = math.max(4, text.length);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            InfoTag(
              '${e.state == EventState.live ? 'LIVE · ' : ''}+${e.points} PTS',
              color: Palette.crimson,
              textColor: Palette.onCrimson,
            ),
            Text(e.title, style: AppType.title(size: 22)),
          ],
        ),
        // The real field is invisible and sits under the boxes, so tapping
        // anywhere on them opens the keyboard.
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(math.sin(_shake.value * math.pi * 5) * 10 * (1 - _shake.value), 0),
            child: child,
          ),
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 10,
                children: [
                  for (var i = 0; i < boxes; i++)
                    Flexible(
                      child: _CodeBox(
                        char: i < text.length ? text[i] : '',
                        active: _focus.hasFocus && i == text.length,
                        error: _error != null,
                      ),
                    ),
                ],
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _code,
                    focusNode: _focus,
                    autofocus: true,
                    maxLength: 20,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(counterText: '', border: InputBorder.none, filled: false),
                    // Codes are shown in capitals; the API matches any case anyway.
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      TextInputFormatter.withFunction((_, value) => value.copyWith(text: value.text.toUpperCase())),
                    ],
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          _error ?? 'Enter the code at the door',
          textAlign: TextAlign.center,
          style: AppType.body(size: 14, color: _error == null ? Palette.muted : Palette.danger),
        ),
        FilledButton(
          onPressed: _busy || text.isEmpty ? null : _submit,
          child: Text(_busy ? 'Checking…' : 'Check in'),
        ),
      ],
    );
  }
}

/// One letter of the code: gold-edged once typed, with a little pop.
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.char, required this.active, required this.error});

  final String char;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final border = error
        ? Palette.danger
        : char.isNotEmpty
            ? Palette.gold
            : active
                ? Palette.ink
                : Palette.dashed;
    return AnimatedContainer(
      duration: Motion.of(context, const Duration(milliseconds: 200)),
      curve: Motion.standard,
      constraints: const BoxConstraints(maxWidth: 60),
      height: 68,
      decoration: BoxDecoration(
        color: char.isEmpty ? Palette.field : Palette.window,
        borderRadius: Frame.buttonRadius,
        border: Border.all(color: border, width: 2),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: Motion.of(context, const Duration(milliseconds: 220)),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: Text(char, key: ValueKey(char), style: AppType.title(size: 28)),
      ),
    );
  }
}

/// The gold burst, flying sparks and a "Checked in" stamp.
class _Success extends StatelessWidget {
  const _Success({required this.result});

  final CheckInResult result;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          const SizedBox(height: 4),
          SizedBox(
            height: 140,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: Motion.on(context) ? 0 : 1, end: 1),
              duration: Motion.of(context, const Duration(milliseconds: 900)),
              curve: Motion.ease,
              builder: (context, t, _) => Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0) * 0.9,
                    child: Transform.scale(
                      scale: 0.2 + 2.2 * t,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(color: Palette.gold, shape: BoxShape.circle),
                        child: SizedBox.square(dimension: 80),
                      ),
                    ),
                  ),
                  for (var i = 0; i < 8; i++)
                    Transform.translate(
                      offset: Offset.fromDirection(i / 8 * math.pi * 2, 72 * t),
                      child: Opacity(
                        opacity: (1 - t).clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: [Palette.gold, Palette.crimson, Palette.navy, Palette.gold][i % 4],
                            borderRadius: const BorderRadius.all(Radius.circular(2)),
                          ),
                          child: const SizedBox.square(dimension: 8),
                        ),
                      ),
                    ),
                  Transform.rotate(
                    angle: -0.14,
                    child: Transform.scale(
                      scale: t < 0.6 ? 2.2 - 1.3 * (t / 0.6) : 0.9 + 0.1 * ((t - 0.6) / 0.4),
                      child: Opacity(
                        opacity: (t * 2.5).clamp(0.0, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Palette.desktop,
                            borderRadius: Frame.chipRadius,
                            border: Border.all(color: Palette.link, width: 3),
                          ),
                          child: Text(
                            'Checked in · +${result.pointsAwarded}',
                            style: AppType.title(size: 18, color: Palette.link),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(result),
            child: const Text('Done'),
          ),
        ],
      );
}
