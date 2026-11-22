import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../shell/top_menu_bar.dart';

/// After sign-up: type the 6-digit code we emailed. Until then the rest of the
/// app stays locked (the API refuses it too).
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> with SingleTickerProviderStateMixin {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  var _busy = false;
  String? _error;

  /// Seconds before "Send a new code" works again.
  var _wait = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _countdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _countdown() {
    _timer?.cancel();
    setState(() => _wait = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _code.text;
    if (_busy || code.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.session;
    try {
      final user = await session.api.verifyEmail(code);
      HapticFeedback.mediumImpact();
      session.devCode = null;
      session.updateUser(user);
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

  Future<void> _resend() async {
    final session = context.session;
    try {
      final code = await session.api.resendCode();
      session.devCode = code;
      if (!mounted) return;
      setState(() => _error = null);
      _countdown();
      showNotice(context, 'New code sent');
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.watch(context);
    final email = session.user?.email ?? 'your email';
    final devCode = session.devCode;
    final text = _code.text;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopMenuBar(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 18,
                      children: [
                        PopIn(
                          child: Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(color: Palette.gold, shape: BoxShape.circle),
                              child: const Icon(Icons.mark_email_read_outlined, size: 34, color: Palette.onGold),
                            ),
                          ),
                        ),
                        Rise(
                          child: Column(
                            spacing: 8,
                            children: [
                              Semantics(
                                header: true,
                                child: Text('Check your email', textAlign: TextAlign.center, style: AppType.title(size: 26)),
                              ),
                              Text.rich(
                                TextSpan(
                                  text: 'We sent a 6-digit code to ',
                                  children: [TextSpan(text: email, style: const TextStyle(fontWeight: FontWeight.w700))],
                                ),
                                textAlign: TextAlign.center,
                                style: AppType.body(size: 15, color: Palette.muted),
                              ),
                            ],
                          ),
                        ),
                        if (devCode != null)
                          Rise(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                              decoration: const BoxDecoration(color: Palette.strip, borderRadius: Frame.radius),
                              child: Row(
                                spacing: 10,
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 20, color: Palette.muted),
                                  Expanded(
                                    child: Text(
                                      'Demo server, no email set up. Your code is $devCode',
                                      style: AppType.body(size: 13.5),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _code.text = devCode;
                                      setState(() {});
                                      _verify();
                                    },
                                    child: const Text('Use it'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        AnimatedBuilder(
                          animation: _shake,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(math.sin(_shake.value * math.pi * 5) * 10 * (1 - _shake.value), 0),
                            child: child,
                          ),
                          child: Semantics(
                            label: 'Verification code',
                            textField: true,
                            child: Stack(
                              children: [
                                Row(
                                  spacing: 8,
                                  children: [
                                    for (var i = 0; i < 6; i++)
                                      Expanded(
                                        child: AnimatedContainer(
                                          duration: Motion.of(context, const Duration(milliseconds: 180)),
                                          height: 58,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: i < text.length ? Palette.window : Palette.field,
                                            borderRadius: Frame.buttonRadius,
                                            border: Border.all(
                                              width: 2,
                                              color: _error != null
                                                  ? Palette.danger
                                                  : i < text.length
                                                      ? Palette.gold
                                                      : i == text.length && _focus.hasFocus
                                                          ? Palette.ink
                                                          : Palette.dashed,
                                            ),
                                          ),
                                          child: Text(i < text.length ? text[i] : '', style: AppType.title(size: 24)),
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
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                      showCursor: false,
                                      autofillHints: const [AutofillHints.oneTimeCode],
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      decoration: const InputDecoration(counterText: '', border: InputBorder.none, filled: false),
                                      onChanged: (v) {
                                        setState(() => _error = null);
                                        if (v.length == 6) _verify();
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_error case final error?)
                          Text(error, textAlign: TextAlign.center, style: AppType.body(size: 14, color: Palette.danger)),
                        FilledButton(
                          onPressed: _busy || text.length != 6 ? null : _verify,
                          child: Text(_busy ? 'Checking…' : 'Verify email'),
                        ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text("Didn't get it?", style: AppType.body(size: 14.5, color: Palette.muted)),
                            TextButton(
                              onPressed: _wait > 0 ? null : _resend,
                              child: Text(_wait > 0 ? 'Send a new code in ${_wait}s' : 'Send a new code'),
                            ),
                          ],
                        ),
                        Center(
                          child: TextButton(
                            onPressed: () => session.signOut(),
                            child: const Text('Use a different email'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
