import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/post.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/when.dart';

/// All comments on a post, with a box to add one. Resolves to the updated
/// post when you commented, so the feed can show the new count.
Future<Post?> showCommentsSheet(BuildContext context, Post post) => showModalBottomSheet<Post>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(post: post),
    );

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post});

  final Post post;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _text = TextEditingController();
  List<PostComment>? _comments;
  Post? _updated;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final comments = await context.api.comments(widget.post.id);
      if (mounted) setState(() => _comments = comments);
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final post = await context.api.addComment(widget.post.id, text);
      _text.clear();
      _updated = post;
      await _load();
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = _comments;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_updated);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Comments', style: AppType.title(size: 20)),
              ),
              Flexible(
                child: switch (comments) {
                  null => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                  [] => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No comments yet. Say something nice.', textAlign: TextAlign.center, style: AppType.body(color: Palette.muted)),
                    ),
                  final list => ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      itemCount: list.length,
                      itemBuilder: (context, i) => Rise(
                        key: ValueKey(list[i].id),
                        delay: Motion.stagger(i, stepMs: 40),
                        child: _CommentRow(comment: list[i]),
                      ),
                    ),
                },
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          maxLength: 300,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Add a comment',
                            counterText: '',
                            border: const OutlineInputBorder(borderRadius: Frame.pill, borderSide: BorderSide(color: Palette.border)),
                            enabledBorder: const OutlineInputBorder(borderRadius: Frame.pill, borderSide: BorderSide(color: Palette.border)),
                            focusedBorder: const OutlineInputBorder(borderRadius: Frame.pill, borderSide: BorderSide(color: Palette.link, width: 2)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          ),
                        ),
                      ),
                      SendButton(enabled: _text.text.trim().isNotEmpty && !_sending, onPressed: _send),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});

  final PostComment comment;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Avatar(url: comment.author.avatar, name: comment.author.name, size: 32, background: Palette.high),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Palette.strip,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      '${comment.author.name} · ${timeAgo(comment.createdAt, DateTime.now())}',
                      style: AppType.body(size: 12, weight: FontWeight.w500, color: Palette.muted),
                    ),
                    Text(comment.text, style: AppType.body(size: 14.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
