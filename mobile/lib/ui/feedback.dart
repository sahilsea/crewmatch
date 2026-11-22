import 'package:material_ui/material_ui.dart';

import '../api/api_exception.dart';
import 'palette.dart';
import 'type.dart';

/// A thin ink progress bar with a status line under it.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 10,
              decoration: BoxDecoration(border: Border.all(color: Palette.ink)),
              child: const LinearProgressIndicator(minHeight: 8),
            ),
            const SizedBox(height: 10),
            Label(message, color: Palette.mutedDark),
          ],
        ),
      );
}

/// A headline, a line of help and some actions, for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actions = const [],
  });

  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: AppType.headline(size: 26)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.body(color: Palette.mutedDark),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ],
        ),
      );
}

/// A failed load, with a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        title: error is ApiException && (error as ApiException).isOffline
            ? 'No connection'
            : 'Something went wrong',
        message: messageOf(error),
        actions: [OutlinedButton(onPressed: onRetry, child: const Text('Try again'))],
      );
}

/// An inline error box for forms and dialogs.
class ErrorNote extends StatelessWidget {
  const ErrorNote(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Tone(0xFFFCE4E6, Color(0xFF3A1A1A)),
            border: Border.all(color: Palette.danger, width: Frame.line),
          ),
          child: Text(message, style: AppType.body(size: 14.5, color: Palette.danger)),
        ),
      );
}

/// The message to show for any error thrown by an API call.
String messageOf(Object error) =>
    error is ApiException ? error.message : 'Something went wrong. Please try again.';

/// A short message in the black snack bar at the bottom of the screen.
void showNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
