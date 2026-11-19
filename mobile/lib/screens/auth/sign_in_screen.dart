import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../shell/top_menu_bar.dart';
import 'welcome_window.dart';

/// Sign in, or create an account. New accounts go on to the profile form.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _registering = false;
  var _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.session;
    try {
      if (_registering) {
        await session.register(_name.text, _email.text, _password.text);
      } else {
        await session.signIn(_email.text, _password.text);
      }
      // The root gate swaps this screen out once the session has a user.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleMode() => setState(() {
        _registering = !_registering;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    final notice = SessionScope.watch(context).notice;
    final fieldErrors = _error?.fieldErrors ?? const {};
    final formError = _error != null && fieldErrors.isEmpty ? _error!.message : notice;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopMenuBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  WelcomeWindow(registering: _registering),
                  const SizedBox(height: 24),
                  AutofillGroup(
                    child: SmoothSize(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 14,
                        children: [
                          if (_registering)
                            Rise(
                              child: LabeledField(
                                label: 'Full name',
                                controller: _name,
                                error: fieldErrors['name'],
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [AutofillHints.name],
                              ),
                            ),
                          Rise(
                            delay: const Duration(milliseconds: 100),
                            child: LabeledField(
                              label: 'Email',
                              controller: _email,
                              hint: 'you@college.edu',
                              error: fieldErrors['email'],
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                            ),
                          ),
                          Rise(
                            delay: const Duration(milliseconds: 200),
                            child: LabeledField(
                              label: 'Password',
                              controller: _password,
                              error: fieldErrors['password'],
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: [
                                _registering ? AutofillHints.newPassword : AutofillHints.password,
                              ],
                              onChanged: _registering ? (_) => setState(() {}) : null,
                              onSubmitted: (_) => _submit(),
                            ),
                          ),
                          if (_registering) PasswordStrength(password: _password.text),
                          if (formError != null) ErrorNote(formError),
                          Rise(
                            delay: const Duration(milliseconds: 300),
                            child: FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: Text(
                                _busy
                                    ? 'Please wait…'
                                    : _registering
                                        ? 'Create account'
                                        : 'Sign in',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Rise(
                    delay: const Duration(milliseconds: 400),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _registering ? 'Already have one?' : 'New here?',
                          style: AppType.body(size: 15, color: Palette.muted),
                        ),
                        TextButton(
                          onPressed: _toggleMode,
                          child: Text(_registering ? 'Sign in' : 'Create an account'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four bars that fill and change colour as the password gets stronger:
/// longer, and a mix of letters, digits and symbols.
class PasswordStrength extends StatelessWidget {
  const PasswordStrength({super.key, required this.password});

  final String password;

  int get score {
    if (password.isEmpty) return 0;
    final variety = [RegExp('[a-zA-Z]'), RegExp(r'\d'), RegExp(r'[^a-zA-Z\d]')].where((r) => r.hasMatch(password)).length;
    return ((password.length >= 8 ? 2 : 1) + (variety - 1)).clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    final score = this.score;
    final color = switch (score) { <= 1 => Palette.crimson, 2 || 3 => Palette.gold, _ => Palette.navy };
    return Semantics(
      label: 'Password strength',
      value: const ['None', 'Too short', 'Okay', 'Good', 'Strong'][score],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            spacing: 6,
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: Motion.of(context, const Duration(milliseconds: 300)),
                    curve: Motion.ease,
                    height: i < score ? 7 : 5,
                    decoration: BoxDecoration(
                      color: i < score ? color : Palette.high,
                      borderRadius: Frame.pill,
                    ),
                  ),
                ),
            ],
          ),
          ExcludeSemantics(
            child: Text(
              const ['Type a password', 'Too short', 'Okay', 'Good', 'Strong'][score],
              style: AppType.body(size: 13, color: Palette.muted),
            ),
          ),
        ],
      ),
    );
  }
}
