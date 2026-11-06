import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/brand.dart';

/// A message shown inside a bottom sheet. Snack bars appear on the screen
/// underneath and can sit behind the sheet, so anything the person must see
/// while a sheet is open (problems, hints) goes here instead.
class SheetNotice extends StatelessWidget {
  const SheetNotice(
    this.text, {
    super.key,
    this.error = true,
    this.actionLabel,
    this.onAction,
  });

  /// Null or empty shows nothing.
  final String? text;
  final bool error;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final message = text;
    final show = message != null && message.isNotEmpty;
    final tone = error ? bad : brand;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Semantics(
              // Screen readers announce a message the moment it appears.
              liveRegion: true,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tone.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        error
                            ? Icons.error_outline_rounded
                            : Icons.info_outline_rounded,
                        size: 17,
                        color: tone,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          height: 1.35,
                          color: ink,
                        ),
                      ),
                    ),
                    if (actionLabel != null && onAction != null)
                      TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          actionLabel!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: tone,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
