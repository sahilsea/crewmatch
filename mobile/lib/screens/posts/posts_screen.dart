import 'package:material_ui/material_ui.dart';

import '../../api/api_exception.dart';
import '../../models/hub_event.dart';
import '../../models/post.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../events/check_in_dialog.dart';
import '../events/events_screen.dart';
import '../shell/app_tab.dart';
import 'comments_sheet.dart';
import 'composer_sheet.dart';
import 'post_card.dart';

/// The Posts tab: what's happening now at the hackathon, then the feed
/// everyone posts to.
class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key, required this.onOpen, this.wide = false});

  final OpenTab onOpen;

  /// Wide windows: the feed in a readable column, events in a sidebar.
  final bool wide;

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  final _scroll = ScrollController();
  List<Post>? _posts;
  List<HubEvent> _events = const [];
  var _hasMore = false;
  var _loadingMore = false;
  Object? _error;

  /// Posts you just made, which slide in from the top instead of rising.
  final _fresh = <String>{};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.api;
    // Events are a bonus on this tab: if they fail, the feed still shows.
    final events = api
        .events(kind: EventKind.event)
        .then<List<HubEvent>?>((e) => e)
        .catchError((_) => null);
    try {
      final page = await api.posts();
      final now = await events;
      if (!mounted) return;
      setState(() {
        _posts = page.posts;
        _hasMore = page.hasMore;
        _events = [
          for (final e in now ?? const <HubEvent>[])
            if (e.state != EventState.ended) e,
        ];
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _maybeLoadMore() {
    final posts = _posts;
    if (!_hasMore || _loadingMore || posts == null || posts.isEmpty) return;
    if (_scroll.position.extentAfter > 600) return;
    _loadingMore = true;
    context.api
        .posts(before: posts.last.createdAt)
        .then((page) {
          if (!mounted) return;
          setState(() {
            _posts = [...posts, ...page.posts];
            _hasMore = page.hasMore;
          });
        })
        .catchError((_) {})
        .whenComplete(() => _loadingMore = false);
  }

  void _replace(Post post) => setState(
    () => _posts = [for (final p in _posts!) p.id == post.id ? post : p],
  );

  Future<void> _like(Post post) async {
    // Instant on screen; the server's answer settles the count.
    _replace(post.toggledLike());
    try {
      _replace(await context.api.toggleLike(post.id));
    } on ApiException catch (e) {
      _replace(post);
      if (mounted) showNotice(context, e.message);
    }
  }

  Future<void> _comments(Post post) async {
    final updated = await showCommentsSheet(context, post);
    if (updated != null && mounted) _replace(updated);
  }

  Future<void> _delete(Post post) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete post',
      message: 'Delete this post for everyone?',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;
    try {
      await context.api.deletePost(post.id);
      if (mounted) setState(() => _posts!.removeWhere((p) => p.id == post.id));
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    }
  }

  Future<void> _compose() async {
    final post = await showComposerSheet(context);
    if (post == null || !mounted) return;
    setState(() {
      _fresh.add(post.id);
      _posts = [post, ...?_posts];
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: Motion.of(context, const Duration(milliseconds: 400)),
        curve: Motion.ease,
      );
    }
    showNotice(context, 'Posted');
  }

  Future<void> _checkIn(HubEvent event) async {
    if (context.session.user?.crewId == null) {
      return showNotice(context, 'Join a crew to check in at events');
    }
    final result = await showCheckInDialog(context, event);
    if (result != null && mounted) {
      showNotice(context, 'Checked in · +${result.pointsAwarded} pts');
      _load();
    }
  }

  void _allEvents() =>
      Navigator.of(context).push(EventsScreen.route(widget.onOpen)).then((_) {
        if (mounted) _load();
      });

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    final myId = context.session.user?.id;
    final feed = _feed(posts, myId);
    if (!widget.wide) return feed;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: feed,
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 340,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
            children: [
              _HappeningNow(
                events: _events,
                onCheckIn: _checkIn,
                onAll: _allEvents,
                vertical: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _feed(List<Post>? posts, String? myId) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader(title: 'Posts'),
            Expanded(
              child: posts == null
                  ? (_error == null
                        ? const LoadingView()
                        : ErrorView(
                            error: _error!,
                            onRetry: () {
                              setState(() => _error = null);
                              _load();
                            },
                          ))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 4, bottom: 96),
                        children: [
                          if (!widget.wide) ...[
                            _HappeningNow(
                              events: _events,
                              onCheckIn: _checkIn,
                              onAll: _allEvents,
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (posts.isEmpty)
                            const EmptyState(
                              title: 'No posts yet',
                              message: 'Be the first to post.',
                            )
                          else
                            for (final (i, post) in posts.indexed)
                              Padding(
                                key: ValueKey(post.id),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  10,
                                ),
                                child: _fresh.contains(post.id)
                                    ? Rise(
                                        offset: -16,
                                        child: _card(post, myId),
                                      )
                                    : Rise(
                                        delay: Motion.stagger(i, stepMs: 70),
                                        child: _card(post, myId),
                                      ),
                              ),
                          if (_hasMore)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: PopIn(
            delay: const Duration(milliseconds: 400),
            child: FloatingActionButton.extended(
              onPressed: _compose,
              backgroundColor: Palette.crimson,
              foregroundColor: Palette.onCrimson,
              shape: const RoundedRectangleBorder(borderRadius: Frame.radius),
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                'New post',
                style: AppType.body(
                  size: 15,
                  weight: FontWeight.w500,
                  color: Palette.onCrimson,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(Post post, String? myId) => PostCard(
    post: post,
    mine: post.author.id == myId,
    onLike: () => _like(post),
    onComments: () => _comments(post),
    onDelete: () => _delete(post),
  );
}

/// A sideways row of live and upcoming events, with a link to all of them.
class _HappeningNow extends StatelessWidget {
  const _HappeningNow({
    required this.events,
    required this.onCheckIn,
    required this.onAll,
    this.vertical = false,
  });

  final List<HubEvent> events;
  final ValueChanged<HubEvent> onCheckIn;
  final VoidCallback onAll;

  /// A column of cards, for the wide sidebar.
  final bool vertical;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 6,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 20, right: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Happening now',
                style: AppType.body(size: 16, weight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: onAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('All events'),
                  Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
      if (events.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Nothing on right now.',
            style: AppType.body(size: 14, color: Palette.muted),
          ),
        )
      else if (vertical)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            spacing: 10,
            children: [
              for (final (i, e) in events.indexed)
                SlideIn(
                  delay: Motion.stagger(i, stepMs: 80),
                  child: SizedBox(
                    height: 164,
                    child: _EventTile(
                      event: e,
                      onCheckIn: () => onCheckIn(e),
                      onOpen: onAll,
                      fullWidth: true,
                    ),
                  ),
                ),
            ],
          ),
        )
      else
        SizedBox(
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => SlideIn(
              delay: Motion.stagger(i, stepMs: 80),
              child: _EventTile(
                event: events[i],
                onCheckIn: () => onCheckIn(events[i]),
                onOpen: onAll,
              ),
            ),
          ),
        ),
    ],
  );
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.onCheckIn,
    required this.onOpen,
    this.fullWidth = false,
  });

  final bool fullWidth;
  final HubEvent event;
  final VoidCallback onCheckIn;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final live = e.state == EventState.live;
    final done = e.isCompleted;
    final start = e.startsAt.toLocal();
    return Container(
      width: fullWidth ? double.infinity : 236,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Palette.window,
        borderRadius: Frame.radius,
        border: Frame.border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (live)
                const LivePill()
              else
                InfoTag(
                  '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
                  color: Palette.navy,
                  textColor: Palette.cream,
                ),
              const Spacer(),
              e.isOfficial ? InfoTag('+${e.points}') : const InfoTag('Community', color: Palette.high, textColor: Palette.ink),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            e.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.body(
              size: 16,
              weight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          Text(
            e.location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.body(size: 13, color: Palette.muted),
          ),
          const Spacer(),
          if (done)
            FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                disabledBackgroundColor: Palette.navy,
                disabledForegroundColor: Palette.cream,
              ),
              child: const Text('✓ Checked in'),
            )
          else if (live && e.canCheckIn(DateTime.now()))
            FilledButton(
              onPressed: onCheckIn,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                backgroundColor: fullWidth ? Palette.gold : null,
                foregroundColor: fullWidth ? Palette.onGold : null,
              ),
              child: const Text('Check in'),
            )
          else
            OutlinedButton(
              onPressed: onOpen,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              child: const Text('Details'),
            ),
        ],
      ),
    );
  }
}
