import 'package:material_ui/material_ui.dart';

import '../../ui/ui.dart';
import '../shell/top_menu_bar.dart';

/// Admins have no student profile to swipe with; their tools live on the web.
class AdminNoticeScreen extends StatelessWidget {
  const AdminNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              TopMenuBar(trailing: LogOutButton()),
              Padding(
                padding: EdgeInsets.all(14),
                child: RetroWindow(
                  title: 'Admin',
                  child: EmptyState(
                    title: 'Organisers use the web dashboard',
                    message: 'Admin accounts manage events, check-in codes and '
                        'submissions on the CrewMatch web app. Sign in with a '
                        'student account to use the mobile app.',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
