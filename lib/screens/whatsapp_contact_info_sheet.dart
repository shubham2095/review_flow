import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/whatsapp_models.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/wa_ui.dart';

/// Read-only card for the person in a chat: name, number (copy or call), hot
/// lead reason and where the 24-hour reply window stands. Editing contacts
/// stays in the Contacts tab.
class WhatsAppContactInfoSheet extends StatelessWidget {
  const WhatsAppContactInfoSheet({super.key, required this.conversation});

  final WaConversation conversation;

  Future<void> _call(BuildContext context, String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse('tel:+$digits'));
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) showToast(context, 'Could not start a call.');
  }

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final contact = c.contact;
    final until = c.windowExpiresAt;
    final open =
        c.windowOpen && (until == null || until.isAfter(DateTime.now()));
    return AppSheet(
      title: contact.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ContactAvatar(name: contact.title, radius: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (contact.phone.isNotEmpty)
                      Text(
                        contact.phone,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: ink,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (contact.isHot)
                          const InfoChip(
                            'Hot lead',
                            icon: Icons.local_fire_department_rounded,
                            color: bad,
                          ),
                        InfoChip(
                          open ? 'Can reply' : 'Reply window closed',
                          icon: open
                              ? Icons.schedule_rounded
                              : Icons.lock_clock_rounded,
                          color: open ? good : muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (contact.isHot && contact.hotReason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bad.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                contact.hotReason,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: ink,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (open && until != null) ...[
            const SizedBox(height: 12),
            Text(
              'You can reply until ${fmtDateTime(until)}.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: muted),
            ),
          ],
          if (c.numberLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Chat on ${c.numberLabel}',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: muted),
            ),
          ],
          if (contact.phone.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: contact.phone),
                      );
                      if (context.mounted) showToast(context, 'Number copied.');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy number'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _call(context, contact.phone),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Call'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
