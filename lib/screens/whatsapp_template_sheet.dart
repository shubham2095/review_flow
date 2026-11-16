import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/wa_template_preview.dart';
import '../widgets/wa_ui.dart';
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
    return AppSheet(
      title: t.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusBadge(s.label, s.color),
              if (t.category.isNotEmpty)
                InfoChip(
                  t.category[0] + t.category.substring(1).toLowerCase(),
                ),
              InfoChip(t.language),
              if (t.quality.isNotEmpty && t.quality.toUpperCase() != 'UNKNOWN')
                InfoChip('Quality ${t.quality}'),
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
          WaTemplatePreview(
            body: t.body,
            headerFormat: t.headerFormat,
            headerText: t.headerText,
            footer: t.footer,
            buttons: t.buttons,
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
    );
  }
}
