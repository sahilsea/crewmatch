import 'package:material_ui/material_ui.dart';

import '../../models/user.dart';
import '../../state/incoming_link.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';

/// What someone sees when they open a profile link without being signed in.
class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.handle});

  final String handle;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  User? _user;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await context.api.publicProfile(widget.handle);
      if (mounted) setState(() => _user = user);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// On to sign in; the profile opens again afterwards.
  void _join() => IncomingLink.showPublic.value = false;

  @override
  Widget build(BuildContext context) {
    final u = _user;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
              child: Row(
                spacing: 12,
                children: [
                  const BrandMark(size: 34),
                  Expanded(child: Text('CrewMatch', style: AppType.title(size: 22))),
                  TextButton(onPressed: _join, child: const Text('Sign in')),
                ],
              ),
            ),
            const Divider(height: 1, color: Palette.border),
            Expanded(
              child: u == null
                  ? (_error == null
                      ? const LoadingView()
                      : EmptyState(
                          title: 'Profile not found',
                          message: 'This link may be old or mistyped.',
                          actions: [FilledButton(onPressed: _join, child: const Text('Open CrewMatch'))],
                        ))
                  : Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Rise(child: _Card(user: u, onJoin: _join)),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.user, required this.onJoin});

  final User user;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final first = user.name.split(' ').first;
    return Container(
      decoration: BoxDecoration(color: Palette.window, borderRadius: BorderRadius.circular(24), border: Frame.border),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 120, color: Palette.navy),
          Transform.translate(
            offset: const Offset(0, -44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Palette.window, shape: BoxShape.circle),
                    child: Avatar(url: user.avatar, name: user.name, size: 88, background: Palette.pink),
                  ),
                  Text(user.name, style: AppType.title(size: 28)),
                  Text(
                    [
                      if (user.role != null) optionLabel(user.role!),
                      if (user.experienceLevel != null) optionLabel(user.experienceLevel!),
                      user.inCrew ? 'In a crew' : 'Looking for a crew',
                    ].join(' · '),
                    style: AppType.body(size: 14, color: Palette.muted),
                  ),
                  if (user.headline.isNotEmpty) Text(user.headline, style: AppType.body(size: 17, height: 1.5)),
                  if (user.skills.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: [for (final s in user.skills) Chip(label: Text(s))]),
                  const SizedBox(height: 10),
                  Text('Team up with $first?', style: AppType.title(size: 20)),
                  Text('Join CrewMatch free to send a request and see how well you fit.', style: AppType.body(size: 14.5, color: Palette.muted)),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onJoin,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      child: const Text('Join CrewMatch'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
