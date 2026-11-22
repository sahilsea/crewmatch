import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/user.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../discover/profile_card.dart';
import 'card_preview_screen.dart';

/// "Your card": profile picture, cover, headline, what shows, accent colour,
/// with a live preview of the card others swipe on.
class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const CardEditorScreen());

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  late final _headline = TextEditingController(
    text: context.session.user?.headline ?? '',
  );
  late String _cover = context.session.user?.cover ?? 'dusk';
  late String _accent = context.session.user?.accent ?? 'crimson';
  late Set<String> _fields = {...?context.session.user?.cardFields};
  var _saving = false;
  var _uploading = false;

  @override
  void dispose() {
    _headline.dispose();
    super.dispose();
  }

  /// What the card looks like right now, saved or not.
  User _draft(User me) => me.copyWith(
    headline: _headline.text.trim(),
    cover: _cover,
    accent: _accent,
    cardFields: [
      for (final (id, _) in CardStyle.fields)
        if (_fields.contains(id)) id,
    ],
  );

  bool _dirty(User me) {
    final d = _draft(me);
    return d.headline != me.headline ||
        d.cover != me.cover ||
        d.accent != me.accent ||
        d.cardFields.join() != me.cardFields.join();
  }

  Future<String?> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 82,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      if (bytes.length > 3 * 1024 * 1024) {
        if (mounted) {
          showNotice(context, 'That photo is too big. Pick one under 3 MB.');
        }
        return null;
      }
      final type =
          file.mimeType ??
          (file.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg');
      return 'data:$type;base64,${base64Encode(bytes)}';
    } catch (_) {
      if (mounted) {
        showNotice(
          context,
          source == ImageSource.camera
              ? "Couldn't open the camera"
              : "Couldn't open your photos",
        );
      }
      return null;
    }
  }

  /// Runs an upload and keeps the session's user in step with the server.
  Future<void> _upload(Future<User> Function() call, String done) async {
    setState(() => _uploading = true);
    try {
      final user = await call();
      if (!mounted) return;
      context.session.updateUser(user);
      setState(() => _cover = user.cover);
      showNotice(context, done);
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _photoSheet(User me) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text('Profile picture', style: AppType.title(size: 20)),
              ),
              _SheetItem(
                icon: Icons.photo_camera_outlined,
                label: 'Take a photo',
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              _SheetItem(
                icon: Icons.photo_library_outlined,
                label: 'Choose from gallery',
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              if (me.avatar.isNotEmpty)
                _SheetItem(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove photo',
                  color: Palette.link,
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final api = context.api;
    if (choice == 'remove') return _upload(api.removeAvatar, 'Photo removed');
    final photo = await _pick(
      choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );
    if (photo != null) {
      await _upload(() => api.uploadAvatar(photo), 'Profile picture updated');
    }
  }

  Future<void> _pickCover(User me, String id) async {
    if (id != 'photo') return setState(() => _cover = id);
    if (me.coverUrl != null && _cover != 'photo') {
      return setState(() => _cover = 'photo');
    }
    final api = context.api;
    final photo = await _pick(ImageSource.gallery);
    if (photo != null) {
      await _upload(() => api.uploadCover(photo), 'Cover photo added');
    }
  }

  Future<void> _save(User me) async {
    setState(() => _saving = true);
    final d = _draft(me);
    try {
      final user = await context.api.updateProfile({
        'headline': d.headline,
        'cover': d.cover,
        'accent': d.accent,
        'cardFields': d.cardFields,
      });
      if (!mounted) return;
      context.session.updateUser(user);
      showNotice(context, 'Card saved');
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = SessionScope.watch(context).user;
    if (me == null) return const Scaffold(body: LoadingView());
    final draft = _draft(me);
    final dirty = _dirty(me);
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmAction(
          context,
          title: 'Discard changes?',
          message: "Your card changes aren't saved yet.",
          confirmLabel: 'Discard',
        );
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Palette.ink,
                          ),
                        ),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              'Your card',
                              style: AppType.title(size: 22),
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: dirty && !_saving ? () => _save(me) : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(80, 40),
                          ),
                          child: Text(_saving ? 'Saving…' : 'Save'),
                        ),
                      ],
                    ),
                  ),
                  // A live, scaled-down copy of the real card.
                  Container(
                    height: 290,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Palette.desktop, Palette.strip],
                      ),
                    ),
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 6),
                    child: Semantics(
                      label: 'Live preview of your card',
                      child: FittedBox(
                        child: SizedBox(
                          width: 358,
                          height: 520,
                          child: AnimatedSwitcher(
                            duration: Motion.of(
                              context,
                              const Duration(milliseconds: 250),
                            ),
                            child: ProfileCard(
                              key: ValueKey((
                                draft.cover,
                                draft.accent,
                                me.avatar,
                                me.coverUrl,
                              )),
                              person: draft,
                              fitLabel: 'Your fit shows here',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
                      children: [
                        if (_uploading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(),
                          ),
                        _Section(
                          title: 'Profile picture',
                          child: Row(
                            spacing: 14,
                            children: [
                              Semantics(
                                button: true,
                                label: 'Change profile picture',
                                child: GestureDetector(
                                  onTap: _uploading
                                      ? null
                                      : () => _photoSheet(me),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Avatar(
                                        url: me.avatar,
                                        name: me.name,
                                        size: 72,
                                        background: Palette.gold,
                                      ),
                                      Positioned(
                                        right: -2,
                                        bottom: -2,
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: Palette.crimson,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Palette.desktop,
                                              width: 3,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.photo_camera_outlined,
                                            size: 15,
                                            color: Palette.onCrimson,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 2,
                                  children: [
                                    Text(
                                      me.avatar.isEmpty
                                          ? 'Add a photo'
                                          : 'Looking good',
                                      style: AppType.body(
                                        size: 15,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Shows on your card, matches and chat',
                                      style: AppType.body(
                                        size: 13,
                                        color: Palette.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Section(
                          title: 'Cover',
                          child: SizedBox(
                            height: 88,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: CardStyle.covers.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, i) {
                                final (id, label) = CardStyle.covers[i];
                                final on = _cover == id;
                                return Semantics(
                                  button: true,
                                  selected: on,
                                  label: '$label cover',
                                  child: GestureDetector(
                                    onTap: _uploading
                                        ? null
                                        : () => _pickCover(me, id),
                                    child: Column(
                                      spacing: 6,
                                      children: [
                                        AnimatedContainer(
                                          duration: Motion.of(
                                            context,
                                            const Duration(milliseconds: 200),
                                          ),
                                          width: 92,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            borderRadius: Frame.buttonRadius,
                                            border: Border.all(
                                              color: on
                                                  ? Palette.gold
                                                  : Palette.border,
                                              width: on ? 3 : 1,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.all(
                                                  Radius.circular(9),
                                                ),
                                            child:
                                                id == 'photo' &&
                                                    me.coverUrl == null
                                                ? const ColoredBox(
                                                    color: Palette.strip,
                                                    child: Center(
                                                      child: Icon(
                                                        Icons
                                                            .add_photo_alternate_outlined,
                                                        color: Palette.muted,
                                                      ),
                                                    ),
                                                  )
                                                : DecoratedBox(
                                                    decoration: CardStyle.cover(
                                                      id,
                                                      photoUrl: me.coverUrl,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        Text(
                                          label,
                                          style: AppType.body(
                                            size: 12,
                                            weight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        _Section(
                          title: 'Headline',
                          child: TextField(
                            controller: _headline,
                            maxLength: 80,
                            minLines: 2,
                            maxLines: 3,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'What do you bring to a crew?',
                            ),
                          ),
                        ),
                        _Section(
                          title: 'Show on your card',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final (id, label) in CardStyle.fields)
                                    OptionChip(
                                      label: label,
                                      selected: _fields.contains(id),
                                      onTap: () => setState(
                                        () => _fields = _fields.contains(id)
                                            ? ({..._fields}..remove(id))
                                            : {..._fields, id},
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                'Your name, role and fit always show.',
                                style: AppType.body(
                                  size: 12,
                                  color: Palette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Section(
                          title: 'Accent colour',
                          child: Row(
                            spacing: 14,
                            children: [
                              for (final MapEntry(key: id, value: (color, _))
                                  in CardStyle.accents.entries)
                                Semantics(
                                  button: true,
                                  selected: _accent == id,
                                  label: '$id accent',
                                  child: GestureDetector(
                                    onTap: () => setState(() => _accent = id),
                                    child: AnimatedContainer(
                                      duration: Motion.of(
                                        context,
                                        const Duration(milliseconds: 200),
                                      ),
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _accent == id
                                              ? Palette.ink
                                              : Palette.border,
                                          width: _accent == id ? 3 : 1,
                                        ),
                                      ),
                                    ),
                                  ),
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
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final looksGood = await Navigator.of(context)
                    .push(CardPreviewScreen.route(draft));
                if (looksGood == true && mounted && _dirty(me)) await _save(me);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Palette.navy,
                foregroundColor: Palette.cream,
              ),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('See it as others do'),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Rise(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(title, style: AppType.body(size: 15, weight: FontWeight.w700)),
          child,
        ],
      ),
    ),
  );
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Palette.ink,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    shape: const RoundedRectangleBorder(borderRadius: Frame.radius),
    leading: Icon(icon, color: color),
    title: Text(label, style: AppType.body(size: 16, color: color)),
  );
}
