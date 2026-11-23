import 'package:material_ui/material_ui.dart';

import '../../models/user.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import '../discover/profile_card.dart';

/// Your card as others see it: in Discover, in someone's Matches list, and
/// next to your messages in crew chat.
class CardPreviewScreen extends StatefulWidget {
  const CardPreviewScreen({super.key, required this.me});

  /// Your card, including unsaved edits.
  final User me;

  /// Resolves to true for 'Looks good', which saves the card.
  static Route<bool> route(User me) => MaterialPageRoute(builder: (_) => CardPreviewScreen(me: me));

  @override
  State<CardPreviewScreen> createState() => _CardPreviewScreenState();
}

class _CardPreviewScreenState extends State<CardPreviewScreen> {
  var _tab = 0;
  var _dx = 0.0;

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final (accent, _) = CardStyle.accent(me.accent);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back to editing',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, color: Palette.ink),
                      ),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text('How others see you', style: AppType.title(size: 22)),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Discover')),
                      ButtonSegment(value: 1, label: Text('Matches')),
                      ButtonSegment(value: 2, label: Text('Chat')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: Palette.gold,
                      selectedForegroundColor: Palette.onGold,
                      foregroundColor: Palette.ink,
                      side: const BorderSide(color: Palette.dashed),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, const Duration(milliseconds: 300)),
                    switchInCurve: Motion.ease,
                    child: KeyedSubtree(
                      key: ValueKey(_tab),
                      child: switch (_tab) {
                        0 => _discover(me),
                        1 => _matches(me, accent),
                        _ => _chat(me, accent),
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    spacing: 10,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                          child: const Text('Edit'),
                        ),
                      ),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Looks good'),
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
    );
  }

  Widget _discover(User me) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      spacing: 10,
      children: [
        Expanded(
          child: GestureDetector(
            onPanUpdate: (d) => setState(() => _dx = (_dx + d.delta.dx).clamp(-120, 120)),
            onPanEnd: (_) => setState(() => _dx = 0),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _dx),
              duration: Motion.of(context, const Duration(milliseconds: 250)),
              curve: Motion.ease,
              builder: (context, dx, child) => Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.rotate(angle: dx * 0.001, child: child),
              ),
              child: ProfileCard(person: me, fitLabel: '88% fit'),
            ),
          ),
        ),
        Text('Try dragging it: this is what people swipe on.', style: AppType.body(size: 13, color: Palette.muted)),
      ],
    ),
  );

  Widget _matches(User me, Color accent) {
    Widget row(String name, String sub, Widget face, {bool mine = false}) => Opacity(
      opacity: mine ? 1 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: mine
            ? BoxDecoration(
                color: Palette.strip,
                borderRadius: Frame.radius,
                border: Border.all(color: Palette.gold, width: 2),
              )
            : null,
        child: Row(
          spacing: 12,
          children: [
            face,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppType.body(size: 16, weight: FontWeight.w500)),
                  Text(sub, style: AppType.body(size: 13, color: Palette.muted)),
                ],
              ),
            ),
            if (mine)
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(minimumSize: const Size(64, 36)),
                child: const Text('Add'),
              ),
          ],
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text("In someone's Matches list", style: AppType.body(size: 13, color: Palette.muted)),
        ),
        row(
          'Tara Fernandes',
          'Backend · 92% fit',
          const Avatar(url: '', name: 'Tara Fernandes', size: 46, background: Palette.pink),
        ),
        row(
          me.name,
          '${me.role == null ? '' : '${optionLabel(me.role!)} · '}88% fit',
          Avatar(url: me.avatar, name: me.name, size: 46, background: accent),
          mine: true,
        ),
        row(
          'Yash Agarwal',
          'Data & ML · 64% fit',
          const Avatar(url: '', name: 'Yash Agarwal', size: 46, background: Palette.pink),
        ),
      ],
    );
  }

  Widget _chat(User me, Color accent) {
    Widget bubble(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.window,
        border: Border.all(color: Palette.border),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Text(text, style: AppType.body(size: 15)),
    );
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          child: Text("In your crew's chat", style: AppType.body(size: 13, color: Palette.muted)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 8,
          children: [
            const Avatar(url: '', name: 'Aisha Siddiqui', size: 30, background: Palette.pink),
            Flexible(child: bubble('Who’s taking the demo video?')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 8,
          children: [
            Avatar(url: me.avatar, name: me.name, size: 30, background: accent),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(me.name.split(' ').first, style: AppType.body(size: 12, color: Palette.muted)),
                  ),
                  bubble('I can! I’ll cut it tonight 🎬'),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Your crew sees your photo next to everything you send.',
            style: AppType.body(size: 13, color: Palette.muted),
          ),
        ),
      ],
    );
  }
}
