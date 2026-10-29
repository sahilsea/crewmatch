import 'package:material_ui/material_ui.dart';

import '../../models/user.dart';
import '../../ui/ui.dart';

/// "It's a match!" Resolves to true when the user wants to see their matches.
Future<bool> showMatchDialog(BuildContext context, {required User me, required User them}) async {
  final seeMatches = await showWindowDialog<bool>(
    context,
    title: 'New match',
    builder: (context) => _MatchBody(me: me, them: them),
  );
  return seeMatches ?? false;
}

class _MatchBody extends StatelessWidget {
  const _MatchBody({required this.me, required this.them});

  final User me;
  final User them;

  @override
  Widget build(BuildContext context) {
    final email = them.email;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(border: Border(bottom: Frame.side)),
          child: Halftone(
            color: Palette.pink,
            opacity: 0.16,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  Avatar(url: me.avatar, name: me.name, size: 92),
                  const GlyphIcon(Glyph.heart, size: 34, fill: Palette.cream),
                  Avatar(url: them.avatar, name: them.name, size: 92, background: Palette.blue),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            spacing: 8,
            children: [
              Text("It's a match!", textAlign: TextAlign.center, style: AppType.headline(size: 38)),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'You and '),
                    TextSpan(
                      text: them.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: ' both swiped right.'),
                  ],
                ),
                textAlign: TextAlign.center,
                style: AppType.body(size: 16),
              ),
              if (email != null)
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [const Label('Say hi:', size: 19), CopyText(email)],
                ),
            ],
          ),
        ),
        SegmentRow(
          segments: [
            Segment(label: 'See matches', onPressed: () => Navigator.of(context).pop(true)),
            Segment(
              label: 'Keep swiping',
              color: Palette.pink,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ],
    );
  }
}
