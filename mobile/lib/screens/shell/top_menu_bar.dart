import 'package:material_ui/material_ui.dart';

import '../../state/session.dart';
import '../../ui/ui.dart';
import '../profile/profile_screen.dart';

/// The menu bar across the top: logo, CREWMATCH, and a slot on the right.
class TopMenuBar extends StatelessWidget {
  const TopMenuBar({super.key, this.trailing});

  /// Usually the [AccountMenu]; a date or a log-out button on other screens.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        decoration: const BoxDecoration(
          color: Palette.window,
          border: Border(top: Frame.side, bottom: Frame.side),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ColoredBox(
              color: Palette.ink,
              child: SizedBox(
                width: 44,
                child: Center(child: GlyphIcon(Glyph.logo, size: 22, color: Palette.cream)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    header: true,
                    child: Text(
                      'CREWMATCH',
                      style: AppType.label(size: 22, color: Palette.ink).copyWith(letterSpacing: 1.8),
                    ),
                  ),
                ),
              ),
            ),
            if (trailing != null)
              DecoratedBox(
                decoration: const BoxDecoration(border: Border(left: Frame.side)),
                child: trailing,
              ),
          ],
        ),
      );
}

/// A VT323 text slot for the menu bar, e.g. today's date.
class MenuBarText extends StatelessWidget {
  const MenuBarText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Center(child: Label(text, size: 21, color: Palette.ink)),
      );
}

/// A pink LOG OUT button for the menu bar.
class LogOutButton extends StatelessWidget {
  const LogOutButton({super.key});

  @override
  Widget build(BuildContext context) => Material(
        color: Palette.pink,
        child: InkWell(
          onTap: () => context.session.signOut(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Center(child: Label('Log out', size: 21, color: Palette.ink)),
          ),
        ),
      );
}

enum _AccountAction { profile, signOut }

/// The avatar on the right of the menu bar, opening Profile / Log out.
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SessionScope.watch(context).user;
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      onSelected: (action) {
        switch (action) {
          case _AccountAction.profile:
            Navigator.of(context).push(ProfileScreen.route());
          case _AccountAction.signOut:
            context.session.signOut();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: _AccountAction.profile, child: Text('PROFILE')),
        PopupMenuItem(value: _AccountAction.signOut, child: Text('LOG OUT')),
      ],
      child: SizedBox(
        width: 56,
        child: Center(
          child: Avatar(url: user?.avatar ?? '', name: user?.name ?? '', size: 28),
        ),
      ),
    );
  }
}
