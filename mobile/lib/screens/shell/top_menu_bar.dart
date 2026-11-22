import 'package:material_ui/material_ui.dart';

import '../../state/appearance.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../profile/card_editor_screen.dart';
import '../profile/profile_screen.dart';

/// The header across the top: logo, CrewMatch, and a slot on the right.
class TopMenuBar extends StatelessWidget {
  const TopMenuBar({super.key, this.trailing});

  /// Usually the [AccountMenu]; a date or a log-out button on other screens.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    padding: const EdgeInsets.only(left: 12),
    color: Palette.desktop,
    child: Row(
      children: [
        const BrandMark(size: 34),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                header: true,
                child: Text('CrewMatch', style: AppType.title(size: 20)),
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A small text slot for the header, e.g. today's date.
class MenuBarText extends StatelessWidget {
  const MenuBarText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Center(child: Label(text, size: 19, color: Palette.muted)),
  );
}

/// Asks first, then signs out and goes back to the sign-in screen.
Future<void> confirmSignOut(BuildContext context) async {
  final session = context.session;
  final yes = await confirmAction(
    context,
    title: 'Log out',
    message: 'Log out of CrewMatch on this device?',
    confirmLabel: 'Log out',
  );
  if (yes) await session.signOut(notice: 'You have logged out.');
}

/// A LOG OUT button for the header.
class LogOutButton extends StatelessWidget {
  const LogOutButton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: TextButton(
      onPressed: () => confirmSignOut(context),
      child: const Text('Log out'),
    ),
  );
}

enum _AccountAction { card, profile, light, dark, system, signOut }

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
          case _AccountAction.card:
            Navigator.of(context).push(CardEditorScreen.route());
          case _AccountAction.profile:
            Navigator.of(context).push(ProfileScreen.route());
          case _AccountAction.light:
            Appearance.instance.choose(ThemeMode.light);
          case _AccountAction.dark:
            Appearance.instance.choose(ThemeMode.dark);
          case _AccountAction.system:
            Appearance.instance.choose(ThemeMode.system);
          case _AccountAction.signOut:
            confirmSignOut(context);
        }
      },
      itemBuilder: (context) {
        final mode = Appearance.instance.value;
        return [
          // Organisers have no student card or profile.
          if (user?.isAdmin != true) ...[
            const PopupMenuItem(value: _AccountAction.card, child: Text('Your card')),
            const PopupMenuItem(value: _AccountAction.profile, child: Text('Profile')),
            const PopupMenuDivider(),
          ],
          CheckedPopupMenuItem(value: _AccountAction.light, checked: mode == ThemeMode.light, child: const Text('Light')),
          CheckedPopupMenuItem(value: _AccountAction.dark, checked: mode == ThemeMode.dark, child: const Text('Dark')),
          CheckedPopupMenuItem(value: _AccountAction.system, checked: mode == ThemeMode.system, child: const Text('Match phone')),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _AccountAction.signOut,
            child: Row(
              spacing: 10,
              children: [
                const Icon(Icons.logout_rounded, size: 20, color: Palette.danger),
                Text('Log out', style: AppType.body(size: 15, color: Palette.danger)),
              ],
            ),
          ),
        ];
      },
      child: SizedBox(
        width: 56,
        child: Center(
          child: Avatar(
            url: user?.avatar ?? '',
            name: user?.name ?? '',
            size: 34,
          ),
        ),
      ),
    );
  }
}
