import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/app_update.dart';
import '../../ui/ui.dart';

/// "A new version is available": what's new, then Update downloads the APK.
Future<void> showUpdateDialog(BuildContext context, AppUpdate update) async {
  final download = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.system_update_rounded, size: 32, color: Palette.link),
      title: const Text('New version available'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 320),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InfoTag('v${update.current}', color: Palette.strip, textColor: Palette.muted),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: Palette.muted),
                  InfoTag('v${update.version}', color: Palette.gold, textColor: Palette.onGold),
                ],
              ),
              if (update.notes.isNotEmpty) ...[
                Text("What's new", style: AppType.body(size: 14, weight: FontWeight.w700)),
                Text(update.notes, style: AppType.body(size: 14, height: 1.45)),
              ],
              Text(
                'Update downloads the new app. Open the file when it finishes and tap Update. Your account and crew stay as they are.',
                style: AppType.body(size: 12.5, color: Palette.muted),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Update'),
        ),
      ],
    ),
  );
  if (download != true || !context.mounted) return;
  final opened = await launchUrl(Uri.parse(update.url), mode: LaunchMode.externalApplication);
  if (!context.mounted) return;
  showNotice(context, opened ? 'Downloading… open the file to install' : "Couldn't open the download");
}

/// From the account menu: check now and say so either way.
Future<void> checkForUpdatesNow(BuildContext context) async {
  final update = await UpdateChecker.check();
  if (!context.mounted) return;
  if (update != null) return showUpdateDialog(context, update);
  showNotice(context, "You're on the latest version");
}
