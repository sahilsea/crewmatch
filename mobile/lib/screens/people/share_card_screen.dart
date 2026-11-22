import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/team_request.dart';
import '../../state/session.dart';
import '../../ui/ui.dart';
import '../../util/labels.dart';
import 'people_ui.dart';
import 'person_screen.dart';

/// Your card: a QR code and link people can open, and a scanner for theirs.
class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({super.key, this.scan = false});

  /// Opens on the scanner instead of your code.
  final bool scan;

  static Route<void> route({bool scan = false}) => MaterialPageRoute(builder: (_) => ShareCardScreen(scan: scan));

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  late var _scan = widget.scan;
  var _copied = false;
  var _opening = false;
  final _pasted = TextEditingController();

  @override
  void dispose() {
    _pasted.dispose();
    super.dispose();
  }

  /// Opens a scanned or pasted profile once.
  Future<void> _openHandle(String? handle, RequestSource source) async {
    if (handle == null) {
      showNotice(context, "That isn't a CrewMatch profile link");
      return;
    }
    if (_opening) return;
    _opening = true;
    await Navigator.of(context).push(PersonScreen.route(handle, source: source));
    _opening = false;
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionScope.watch(context).user!;
    final link = profileLink(user.handle ?? '');
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeader(
                  title: 'Your card',
                  leading: IconButton(tooltip: 'Close', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('My code'), icon: Icon(Icons.qr_code_rounded)),
                      ButtonSegment(value: true, label: Text('Scan'), icon: Icon(Icons.qr_code_scanner_rounded)),
                    ],
                    selected: {_scan},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _scan = s.first),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, const Duration(milliseconds: 300)),
                    child: _scan ? _scanner() : _myCode(user.name, user.avatar, user.role, link),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _myCode(String name, String avatar, String? role, String link) => ListView(
        key: const ValueKey('code'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          PopIn(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Palette.window, borderRadius: BorderRadius.circular(24), border: Frame.border),
              child: Column(
                spacing: 14,
                children: [
                  Row(
                    spacing: 12,
                    children: [
                      Avatar(url: avatar, name: name, size: 44, background: Palette.pink),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: AppType.body(size: 16, weight: FontWeight.w700)),
                            if (role != null) Text(optionLabel(role), style: AppType.body(size: 13, color: Palette.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _Qr(link: link, size: 220),
                  Text('Scan to see my card and team up', style: AppType.body(size: 14, color: Palette.muted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: const BoxDecoration(color: Palette.strip, borderRadius: Frame.buttonRadius),
            child: Row(
              spacing: 10,
              children: [
                const Icon(Icons.link_rounded, size: 18, color: Palette.muted),
                Expanded(child: Text(link.replaceFirst(RegExp('^https?://'), ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13))),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    setState(() => _copied = true);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _copied = false);
                    });
                  },
                  icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 16),
                  label: Text(_copied ? 'Copied' : 'Copy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            spacing: 10,
            children: [
              Expanded(
                flex: 4,
                child: FilledButton.icon(
                  onPressed: () => SharePlus.instance.share(ShareParams(text: 'Team up with me on CrewMatch: $link')),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share link'),
                ),
              ),
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: () => _shareQr(link),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Share QR'),
                ),
              ),
            ],
          ),
        ],
      );

  /// Shares the QR code as a picture, to save or post.
  Future<void> _shareQr(String link) async {
    final painter = QrPainter(
      data: link,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      gapless: true,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF2A1A12)),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF2A1A12)),
    );
    final data = await painter.toImageData(900);
    if (data == null) return;
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'crewmatch-qr.png')],
      text: 'Team up with me on CrewMatch: $link',
    ));
  }

  Widget _scanner() => ListView(
        key: const ValueKey('scan'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 340,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    onDetect: (capture) {
                      for (final code in capture.barcodes) {
                        final handle = handleFromLink(code.rawValue ?? '');
                        if (handle != null) {
                          _openHandle(handle, RequestSource.qr);
                          return;
                        }
                      }
                    },
                    errorBuilder: (context, error) => ColoredBox(
                      color: const Color(0xFF1A140F),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            "Can't open the camera. Allow camera access, or paste their link below.",
                            textAlign: TextAlign.center,
                            style: AppType.body(size: 14, color: const Color(0xFFF3E9D2)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const IgnorePointer(child: CustomPaint(painter: _Brackets())),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Text(
                      'Point at a CrewMatch code',
                      textAlign: TextAlign.center,
                      style: AppType.body(size: 14, weight: FontWeight.w500, color: const Color(0xFFF3E9D2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          LabeledField(
            label: 'Or paste a profile link',
            controller: _pasted,
            hint: 'crewmatch.netlify.app/u/…',
            keyboardType: TextInputType.url,
            onSubmitted: (v) => _openHandle(handleFromLink(v), RequestSource.link),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _openHandle(handleFromLink(_pasted.text), RequestSource.link),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Open profile'),
          ),
        ],
      );
}

/// A QR code with the CrewMatch logo in the middle.
class _Qr extends StatelessWidget {
  const _Qr({required this.link, required this.size});

  final String link;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFFFBF2), borderRadius: BorderRadius.circular(18)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            QrImageView(
              data: link,
              size: size,
              padding: EdgeInsets.zero,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              semanticsLabel: 'QR code for your profile',
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF2A1A12)),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF2A1A12)),
            ),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: const Color(0xFFF7EEDC), borderRadius: BorderRadius.circular(10)),
              child: BrandMark(size: size * 0.16, style: MarkStyle.brand),
            ),
          ],
        ),
      );
}

/// Gold corner brackets over the camera view.
class _Brackets extends CustomPainter {
  const _Brackets();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8C25E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final side = size.shortestSide * 0.62;
    final r = Rect.fromCenter(center: size.center(Offset.zero), width: side, height: side);
    const l = 34.0;
    for (final (corner, dx, dy) in [(r.topLeft, 1.0, 1.0), (r.topRight, -1.0, 1.0), (r.bottomLeft, 1.0, -1.0), (r.bottomRight, -1.0, -1.0)]) {
      canvas.drawLine(corner, corner + Offset(l * dx, 0), paint);
      canvas.drawLine(corner, corner + Offset(0, l * dy), paint);
    }
  }

  @override
  bool shouldRepaint(_Brackets old) => false;
}
