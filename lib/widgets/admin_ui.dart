import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/brand.dart';

/// Shared building blocks for the super admin screens.

InputDecoration adminInput(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );

Future<T?> showAdminSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: builder,
  );
}

Future<bool> adminConfirm(
  BuildContext context, {
  required String title,
  required String text,
  String action = 'Confirm',
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: danger ? FilledButton.styleFrom(backgroundColor: bad) : null,
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

class AdminBadge extends StatelessWidget {
  const AdminBadge(this.text, this.color, {super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// Grab handle plus title for a bottom sheet.
class AdminSheetHeader extends StatelessWidget {
  const AdminSheetHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: muted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: ink,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

/// Empty or error state for a list.
class AdminMessage extends StatelessWidget {
  const AdminMessage({
    super.key,
    required this.icon,
    required this.title,
    this.text = '',
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 44, color: muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: ink,
            ),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: muted),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

Color adminStatusColor(String status) {
  switch (status) {
    case 'active':
    case 'paid':
    case 'resolved':
    case 'closed':
      return good;
    case 'suspended':
    case 'failed':
    case 'deleted':
      return bad;
    case 'in_progress':
    case 'trialing':
      return brand;
    default:
      return warn;
  }
}
