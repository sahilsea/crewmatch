import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'motion.dart';
import 'palette.dart';
import 'type.dart';

/// A labelled text input: VT323 label above a square, ink-bordered field,
/// with the API's error for this field (if any) underneath.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.error,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.enabled = true,
    this.maxLength,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.onChanged,
    this.inputFormatters,
    this.style,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? error;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enabled;
  final int? maxLength;
  final int? maxLines;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Label(label, size: 18, color: Palette.ink),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            maxLength: maxLength,
            maxLines: maxLines,
            textCapitalization: textCapitalization,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            inputFormatters: inputFormatters,
            autofocus: autofocus,
            textAlign: textAlign,
            style: style ?? AppType.body(size: 16),
            decoration: InputDecoration(
              hintText: hint,
              errorText: error,
              errorMaxLines: 3,
              counterText: '',
            ),
          ),
        ],
      );
}

/// A bordered group with its legend sitting on the top edge, like an HTML fieldset.
class Fieldset extends StatelessWidget {
  const Fieldset({super.key, required this.legend, required this.child, this.error});

  final String legend;
  final Widget child;

  /// Shown under the group in red.
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(legend, style: AppType.body(size: 16, weight: FontWeight.w500, color: error == null ? Palette.ink : Palette.danger)),
          child,
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(error!, style: AppType.body(size: 13.5, color: Palette.danger)),
            ),
        ],
      );
}

/// A tappable option chip: gold with a check when selected.
class OptionChip extends StatelessWidget {
  const OptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = Palette.gold,
  });

  final String label;
  final bool selected;

  /// Null disables the chip (e.g. the superpower limit is reached).
  final VoidCallback? onTap;

  /// Fill when selected.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || selected;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Material(
        color: selected ? color : Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: selected ? color : (enabled ? Palette.dashed : Palette.border)),
          borderRadius: Frame.chipRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.of(context, const Duration(milliseconds: 180)),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (selected) PopIn(child: Icon(Icons.check_rounded, size: 16, color: color == Palette.gold ? Palette.onGold : Palette.cream)),
                Text(
                  label,
                  style: AppType.body(
                    size: 14,
                    weight: FontWeight.w500,
                    color: selected ? (color == Palette.gold ? Palette.onGold : Palette.cream) : (enabled ? Palette.ink : Palette.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
