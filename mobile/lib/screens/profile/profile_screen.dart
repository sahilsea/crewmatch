import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/profile_options.dart';
import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import '../shell/top_menu_bar.dart';
import 'choice_group.dart';
import 'skills_field.dart';

/// The chip-based profile form. New users fill it in before they can swipe;
/// everyone else opens it from the avatar menu.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.firstTime = false});

  final bool firstTime;

  static Route<void> route() => MaterialPageRoute(builder: (_) => const ProfileScreen());

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// The single-choice questions, in form order.
  static const _single = ['role', 'experienceLevel', 'schedule', 'commitment', 'communication'];
  static const _maxSkills = 15;

  ProfileOptions? _options;
  Object? _loadError;

  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _bio;
  final _skillText = TextEditingController();
  late final Map<String, String?> _choices;
  late final List<String> _interests;
  late final List<String> _superpowers;
  late final List<String> _skills;

  Map<String, String> _errors = const {};
  String? _formError;
  var _busy = false;
  var _saved = false;

  @override
  void initState() {
    super.initState();
    final user = context.session.user!;
    _name = TextEditingController(text: user.name);
    _email = TextEditingController(text: user.email);
    _bio = TextEditingController(text: user.bio);
    _choices = {for (final field in _single) field: _answer(user, field)};
    _interests = [...user.interests];
    _superpowers = [...user.superpowers];
    _skills = [...user.skills];
    _loadOptions();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _bio.dispose();
    _skillText.dispose();
    super.dispose();
  }

  static String? _answer(User user, String field) => switch (field) {
        'role' => user.role,
        'experienceLevel' => user.experienceLevel,
        'schedule' => user.schedule,
        'commitment' => user.commitment,
        'communication' => user.communication,
        _ => null,
      };

  Future<void> _loadOptions() async {
    try {
      final options = await context.api.options();
      if (mounted) setState(() => _options = options);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  List<String> get _missing => [
        for (final field in _single)
          if (_choices[field] == null) fieldLabels[field]!.toLowerCase(),
        if (_interests.isEmpty) 'an interest',
        if (_skills.isEmpty) 'a skill',
      ];

  void _edit(VoidCallback change) => setState(() {
        change();
        _saved = false;
      });

  void _toggle(List<String> list, String value) => _edit(() {
        if (!list.remove(value)) list.add(value);
      });

  void _addSkills(String text) => _edit(() {
        for (final raw in text.split(',')) {
          final skill = raw.trim();
          final known = _skills.any((s) => s.toLowerCase() == skill.toLowerCase());
          if (skill.isEmpty || known || _skills.length >= _maxSkills) continue;
          _skills.add(skill.length > 30 ? skill.substring(0, 30) : skill);
        }
        _skillText.clear();
      });

  Future<void> _save() async {
    if (_skillText.text.trim().isNotEmpty) _addSkills(_skillText.text);
    setState(() {
      _busy = true;
      _errors = const {};
      _formError = null;
    });
    final session = context.session;
    try {
      final user = await session.api.updateProfile({
        'name': _name.text.trim(),
        'bio': _bio.text.trim(),
        for (final field in _single)
          if (_choices[field] != null) field: _choices[field],
        'interests': _interests,
        'superpowers': _superpowers,
        'skills': _skills,
      });
      // On first setup this completes the profile and the app moves on to Discover.
      session.updateUser(user);
      if (mounted) setState(() => _saved = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errors = e.fieldErrors;
        _formError = _errors.isEmpty ? e.message : 'Check the fields marked in red.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.session.user;
    if (user == null) return const SizedBox.shrink();
    final options = _options;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopMenuBar(trailing: LogOutButton()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: RetroWindow(
                  title: widget.firstTime ? 'Build your profile' : 'Your profile',
                  onClose: widget.firstTime ? null : () => Navigator.of(context).pop(),
                  inset: false,
                  fill: true,
                  footer: options == null ? null : _saveBar(),
                  child: options == null
                      ? (_loadError == null
                          ? const LoadingView()
                          : ErrorView(
                              error: _loadError!,
                              onRetry: () {
                                setState(() => _loadError = null);
                                _loadOptions();
                              },
                            ))
                      : _form(user, options),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(User user, ProfileOptions options) => ListView(
        children: [
          _Header(user: user, firstTime: widget.firstTime),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                LabeledField(
                  label: 'Name',
                  controller: _name,
                  error: _errors['name'],
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => _edit(() {}),
                ),
                LabeledField(label: 'Email', controller: _email, enabled: false),
                LabeledField(
                  label: 'Bio (${280 - _bio.text.length} left)',
                  controller: _bio,
                  error: _errors['bio'],
                  hint: 'One line about what you bring to a team.',
                  maxLength: 280,
                  maxLines: 3,
                  onChanged: (_) => _edit(() {}),
                ),
                for (final field in _single)
                  ChoiceGroup(
                    legend: fieldLabels[field]!,
                    values: options[field],
                    selected: [?_choices[field]],
                    error: _errors[field],
                    onToggle: (value) => _edit(() => _choices[field] = value),
                  ),
                ChoiceGroup(
                  legend: fieldLabels['interests']!,
                  values: options['interests'],
                  selected: _interests,
                  error: _errors['interests'],
                  onToggle: (value) => _toggle(_interests, value),
                ),
                ChoiceGroup(
                  legend: '${fieldLabels['superpowers']} (up to ${options.maxSuperpowers})',
                  values: options['superpowers'],
                  selected: _superpowers,
                  max: options.maxSuperpowers,
                  error: _errors['superpowers'],
                  onToggle: (value) => _toggle(_superpowers, value),
                ),
                SkillsField(
                  skills: _skills,
                  controller: _skillText,
                  error: _errors['skills'],
                  onAdd: _addSkills,
                  onRemove: (skill) => _edit(() => _skills.remove(skill)),
                ),
                if (_formError != null) ErrorNote(_formError!),
              ],
            ),
          ),
        ],
      );

  Widget _saveBar() {
    final missing = _missing;
    final status = missing.isNotEmpty
        ? 'Still needed: ${missing.join(', ')}'
        : _saved
            ? '✓ Saved'
            : '✓ Looks good';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: const BoxDecoration(
        color: Palette.strip,
        border: Border(top: Frame.side),
      ),
      child: Row(
        spacing: 10,
        children: [
          Expanded(child: Label(status, size: 18, color: Palette.ink, maxLines: 2)),
          FilledButton(
            onPressed: _busy || missing.isNotEmpty ? null : _save,
            child: Text(
              _busy
                  ? 'Saving…'
                  : widget.firstTime
                      ? 'Start swiping'
                      : 'Save',
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.firstTime});

  final User user;
  final bool firstTime;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(border: Border(bottom: Frame.side)),
        child: Halftone(
          color: Palette.blue,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              spacing: 14,
              children: [
                Avatar(url: user.avatar, name: user.name, size: 76),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(user.name, style: AppType.headline(size: 28)),
                      Label(
                        firstTime
                            ? 'Tap what fits. Your matches are scored on it.'
                            : 'Changes reach your deck on web and mobile',
                        size: 18,
                        color: Palette.ink,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
