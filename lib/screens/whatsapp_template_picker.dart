import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/state_view.dart';

/// Lists approved templates and pops with the one the person chose. After the
/// 24-hour window only a template can be sent. Templates that need fields to
/// be filled in (or a media header) are shown but cannot be picked here.
class WhatsAppTemplatePicker extends StatefulWidget {
  const WhatsAppTemplatePicker({super.key});

  @override
  State<WhatsAppTemplatePicker> createState() => _WhatsAppTemplatePickerState();
}

class _WhatsAppTemplatePickerState extends State<WhatsAppTemplatePicker> {
  List<WaTemplate>? _templates;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await WhatsAppService.approvedTemplates();
      // Ones that can be sent now first.
      list.sort((a, b) {
        if (a.needsInput != b.needsInput) return a.needsInput ? 1 : -1;
        return a.name.compareTo(b.name);
      });
      if (mounted) setState(() => _templates = list);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Widget _content() {
    final error = _error;
    if (error != null) {
      final access = accessProblem(error);
      return access != null
          ? StateView(
              icon: access.icon,
              title: access.title,
              text: access.text,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            )
          : StateView.error(
              title: 'Could not load templates',
              text: friendlyException(error).message,
              onRetry: _load,
            );
    }
    final list = _templates;
    if (list == null) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (list.isEmpty) {
      return const StateView(
        icon: Icons.description_outlined,
        title: 'No approved templates',
        text:
            'Templates are approved by Meta before they can be sent. Create '
            'one on the Eydia website and it will show up here.',
        padding: EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: list.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final t = list[i];
        return ListTile(
          enabled: !t.needsInput,
          onTap: t.needsInput ? null : () => Navigator.of(context).pop(t),
          title: Text(
            t.name,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: t.needsInput ? muted : ink,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              t.needsInput
                  ? 'Needs fields or media, so it cannot be sent from a chat.'
                  : (t.body.isEmpty ? t.language : t.body),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
            ),
          ),
          trailing: Text(
            t.language,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Send a template',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: ink,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Approved messages that can reach a customer after 24 hours.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: muted),
              ),
            ),
            Flexible(child: _content()),
          ],
        ),
      ),
    );
  }
}
