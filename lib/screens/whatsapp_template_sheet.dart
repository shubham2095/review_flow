import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/sheet_notice.dart';
import 'whatsapp_templates_screen.dart' show templateStatus;

/// One template, read-only, laid out like the message the customer receives.
/// Pops with a message after a delete so the list reloads.
class WhatsAppTemplateSheet extends StatefulWidget {
  const WhatsAppTemplateSheet({super.key, required this.template});

  final WaTemplate template;

  @override
  State<WhatsAppTemplateSheet> createState() => _WhatsAppTemplateSheetState();
}

class _WhatsAppTemplateSheetState extends State<WhatsAppTemplateSheet> {
  bool _busy = false;
  String? _notice;

  Future<void> _delete() async {
    final t = widget.template;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${t.name}"?'),
        content: const Text(
          'It is removed from Eydia and from your WhatsApp Business account '
          'on Meta. Campaigns that use it will stop working.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await WhatsAppService.deleteTemplate(t.id);
      if (mounted) Navigator.of(context).pop('${t.name} deleted.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _notice = errorLine(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final s = templateStatus(t.status);
    final mediaHeader = t.headerFormat.isNotEmpty && t.headerFormat != 'TEXT';
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                t.name,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Chip(s.label, s.color),
                  if (t.category.isNotEmpty)
                    _Chip(
                      t.category[0] + t.category.substring(1).toLowerCase(),
                      muted,
                    ),
                  _Chip(t.language, muted),
                  if (t.quality.isNotEmpty &&
                      t.quality.toUpperCase() != 'UNKNOWN')
                    _Chip('Quality ${t.quality}', muted),
                ],
              ),
              if (t.status.toUpperCase() == 'REJECTED' &&
                  t.rejectionReason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bad.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Meta rejected this: ${t.rejectionReason}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: ink,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEAE2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mediaHeader)
                        Container(
                          height: 90,
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: muted.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${t.headerFormat[0]}${t.headerFormat.substring(1).toLowerCase()} header',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                          ),
                        ),
                      if (t.headerFormat == 'TEXT' && t.headerText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            t.headerText,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                        ),
                      Text(
                        t.body.isEmpty ? '(no body text)' : t.body,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          height: 1.4,
                          color: ink,
                        ),
                      ),
                      if (t.footer.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            t.footer,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              for (final b in t.buttons)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          b.type == 'URL'
                              ? Icons.open_in_new_rounded
                              : b.type == 'PHONE_NUMBER'
                              ? Icons.call_rounded
                              : b.type == 'COPY_CODE'
                              ? Icons.copy_rounded
                              : Icons.reply_rounded,
                          size: 16,
                          color: brand,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            b.text,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: brand,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (t.lastSyncedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    'Status checked ${fmtDateTime(t.lastSyncedAt!)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: muted,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SheetNotice(_notice),
              TextButton.icon(
                onPressed: _busy ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: bad),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete template'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
