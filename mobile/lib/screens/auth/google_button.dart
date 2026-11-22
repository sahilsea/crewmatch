import 'dart:async';
import 'dart:math' as math;

import 'package:google_sign_in/google_sign_in.dart';
import 'package:material_ui/material_ui.dart';

import '../../state/google_auth.dart';
import '../../ui/ui.dart';
import 'google_button_stub.dart' if (dart.library.js_interop) 'google_button_web.dart';

/// "Continue with Google". Hands the Google ID token to [onToken].
class GoogleButton extends StatefulWidget {
  const GoogleButton({super.key, required this.onToken, required this.registering, this.busy = false});

  final ValueChanged<String> onToken;
  final bool registering;
  final bool busy;

  @override
  State<GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<GoogleButton> {
  StreamSubscription<String>? _tokens;
  late final Future<void> _ready = GoogleAuth.ready();
  var _picking = false;

  @override
  void initState() {
    super.initState();
    if (GoogleAuth.usesGoogleButton) {
      _ready.then((_) {
        if (mounted) _tokens = GoogleAuth.buttonTokens.listen(widget.onToken);
      });
    }
  }

  @override
  void dispose() {
    _tokens?.cancel();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final token = await GoogleAuth.pickAccount();
      if (token != null && mounted) widget.onToken(token);
    } on GoogleSignInException catch (e) {
      if (mounted) showNotice(context, e.description ?? "Couldn't reach Google. Try again.");
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (GoogleAuth.usesGoogleButton) {
      return FutureBuilder<void>(
        future: _ready,
        builder: (context, snap) => snap.connectionState != ConnectionState.done
            ? const SizedBox(height: 44)
            : LayoutBuilder(
                builder: (context, c) => Center(
                  child: googleWebButton(dark: Palette.isDark, registering: widget.registering, width: c.maxWidth),
                ),
              ),
      );
    }
    final busy = widget.busy || _picking;
    return OutlinedButton(
      onPressed: busy ? null : _pick,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 12,
        children: [
          const SizedBox.square(dimension: 20, child: CustomPaint(painter: _GoogleG())),
          Flexible(
            child: Text(
              _picking ? 'Opening Google…' : (widget.registering ? 'Sign up with Google' : 'Continue with Google'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// "or" between the email form and Google.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          spacing: 12,
          children: [
            const Expanded(child: Divider(color: Palette.border)),
            Text('or', style: AppType.body(size: 14, color: Palette.muted)),
            const Expanded(child: Divider(color: Palette.border)),
          ],
        ),
      );
}

/// Google's four-colour "G".
class _GoogleG extends CustomPainter {
  const _GoogleG();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final rect = Rect.fromCircle(center: Offset(s / 2, s / 2), radius: (s - stroke) / 2);
    Paint arc(int color) => Paint()
      ..color = Color(color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    double rad(double deg) => deg * math.pi / 180;
    canvas.drawArc(rect, rad(-40), rad(-100), false, arc(0xFFEA4335));
    canvas.drawArc(rect, rad(-140), rad(-85), false, arc(0xFFFBBC05));
    canvas.drawArc(rect, rad(135), rad(-90), false, arc(0xFF34A853));
    canvas.drawArc(rect, rad(45), rad(-45), false, arc(0xFF4285F4));
    canvas.drawRect(Rect.fromLTWH(s / 2, s / 2 - stroke / 2, s / 2 - stroke / 4, stroke), Paint()..color = const Color(0xFF4285F4));
  }

  @override
  bool shouldRepaint(_GoogleG old) => false;
}
