import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'type.dart';

/// Underlined text that copies itself when tapped, e.g. an email address.
class CopyText extends StatefulWidget {
  const CopyText(this.text, {super.key, this.label});

  final String text;

  /// What to show instead of [text], e.g. "Email".
  final String? label;

  @override
  State<CopyText> createState() => _CopyTextState();
}

class _CopyTextState extends State<CopyText> {
  var _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: _copy,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          textStyle: AppType.body(size: 14).copyWith(decoration: TextDecoration.underline),
        ),
        child: Text(
          _copied ? 'Copied ✓' : widget.label ?? widget.text,
          semanticsLabel: _copied ? 'Copied' : 'Copy ${widget.text}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
}
