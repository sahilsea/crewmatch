import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/post.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';

/// Write a post: text, an optional tag and photo. Resolves to the new post.
Future<Post?> showComposerSheet(BuildContext context) => showModalBottomSheet<Post>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ComposerSheet(),
    );

class _ComposerSheet extends StatefulWidget {
  const _ComposerSheet();

  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  final _text = TextEditingController();
  PostTag? _tag;
  Uint8List? _photo;
  String _photoType = 'image/jpeg';
  var _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 3 * 1024 * 1024) {
        if (mounted) showNotice(context, 'That photo is too big. Pick one under 3 MB.');
        return;
      }
      final name = file.name.toLowerCase();
      setState(() {
        _photo = bytes;
        _photoType = file.mimeType ?? (name.endsWith('.png') ? 'image/png' : name.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
      });
    } catch (_) {
      if (mounted) showNotice(context, "Couldn't open your photos");
    }
  }

  Future<void> _post() async {
    final text = _text.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final photo = _photo;
      final post = await context.api.createPost(
        text,
        tag: _tag,
        photo: photo == null ? null : 'data:$_photoType;base64,${base64Encode(photo)}',
      );
      if (mounted) Navigator.of(context).pop(post);
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionScope.watch(context).user;
    final ready = _text.text.trim().isNotEmpty && !_busy;
    final photo = _photo;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Row(
                spacing: 10,
                children: [
                  Avatar(url: user?.avatar ?? '', name: user?.name ?? '', size: 40, background: Palette.gold),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? '', style: AppType.body(size: 15, weight: FontWeight.w500)),
                        Text('Everyone can see this', style: AppType.body(size: 12, color: Palette.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _text,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                style: AppType.body(size: 17, height: 1.45),
                decoration: const InputDecoration(
                  hintText: "Share an update, a win, or who you're looking for…",
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
              SmoothSize(
                child: photo == null
                    ? const SizedBox(width: double.infinity)
                    : Stack(
                        children: [
                          ClipRRect(
                            borderRadius: Frame.radius,
                            child: AspectRatio(aspectRatio: 16 / 10, child: Image.memory(photo, fit: BoxFit.cover)),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton.filled(
                              tooltip: 'Remove photo',
                              onPressed: () => setState(() => _photo = null),
                              style: IconButton.styleFrom(backgroundColor: const Color(0x99140C06), foregroundColor: Colors.white),
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                          ),
                        ],
                      ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in PostTag.values)
                    OptionChip(
                      label: tag.label,
                      selected: _tag == tag,
                      onTap: () => setState(() => _tag = _tag == tag ? null : tag),
                    ),
                ],
              ),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _pickPhoto,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: Palette.strip,
                      foregroundColor: Palette.ink,
                    ),
                    icon: const Icon(Icons.photo_outlined, size: 20),
                    label: Text(photo == null ? 'Photo' : 'Change photo'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: ready ? _post : null,
                    style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
                    child: Text(_busy ? 'Posting…' : 'Post'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
