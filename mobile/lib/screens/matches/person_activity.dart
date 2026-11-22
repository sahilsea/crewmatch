import 'package:material_ui/material_ui.dart';

import '../../models/post.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/when.dart';

/// Someone's posts and what they've done at the hackathon, as two tabs.
/// Loads both when it appears.
class PersonActivity extends StatefulWidget {
  const PersonActivity({super.key, required this.userId});

  final String userId;

  @override
  State<PersonActivity> createState() => _PersonActivityState();
}

class _PersonActivityState extends State<PersonActivity> {
  var _tab = 0;
  List<Post>? _posts;
  List<ActivityItem>? _activity;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PersonActivity old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) {
      setState(() {
        _posts = null;
        _activity = null;
        _failed = false;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final api = context.api;
    final id = widget.userId;
    try {
      final posts = await api.userPosts(id);
      final activity = await api.activity(id);
      if (!mounted || id != widget.userId) return;
      setState(() {
        _posts = posts;
        _activity = activity;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(border: Border(bottom: Frame.side)),
            child: Row(
              children: [
                for (final (i, label) in ['Posts', 'Activity'].indexed)
                  Semantics(
                    button: true,
                    selected: _tab == i,
                    child: InkWell(
                      onTap: () => setState(() => _tab = i),
                      child: AnimatedContainer(
                        duration: Motion.of(context, const Duration(milliseconds: 200)),
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: _tab == i ? Palette.gold : Colors.transparent, width: 3)),
                        ),
                        child: Text(
                          label,
                          style: AppType.body(size: 15, weight: _tab == i ? FontWeight.w700 : FontWeight.w500, color: _tab == i ? Palette.ink : Palette.muted),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SmoothSize(
            child: _failed
                ? Text("Couldn't load this right now.", style: AppType.body(color: Palette.muted))
                : _posts == null
                    ? const Padding(padding: EdgeInsets.all(20), child: Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))))
                    : KeyedSubtree(key: ValueKey(_tab), child: _tab == 0 ? _postList(_posts!) : _timeline(_activity!)),
          ),
        ],
      );

  Widget _postList(List<Post> posts) {
    if (posts.isEmpty) return Text('No posts yet.', style: AppType.body(color: Palette.muted));
    final now = DateTime.now();
    return Column(
      spacing: 10,
      children: [
        for (final (i, p) in posts.indexed)
          SlideIn(
            delay: Motion.stagger(i, stepMs: 60),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(color: Palette.window, borderRadius: Frame.radius, border: Frame.border),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        Text(
                          [timeAgo(p.createdAt, now), if (p.tag != null && p.tag != PostTag.update) p.tag!.label].join(' · '),
                          style: AppType.body(size: 12, color: Palette.muted),
                        ),
                        Text(p.text, style: AppType.body(size: 15, height: 1.45)),
                        Text('♥ ${p.likeCount}    💬 ${p.commentCount}', style: AppType.body(size: 13, color: Palette.muted)),
                      ],
                    ),
                  ),
                  if (p.photoUrl case final url?)
                    ClipRRect(
                      borderRadius: Frame.buttonRadius,
                      child: Image.network(mediaUrl(url), width: 76, height: 76, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.square(dimension: 76)),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _timeline(List<ActivityItem> items) {
    if (items.isEmpty) return Text('Nothing yet.', style: AppType.body(color: Palette.muted));
    final now = DateTime.now();
    (IconData, Color, Color) look(String kind) => switch (kind) {
          'points' => (Icons.bolt_rounded, Palette.gold, Palette.onGold),
          'post' => (Icons.edit_outlined, Palette.navy, Palette.cream),
          'crew' => (Icons.groups_outlined, Palette.pink, Palette.onPink),
          _ => (Icons.favorite_rounded, Palette.crimson, Palette.onCrimson),
        };
    return Column(
      children: [
        for (final (i, a) in items.indexed)
          SlideIn(
            delay: Motion.stagger(i, stepMs: 60),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 14,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: look(a.kind).$2, shape: BoxShape.circle),
                        child: Icon(look(a.kind).$1, size: 18, color: look(a.kind).$3),
                      ),
                      if (i < items.length - 1) Expanded(child: Container(width: 2, color: Palette.border)),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 7, bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(a.text, style: AppType.body(size: 15)),
                          if (a.at case final at?) Text(timeAgo(at, now) == 'now' ? 'Just now' : '${timeAgo(at, now)} ago', style: AppType.body(size: 12, color: Palette.muted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
