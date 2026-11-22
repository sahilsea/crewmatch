import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/crew.dart';
import '../../models/post.dart';
import '../../state/chat_read.dart';
import '../../state/session.dart';
import '../people/people_ui.dart';
import '../../ui/ui.dart';
import '../../util/when.dart';

/// Your crew's private chat. Checks for new messages every few seconds while
/// it's open.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.crew, this.embedded = false});

  final Crew crew;

  /// Shown beside the crew on wide screens: no back button or page of its own.
  final bool embedded;

  static Route<void> route(Crew crew) =>
      MaterialPageRoute(builder: (_) => ChatScreen(crew: crew));

  /// How often an open chat asks for new messages.
  static const pollEvery = Duration(seconds: 3);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// A photo or document picked for the next message.
class _Picked {
  const _Picked({
    required this.photo,
    required this.name,
    required this.type,
    required this.bytes,
  });
  final bool photo;
  final String name;
  final String type;
  final Uint8List bytes;

  String get dataUrl => 'data:$type;base64,${base64Encode(bytes)}';

  String get summary {
    final kb = bytes.length / 1024;
    return kb >= 1024
        ? '${(kb / 1024).toStringAsFixed(1)} MB'
        : '${kb.ceil()} KB';
  }
}

/// A message on its way: shown faded until the server has it.
class _Pending {
  _Pending(this.text, this.picked) : at = DateTime.now();
  final String text;
  final _Picked? picked;
  final DateTime at;
  var failed = false;
}

const _maxFileBytes = 10 * 1024 * 1024;

/// The document types the API accepts, by extension.
const _docTypes = {
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'zip': 'application/zip',
};

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  List<ChatMessage>? _messages;
  final _pending = <_Pending>[];
  _Picked? _picked;
  Timer? _poll;
  Object? _error;

  /// Messages that arrived while the screen was open animate in.
  final _fresh = <String>{};

  static const _quick = ['📍 Meet at the expo hall', '🏃 On my way', '✅ Done'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final messages = await context.api.messages();
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _error = null;
      });
      _markRead();
      _poll ??= Timer.periodic(ChatScreen.pollEvery, (_) => _fetchNew());
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _fetchNew() async {
    final current = _messages;
    // Kept alive on a hidden tab: wait until it's on screen again.
    if (current == null || !TickerMode.valuesOf(context).enabled) return;
    try {
      final after = current.isEmpty ? null : current.last.createdAt;
      final newer = await context.api.messages(after: after);
      if (!mounted || newer.isEmpty) return;
      final known = {for (final m in _messages!) m.id};
      final added = [
        for (final m in newer)
          if (!known.contains(m.id)) m,
      ];
      if (added.isEmpty) return;
      setState(() {
        _fresh.addAll(added.map((m) => m.id));
        _messages = [..._messages!, ...added];
      });
      _markRead();
    } catch (_) {
      // A missed poll is fine; the next one catches up.
    }
  }

  void _markRead() {
    final last = _messages?.lastOrNull;
    if (last != null) ChatRead.markRead(widget.crew.id, last.createdAt);
  }

  Future<void> _attach() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (id, icon, label) in const [
                ('gallery', Icons.photo_library_outlined, 'Photo from gallery'),
                ('camera', Icons.photo_camera_outlined, 'Take a photo'),
                ('file', Icons.description_outlined, 'Document'),
              ])
                ListTile(
                  leading: Icon(icon, color: Palette.ink),
                  title: Text(label, style: AppType.body(size: 16)),
                  shape: const RoundedRectangleBorder(
                    borderRadius: Frame.radius,
                  ),
                  onTap: () => Navigator.pop(context, id),
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'PDF, Word, Excel, PowerPoint, text or zip · up to 10 MB',
                  style: AppType.body(size: 12, color: Palette.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      if (choice == 'file') {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: _docTypes.keys.toList(),
        );
        if (files.isEmpty) return;
        final file = files.single;
        if ((await file.length() ?? 0) > _maxFileBytes) return _tooBig();
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(
          () => _picked = _Picked(
            photo: false,
            name: file.name,
            type:
                _docTypes[file.extension?.toLowerCase()] ??
                'application/octet-stream',
            bytes: bytes,
          ),
        );
      } else {
        final image = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 80,
        );
        if (image == null) return;
        final bytes = await image.readAsBytes();
        if (bytes.length > 3 * 1024 * 1024) return _tooBig();
        setState(
          () => _picked = _Picked(
            photo: true,
            name: image.name,
            type: image.mimeType ?? 'image/jpeg',
            bytes: bytes,
          ),
        );
      }
    } catch (_) {
      if (mounted) showNotice(context, "Couldn't open that");
    }
  }

  void _tooBig() => showNotice(context, 'That file is too big to send');

  /// Downloads a document with your sign-in and opens it in a viewer app.
  Future<void> _open(Attachment a) async {
    try {
      final bytes = await context.api.downloadFile(a.url);
      if (kIsWeb) {
        if (mounted) showNotice(context, 'Open documents from the phone app');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/${a.name.replaceAll(RegExp(r'[^\w. -]'), '_')}',
      );
      await file.writeAsBytes(bytes);
      final result = await OpenFilex.open(file.path, type: a.type);
      if (result.type != ResultType.done && mounted) {
        showNotice(context, 'No app on this phone can open ${a.name}');
      }
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    }
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    final picked = _picked;
    if (text.isEmpty && picked == null) return;
    final pending = _Pending(text, picked);
    setState(() {
      _pending.add(pending);
      _picked = null;
      _text.clear();
    });
    try {
      final sent = await context.api.sendMessage(
        text,
        photo: picked != null && picked.photo ? picked.dataUrl : null,
        file: picked != null && !picked.photo
            ? (name: picked.name, data: picked.dataUrl)
            : null,
      );
      if (!mounted) return;
      setState(() {
        _pending.remove(pending);
        _fresh.add(sent.id);
        if (!_messages!.any((m) => m.id == sent.id)) {
          _messages = [..._messages!, sent];
        }
      });
      _markRead();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => pending.failed = true);
      showNotice(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.session.user?.id;
    final crew = widget.crew;
    final messages = _messages;
    final content = Column(
      children: [
        Container(
          color: Palette.strip,
          padding: EdgeInsets.fromLTRB(widget.embedded ? 20 : 4, 8, 12, 8),
          child: Row(
            children: [
              if (!widget.embedded)
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Palette.ink,
                  ),
                ),
              SizedBox(
                width: 34.0 + 22 * (crew.members.take(3).length - 1),
                height: 34,
                child: Stack(
                  children: [
                    for (final (i, m) in crew.members.take(3).indexed)
                      Positioned(
                        left: 22.0 * i,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Palette.strip,
                            shape: BoxShape.circle,
                          ),
                          child: Avatar(
                            url: m.avatar,
                            name: m.name,
                            size: 30,
                            background: Palette.pink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crew.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.title(size: 18),
                    ),
                    Text(
                      '${crew.members.length} members',
                      style: AppType.body(size: 12, color: Palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: messages == null
              ? (_error == null
                    ? const LoadingView()
                    : ErrorView(
                        error: _error!,
                        onRetry: () {
                          setState(() => _error = null);
                          _load();
                        },
                      ))
              : messages.isEmpty && _pending.isEmpty
              ? Center(
                  child: EmptyState(
                    title: 'Say hi to your crew',
                    message: 'Only ${crew.name} can see this chat.',
                  ),
                )
              : _MessageList(
                  messages: messages,
                  pending: _pending,
                  me: me,
                  fresh: _fresh,
                  onRetry: _retry,
                  onOpen: _open,
                ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _quick.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => Center(
              child: ActionChip(
                label: Text(_quick[i]),
                onPressed: () => _send(_quick[i]),
                shape: const RoundedRectangleBorder(
                  borderRadius: Frame.chipRadius,
                ),
                side: const BorderSide(color: Palette.dashed),
                backgroundColor: Palette.desktop,
                labelStyle: AppType.body(size: 13, weight: FontWeight.w500),
              ),
            ),
          ),
        ),
        if (_picked case final picked?)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Rise(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Palette.strip,
                  borderRadius: Frame.radius,
                ),
                child: Row(
                  spacing: 12,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      child: picked.photo
                          ? Image.memory(
                              picked.bytes,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              color: Palette.crimson,
                              child: const Icon(
                                Icons.description_outlined,
                                color: Palette.onCrimson,
                              ),
                            ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            picked.photo ? 'Photo' : picked.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.body(
                              size: 14,
                              weight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            picked.summary,
                            style: AppType.body(size: 12, color: Palette.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove attachment',
                      onPressed: () => setState(() => _picked = null),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 12),
          child: Row(
            spacing: 4,
            children: [
              IconButton(
                tooltip: 'Attach a photo or document',
                onPressed: _attach,
                icon: const Icon(
                  Icons.attach_file_rounded,
                  color: Palette.muted,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _text,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Message your crew',
                    counterText: '',
                    fillColor: Palette.window,
                    border: OutlineInputBorder(
                      borderRadius: Frame.pill,
                      borderSide: BorderSide(color: Palette.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: Frame.pill,
                      borderSide: BorderSide(color: Palette.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: Frame.pill,
                      borderSide: BorderSide(color: Palette.link, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SendButton(
                enabled: _text.text.trim().isNotEmpty || _picked != null,
                onPressed: () => _send(_text.text),
              ),
            ],
          ),
        ),
      ],
    );
    if (widget.embedded) {
      return Material(color: Palette.desktop, child: content);
    }
    return Scaffold(body: SafeArea(child: content));
  }

  void _retry(_Pending p) {
    setState(() => _pending.remove(p));
    _send(p.text);
  }
}

/// The conversation, newest at the bottom. Runs of messages from one person
/// group together: one name on top, one face and time at the bottom.
class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.pending,
    required this.me,
    required this.fresh,
    required this.onRetry,
    required this.onOpen,
  });

  final List<ChatMessage> messages;
  final List<_Pending> pending;
  final String? me;
  final Set<String> fresh;
  final ValueChanged<_Pending> onRetry;
  final ValueChanged<Attachment> onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    String? authorOf(ChatMessage m) => m.system ? null : (m.author?.id ?? '');
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final prev = i > 0 ? messages[i - 1] : null;
      final next = i + 1 < messages.length ? messages[i + 1] : null;
      final first =
          prev == null || prev.system || authorOf(prev) != authorOf(m);
      final last = next == null || next.system || authorOf(next) != authorOf(m);
      final row = m.system
          ? _SystemLine(text: m.text)
          : _Bubble(
              text: m.text,
              mine: m.author?.id == me,
              author: m.author,
              showName: first,
              showFace: last,
              time: last ? clock(m.createdAt.toLocal()) : null,
              attachment: m.attachment,
              onOpen: onOpen,
            );
      rows.add(
        Padding(
          key: ValueKey(m.id),
          padding: EdgeInsets.only(top: first ? 8 : 2),
          child: fresh.contains(m.id) ? PopIn(child: row) : row,
        ),
      );
    }
    for (final p in pending) {
      rows.add(
        Padding(
          key: ObjectKey(p),
          padding: const EdgeInsets.only(top: 2),
          child: GestureDetector(
            onTap: p.failed ? () => onRetry(p) : null,
            child: Opacity(
              opacity: p.failed ? 1 : 0.6,
              child: _Bubble(
                text: p.text,
                mine: true,
                time: p.failed ? 'Not sent · tap to retry' : 'Sending…',
                localPhoto: p.picked != null && p.picked!.photo
                    ? p.picked!.bytes
                    : null,
                localFile: p.picked != null && !p.picked!.photo
                    ? p.picked!.name
                    : null,
              ),
            ),
          ),
        ),
      );
    }
    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      children: rows.reversed.toList(),
    );
  }
}

class _SystemLine extends StatelessWidget {
  const _SystemLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Palette.strip,
        borderRadius: Frame.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          const Icon(Icons.bolt_rounded, size: 14, color: Palette.gold),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: AppType.body(size: 12, color: Palette.muted),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.mine,
    this.author,
    this.showName = false,
    this.showFace = true,
    this.time,
    this.attachment,
    this.onOpen,
    this.localPhoto,
    this.localFile,
  });

  final String text;
  final bool mine;
  final Author? author;
  final bool showName;
  final bool showFace;
  final String? time;
  final Attachment? attachment;
  final ValueChanged<Attachment>? onOpen;

  /// A photo or file name still being sent.
  final Uint8List? localPhoto;
  final String? localFile;

  Widget? _photo(BuildContext context) {
    final a = attachment;
    final image = localPhoto != null
        ? Image.memory(localPhoto!, fit: BoxFit.cover)
        : a != null && a.photo
        ? Image.network(
            mediaUrl(a.url),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(color: Palette.strip),
          )
        : null;
    if (image == null) return null;
    return GestureDetector(
      onTap: a == null
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (context) => GestureDetector(
                onTap: () => Navigator.pop(context),
                child: InteractiveViewer(child: Image.network(mediaUrl(a.url))),
              ),
            ),
      child: ClipRRect(
        borderRadius: Frame.radius,
        child: SizedBox(width: 230, height: 160, child: image),
      ),
    );
  }

  Widget? _file() {
    final a = attachment;
    final name = localFile ?? (a != null && !a.photo ? a.name : null);
    if (name == null) return null;
    return Material(
      color: mine ? const Color(0x24FFFFFF) : Palette.strip,
      borderRadius: Frame.buttonRadius,
      child: InkWell(
        borderRadius: Frame.buttonRadius,
        onTap: a == null ? null : () => onOpen?.call(a),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Palette.crimson,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Palette.onCrimson,
                  size: 20,
                ),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body(
                        size: 14,
                        weight: FontWeight.w500,
                        color: mine ? Palette.onCrimson : Palette.ink,
                      ),
                    ),
                    Text(
                      a == null ? 'Sending…' : '${a.summary} · Open',
                      style: AppType.body(
                        size: 12,
                        color: mine ? Palette.onCrimson : Palette.muted,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final photo = _photo(context);
    final file = _file();
    if (photo != null && text.isEmpty) return _wrap(context, photo);
    const big = Radius.circular(20);
    const small = Radius.circular(4);
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? Palette.crimson : Palette.window,
        border: mine ? null : Border.all(color: Palette.border),
        borderRadius: BorderRadius.only(
          topLeft: big,
          topRight: big,
          bottomLeft: mine || !showFace ? big : small,
          bottomRight: mine && showFace ? small : big,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          ?photo,
          ?file,
          if (text.isNotEmpty)
            Text(
              text,
              style: AppType.body(
                size: 15,
                color: mine ? Palette.onCrimson : Palette.ink,
              ),
            ),
        ],
      ),
    );
    return _wrap(context, bubble);
  }

  /// Name above, time below, face beside: the same for every kind of bubble.
  Widget _wrap(BuildContext context, Widget bubble) {
    final column = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      spacing: 3,
      children: [
        if (showName && !mine && author != null)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              author!.name.split(' ').first,
              style: AppType.body(size: 12, color: Palette.muted),
            ),
          ),
        bubble,
        if (time != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              time!,
              style: AppType.body(size: 11, color: Palette.muted),
            ),
          ),
      ],
    );
    if (mine) return Align(alignment: Alignment.centerRight, child: column);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 8,
      children: [
        Visibility.maintain(
          visible: showFace,
          child: switch (author) {
            final a? => ProfileTap(
                userId: a.id,
                name: a.name,
                child: Avatar(url: a.avatar, name: a.name, size: 28, background: Palette.pink),
              ),
            null => const SizedBox.square(dimension: 28),
          },
        ),
        Flexible(child: column),
      ],
    );
  }
}
