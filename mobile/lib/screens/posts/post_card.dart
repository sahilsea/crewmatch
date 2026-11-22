import 'package:material_ui/material_ui.dart';

import '../../models/post.dart';
import '../../state/session.dart';
import '../people/people_ui.dart';
import '../../ui/ui.dart';
import '../../util/when.dart';

/// One post: who, when, what, an optional photo, likes and comments.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.mine,
    required this.onLike,
    required this.onComments,
    required this.onDelete,
  });

  final Post post;

  /// Your own post: offers Delete.
  final bool mine;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = post;
    final photo = p.photoUrl;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 4),
      decoration: const BoxDecoration(color: Palette.window, borderRadius: Frame.radius, border: Frame.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 10,
            children: [
              ProfileTap(
                userId: p.author.id,
                name: p.author.name,
                child: Avatar(url: p.author.avatar, name: p.author.name, size: 40, background: Palette.pink),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.author.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 15, weight: FontWeight.w500)),
                    Text(
                      [?p.crewName, timeAgo(p.createdAt, DateTime.now())].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body(size: 12, color: Palette.muted),
                    ),
                  ],
                ),
              ),
              if (mine)
                PopupMenuButton<void>(
                  tooltip: 'Post options',
                  icon: const Icon(Icons.more_vert_rounded, color: Palette.muted, size: 20),
                  itemBuilder: (_) => [PopupMenuItem(onTap: onDelete, child: const Text('Delete post'))],
                )
              else
                const SizedBox(width: 6),
            ],
          ),
          // The tag sits on its own line so long crew names never get squeezed.
          if (p.tag case final tag? when tag != PostTag.update)
            Align(alignment: Alignment.centerLeft, child: InfoTag(tag.label, color: Palette.navy, textColor: Palette.cream)),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(p.text, style: AppType.body(size: 15, height: 1.45)),
          ),
          if (photo != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ClipRRect(
                borderRadius: Frame.buttonRadius,
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    context.api.photoUrl(photo),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    // Fades in once loaded instead of popping.
                    frameBuilder: (context, child, frame, sync) => sync
                        ? child
                        : AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: Motion.of(context, const Duration(milliseconds: 300)),
                            curve: Motion.standard,
                            child: child,
                          ),
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Palette.strip,
                      child: Center(child: Icon(Icons.broken_image_outlined, color: Palette.muted)),
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              _LikeButton(liked: p.likedByMe, count: p.likeCount, onTap: onLike),
              TextButton.icon(
                onPressed: onComments,
                style: TextButton.styleFrom(foregroundColor: Palette.muted, minimumSize: const Size(48, 40)),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
                label: Text('${p.commentCount}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The heart fills crimson with a little pop when you like.
class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.liked, required this.count, required this.onTap});

  final bool liked;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        toggled: liked,
        label: '${liked ? 'Unlike' : 'Like'}, $count ${count == 1 ? 'like' : 'likes'}',
        excludeSemantics: true,
        onTap: onTap,
        child: TextButton.icon(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: liked ? Palette.crimson : Palette.muted,
            minimumSize: const Size(48, 40),
          ),
          icon: TweenAnimationBuilder<double>(
            key: ValueKey(liked),
            tween: Tween(begin: liked && Motion.on(context) ? 1.4 : 1, end: 1),
            duration: Motion.of(context, const Duration(milliseconds: 350)),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 20),
          ),
          label: AnimatedSwitcher(
            duration: Motion.of(context, const Duration(milliseconds: 200)),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: Text('$count', key: ValueKey(count)),
          ),
        ),
      );
}
