import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/when.dart';
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
            TopMenuBar(trailing: MenuBarText(calendarDate(DateTime.now()))),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                children: [
                  const WelcomeWindow(),
                  const SizedBox(height: 18),
                  RetroWindow(
                    title: _registering ? 'Create account' : 'Sign in',
                    inset: false,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 12,
                              children: [
                                if (_registering)
                                  LabeledField(
                                    label: 'Full name',
                                    controller: _name,
                                    error: fieldErrors['name'],
                                    textInputAction: TextInputAction.next,
                                    textCapitalization: TextCapitalization.words,
                                    autofillHints: const [AutofillHints.name],
                                  ),
                                LabeledField(
                                  label: 'Email',
                                  controller: _email,
                                  hint: 'you@college.edu',
                                  error: fieldErrors['email'],
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                ),
                                LabeledField(
                                  label: 'Password',
                                  controller: _password,
                                  error: fieldErrors['password'],
                                  hint: _registering ? 'At least 6 characters' : null,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: [
                                    _registering ? AutofillHints.newPassword : AutofillHints.password,
                                  ],
                                  onSubmitted: (_) => _submit(),
                                ),
                                if (formError != null) ErrorNote(formError),
                                FilledButton(
                                  onPressed: _busy ? null : _submit,
                                  child: Text(
                                    _busy
                                        ? 'Please wait…'
                                        : _registering
                                            ? 'Create account'
                                            : 'Sign in',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _SwitchModeStrip(registering: _registering, onTap: _toggleMode),
                        ],
                      ),
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

class _SwitchModeStrip extends StatelessWidget {
  const _SwitchModeStrip({required this.registering, required this.onTap});

  final bool registering;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 16, right: 8),
        decoration: const BoxDecoration(
          color: Palette.strip,
          border: Border(top: Frame.side),
        ),
        // Wraps onto two lines rather than overflowing with large text.
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              registering ? 'Already have an account?' : 'New here?',
              style: AppType.body(size: 14.5),
            ),
            TextButton(
              onPressed: onTap,
              child: Text(registering ? 'Sign in' : 'Create an account'),
            ),
          ],
        ),
      );
}
