import 'package:material_ui/material_ui.dart';

import '../../ui/ui.dart';

/// The "welcome.txt" window above the sign-in form: three faces and the pitch.
class WelcomeWindow extends StatelessWidget {
  const WelcomeWindow({super.key});

  static String _face(String seed) =>
      'https://api.dicebear.com/9.x/notionists/png?seed=${Uri.encodeComponent(seed)}';

  @override
  Widget build(BuildContext context) => RetroWindow(
        title: 'welcome.txt',
        inset: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 104,
              decoration: const BoxDecoration(border: Border(bottom: Frame.side)),
              child: Halftone(
                color: Palette.blue,
                child: Center(
                  child: SizedBox(
                    width: 192,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 0,
                          child: Avatar(url: _face('Tara Fernandes'), name: 'Tara', size: 70),
                        ),
                        Positioned(
                          right: 0,
                          child: Avatar(
                            url: _face('Aisha Siddiqui'),
                            name: 'Aisha',
                            size: 70,
                            background: Palette.pink,
                          ),
                        ),
                        Avatar(
                          url: _face('Aarav Sharma'),
                          name: 'Aarav',
                          size: 80,
                          background: Palette.strip,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text(
                    'Find the teammates your team is missing.',
                    style: AppType.headline(size: 31),
                  ),
                  Text(
                    'Swipe through students ranked by how well they fill your gaps. '
                    'Match, form a crew, then score points at the hackathon.',
                    style: AppType.body(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
