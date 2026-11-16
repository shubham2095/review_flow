import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/wa_template_preview.dart';
import '../widgets/wa_ui.dart';
import 'whatsapp_template_picker.dart';

/// Builds a campaign draft: a name, an approved template and an audience. It
/// is saved as a draft; sending starts from the campaign page.
class WhatsAppCampaignCreateScreen extends StatefulWidget {
  const WhatsAppCampaignCreateScreen({super.key});

  @override
  State<WhatsAppCampaignCreateScreen> createState() =>
      _WhatsAppCampaignCreateScreenState();
}

class _WhatsAppCampaignCreateScreenState
    extends State<WhatsAppCampaignCreateScreen> {
  final _name = TextEditingController();
  WaTemplate? _template;
  String _source = '';
  bool _schedule = false;
  DateTime? _scheduledAt;
  bool _busy = false;
  String? _notice;

  /// The review page is showing (the form is kept untouched underneath).
  bool _reviewing = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickTemplate() async {
    final t = await showModalBottomSheet<WaTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const WhatsAppTemplatePicker(
        title: 'Choose a template',
        subtitle:
            'Campaigns send the template as written, so only templates '
            'without fields or media appear enabled.',
      ),
    );
    if (t != null) setState(() => _template = t);
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _error(String text) {
    HapticFeedback.lightImpact();
    setState(() => _notice = text);
  }

  /// What is missing or wrong in the form, or null.
  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Give the campaign a name.';
    if (_template == null) return 'Choose a template.';
    if (_schedule) {
      final at = _scheduledAt;
      if (at == null ||
          !at.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
        return 'Pick a time in the future to schedule.';
      }
    }
    return null;
  }

  /// Checks the form, then shows the review page. Nothing is saved from here.
  void _review() {
    final problem = _validate();
    if (problem != null) {
      _error(problem);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _notice = null;
      _reviewing = true;
    });
  }

  Future<void> _create() async {
    final problem = _validate();
    if (problem != null) {
      _error(problem);
      return;
    }
    final t = _template!;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final c = await WhatsAppService.createCampaign(
        name: _name.text.trim(),
        templateId: t.id,
        source: _source,
        scheduledAt: _schedule ? _scheduledAt : null,
      );
      if (mounted) Navigator.of(context).pop(c);
    } catch (e) {
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _busy = false;
          _notice = errorLine(e);
        });
      }
    }
  }

  InputDecoration _dec(String label, {String? hint}) =>
      waInputDecoration(label, hint: hint, onWhite: false);

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800,
        fontSize: 14,
        color: ink,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = _template;
    const sources = {
      '': 'All contacts',
      'manual': 'Added by hand',
      'import': 'Imported',
    };
    return PopScope(
      // Back from the review page returns to the form, not out of the screen.
      canPop: !_reviewing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) setState(() => _reviewing = false);
      },
      child: Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          title: Text(
            _reviewing ? 'Review campaign' : 'New campaign',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          foregroundColor: ink,
        ),
        body: ContentWidth(
          child: _reviewing
              ? _reviewView()
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    _label('Name'),
                    TextField(
                      controller: _name,
                      enabled: !_busy,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _dec('Campaign name', hint: 'Diwali offer'),
                    ),
                    _label('Message'),
                    InkWell(
                      onTap: _busy ? null : _pickTemplate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: t == null
                            ? Row(
                                children: [
                                  const Icon(
                                    Icons.description_outlined,
                                    color: brand,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Choose an approved template',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        color: brand,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: muted,
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          t.name,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w800,
                                            color: ink,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Change',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          color: brand,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (t.body.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      t.body,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: inkSoft,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                    _label('Who gets it'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final e in sources.entries)
                          ChoiceChip(
                            label: Text(e.value),
                            selected: _source == e.key,
                            onSelected: _busy
                                ? null
                                : (_) => setState(() => _source = e.key),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Text(
                        'Contacts you blocked or who opted out are always left out. '
                        'The recipient list is fixed when you create the campaign.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Schedule for later'),
                      subtitle: const Text('Otherwise you start it yourself'),
                      value: _schedule,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() {
                              _schedule = v;
                              if (!v) _scheduledAt = null;
                            }),
                    ),
                    if (_schedule)
                      InkWell(
                        onTap: _busy ? null : _pickTime,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event_rounded,
                                size: 18,
                                color: brand,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _scheduledAt == null
                                    ? 'Pick date and time'
                                    : fmtDateTime(_scheduledAt!),
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 22),
                    SheetNotice(_notice),
                    FilledButton.icon(
                      onPressed: _busy ? null : _review,
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: const Text('Review'),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                      child: Text(
                        'Nothing is saved or sent yet. You check everything on the next '
                        'page first.',
                        textAlign: TextAlign.center,
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
    );
  }

  /// The last look before the draft is created: the message as customers will
  /// see it, who it goes to and when.
  Widget _reviewView() {
    final t = _template!;
    const sources = {
      '': 'All contacts',
      'manual': 'Contacts added by hand',
      'import': 'Imported contacts',
    };
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: muted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _label('This is what they will get'),
        WaTemplatePreview(
          body: t.body,
          headerFormat: t.headerFormat,
          headerText: t.headerText,
          footer: t.footer,
          buttons: t.buttons,
        ),
        _label('Details'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row('Name', _name.text.trim()),
              row('Template', t.name),
              row('Audience', sources[_source] ?? _source),
              row(
                'When',
                _schedule && _scheduledAt != null
                    ? 'Scheduled for ${fmtDateTime(_scheduledAt!)}'
                    : 'You start it yourself',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: Text(
            'Contacts you blocked or who opted out are left out. The number of '
            'people is counted when the draft is created, and you see it on the '
            'next page. Nothing is sent until you start it there.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: muted,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 18),
        SheetNotice(_notice),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_schedule ? 'Create scheduled campaign' : 'Create draft'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : () => setState(() => _reviewing = false),
          child: const Text('Back to edit'),
        ),
      ],
    );
  }
}
