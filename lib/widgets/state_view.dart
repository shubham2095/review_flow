import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/brand.dart';
import 'fade_in.dart';

/// One look for empty and error states across the app: a tinted icon badge,
/// a title, a short line of help and an optional action.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.icon,
    required this.title,
    this.text = '',
    this.actionLabel,
    this.onAction,
    this.error = false,
    this.padding = const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
  });

  /// Failure state with a Try again style action.
  /// Having no connection gets its own, calmer wording: nothing is broken and
  /// nothing is lost.
  const StateView.error({
    super.key,
    required String title,
    required String text,
    required VoidCallback onRetry,
  }) : icon = text == kNetworkMessage
           ? Icons.wifi_off_rounded
           : Icons.cloud_off_rounded,
       title = text == kNetworkMessage ? "You're offline" : title,
       text = text == kNetworkMessage
           ? 'Check your internet connection and try again. Nothing has been lost.'
           : text,
       actionLabel = 'Try again',
       onAction = onRetry,
       error = text != kNetworkMessage,
       padding = const EdgeInsets.symmetric(vertical: 48, horizontal: 20);

  final IconData icon;
  final String title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool error;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tone = error ? bad : royalIndigo;
    return FadeIn(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    tone.withValues(alpha: 0.14),
                    tone.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(icon, size: 34, color: tone),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: ink,
              ),
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  height: 1.45,
                  color: muted,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
