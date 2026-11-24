import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/otp_login.dart';
import '../theme/brand.dart';

/// The 6-digit code as six separate boxes. Underneath sits one invisible text
/// field that takes the typing, paste and the phone's one-time-code autofill,
/// so it behaves like any text field; the boxes only show what it holds.
class OtpCodeBoxes extends StatelessWidget {
  const OtpCodeBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    this.enabled = true,
    this.hasError = false,
    this.onChanged,
    this.length = kOtpCodeLength,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  /// Red outline on every box, after a wrong code.
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final int length;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final text = controller.text;
              final active = focusNode.hasFocus && enabled
                  ? (text.length < length ? text.length : length - 1)
                  : -1;
              return ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _Box(
                          char: i < text.length ? text[i] : '',
                          active: i == active,
                          error: hasError,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              alwaysIncludeSemantics: true,
              child: Semantics(
                label: 'Verification code, $length digits',
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  enableInteractiveSelection: false,
                  showCursor: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(length),
                  ],
                  onChanged: onChanged,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.char, required this.active, required this.error});

  final String char;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final filled = char.isNotEmpty;
    final Color border;
    final double width;
    if (error) {
      border = bad;
      width = 1.6;
    } else if (active) {
      border = royalIndigo;
      width = 2;
    } else if (filled) {
      border = royalIndigo.withValues(alpha: 0.35);
      width = 1.2;
    } else {
      border = const Color(0xFFDDE2EE);
      width = 1;
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? Colors.white : surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: width),
        boxShadow: active
            ? [
                BoxShadow(
                  color: royalIndigo.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Text(
        char,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
    );
  }
}
