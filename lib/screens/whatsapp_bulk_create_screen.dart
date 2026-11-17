import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/wa_template_preview.dart';
import '../widgets/wa_ui.dart';
import 'whatsapp_template_picker.dart';

/// What was typed into the numbers box, understood.
class BulkNumbers {
  const BulkNumbers(this.valid, this.rejected, this.duplicates);

  /// Digits only, 10 to 15 of them, each number once, in the order typed.
  final List<String> valid;

  /// Entries too short or too long to be a phone number.
  final int rejected;

  /// Entries that repeated a number already in the list.
  final int duplicates;

  /// Ten-digit numbers: most likely missing the country code.
  int get tenDigit => valid.where((n) => n.length == 10).length;
}

final _numberSplit = RegExp(r'[\n,;]');

String _digitsOf(String s) => s.replaceAll(RegExp(r'\D'), '');

/// Reads numbers separated by new lines, commas or semicolons.
BulkNumbers parseBulkNumbers(String text) {
  final seen = <String>{};
  final valid = <String>[];
  var rejected = 0;
  var duplicates = 0;
  for (final raw in text.split(_numberSplit)) {
    if (raw.trim().isEmpty) continue;
    final digits = _digitsOf(raw);
    if (digits.length < 10 || digits.length > 15) {
      rejected++;
    } else if (seen.add(digits)) {
      valid.add(digits);
    } else {
      duplicates++;
    }
  }
  return BulkNumbers(valid, rejected, duplicates);
}

/// Puts [code] in front of every entry that is exactly 10 digits. Everything
/// else is kept as typed. Only runs when the person asks for it.
String addCountryCode(String text, [String code = '91']) {
  final out = <String>[];
  for (final raw in text.split(_numberSplit)) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    final digits = _digitsOf(t);
    out.add(digits.length == 10 ? '$code$digits' : t);
  }
  return out.join('\n');
}

/// Takes one number (every entry that has these digits) out of the typed text.
String removeBulkNumber(String text, String number) {
  final out = <String>[];
  for (final raw in text.split(_numberSplit)) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    if (_digitsOf(t) != number) out.add(t);
  }
  return out.join('\n');
}

/// Sends one approved template to a typed or pasted list of numbers. Fills in
/// the template's body fields and uploads its media header when it has one.
class WhatsAppBulkCreateScreen extends StatefulWidget {
  const WhatsAppBulkCreateScreen({super.key});

  @override
  State<WhatsAppBulkCreateScreen> createState() =>
      _WhatsAppBulkCreateScreenState();
}

class _WhatsAppBulkCreateScreenState extends State<WhatsAppBulkCreateScreen> {
  final _numbers = TextEditingController();
  final _vars = <int, TextEditingController>{};
  WaTemplate? _template;
  String _mediaId = '';
  String _mediaName = '';
  bool _uploading = false;
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _numbers.dispose();
    for (final c in _vars.values) {
      c.dispose();
    }
    super.dispose();
  }

  BulkNumbers get _stats => parseBulkNumbers(_numbers.text);
  List<String> get _parsed => _stats.valid;
  int get _rejected => _stats.rejected;

  /// Ten-digit entries probably lack the country code.
  int get _tenDigit => _stats.tenDigit;

  /// The review page is showing (the form is kept underneath, untouched).
  bool _reviewing = false;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      showToast(context, 'Nothing to paste. Copy some numbers first.');
      return;
    }
    final existing = _numbers.text.trimRight();
    setState(() {
      _numbers.text = existing.isEmpty ? text : '$existing\n$text';
    });
  }

  void _addCode() {
    final n = _tenDigit;
    setState(() => _numbers.text = addCountryCode(_numbers.text));
    showToast(context, 'Added 91 to $n ${n == 1 ? 'number' : 'numbers'}.');
  }

  void _removeNumber(String number) {
    setState(() => _numbers.text = removeBulkNumber(_numbers.text, number));
  }

  /// Checks the form, then shows the review page. Nothing is sent from here.
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

  TextEditingController _varFor(int n) =>
      _vars.putIfAbsent(n, TextEditingController.new);

  Future<void> _pickTemplate() async {
    final t = await showModalBottomSheet<WaTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const WhatsAppTemplatePicker(
        forBulk: true,
        title: 'Choose a template',
        subtitle: 'Only approved templates can be sent.',
      ),
    );
    if (t == null) return;
    setState(() {
      _template = t;
      _mediaId = '';
      _mediaName = '';
      for (final c in _vars.values) {
        c.clear();
      }
    });
  }

  void _error(String text) {
    HapticFeedback.lightImpact();
    setState(() => _notice = text);
  }

  Future<void> _pickHeader() async {
    final t = _template!;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (t.headerFormat == 'IMAGE')
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose a photo'),
                onTap: () => Navigator.pop(ctx, 'photo'),
              ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('Choose a file'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    List<int> bytes;
    String name;
    try {
      if (choice == 'photo') {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (picked == null) return;
        bytes = await picked.readAsBytes();
        name = picked.name.contains('.') ? picked.name : '${picked.name}.jpg';
      } else {
        final file = await FilePicker.pickFile();
        if (file == null) return;
        bytes = await file.readAsBytes();
        name = file.name;
      }
    } catch (_) {
      _error(
        'Could not open that. Allow access for Eydia in your phone settings.',
      );
      return;
    }
    if (bytes.isEmpty) {
      _error('That file could not be read. Please pick another one.');
      return;
    }
    if (bytes.length > 16 * 1024 * 1024) {
      _error('The file must be 16 MB or smaller.');
      return;
    }
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final allowed = switch (t.headerFormat) {
      'IMAGE' => const ['jpg', 'jpeg', 'png'],
      'VIDEO' => const ['mp4'],
      _ => const ['pdf'],
    };
    if (!allowed.contains(ext)) {
      _error('This template needs a ${allowed.join(', ').toUpperCase()} file.');
      return;
    }
    setState(() {
      _uploading = true;
      _notice = null;
    });
    try {
      final id = await WhatsAppService.uploadBulkHeader(bytes, name);
      if (id.isEmpty) throw StateError('no media id');
      if (mounted) {
        setState(() {
          _mediaId = id;
          _mediaName = name;
        });
      }
    } catch (e) {
      if (mounted) _error(errorLine(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String? _validate() {
    final t = _template;
    if (t == null) return 'Choose a template.';
    final count = _parsed.length;
    if (count == 0) return 'Add at least one phone number, with country code.';
    if (count > 1000) return 'A bulk send can have up to 1000 numbers.';
    for (final n in t.bodyVariables) {
      if (_varFor(n).text.trim().isEmpty) {
        return 'Fill in the value for {{$n}}.';
      }
    }
    if (t.hasMediaHeader && _mediaId.isEmpty) {
      return 'This template has a ${t.headerFormat.toLowerCase()} header. Upload the file to send.';
    }
    return null;
  }

  Future<void> _send() async {
    final problem = _validate();
    if (problem != null) {
      _error(problem);
      return;
    }
    final t = _template!;
    final numbers = _parsed;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send to ${numbers.length} numbers?'),
        content: Text(
          'Template "${t.name}" goes out now. Blocked numbers are skipped. '
          'Messages cannot be recalled once sent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
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
      final result = await WhatsAppService.sendBulk(
        numbers: numbers,
        template: t,
        variables: [for (final n in t.bodyVariables) _varFor(n).text.trim()],
        headerMediaId: _mediaId,
      );
      if (mounted) Navigator.of(context).pop(result);
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

  InputDecoration _dec(String label, {String? hint, String? helper}) =>
      waInputDecoration(label, hint: hint, helper: helper, onWhite: false);

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
    final count = _parsed.length;
    final rejected = _rejected;
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
            _reviewing ? 'Review bulk send' : 'New bulk send',
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
                    if (t != null && t.bodyVariables.isNotEmpty) ...[
                      _label('Template variables'),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(
                          'This template has ${t.bodyVariables.length} '
                          '${t.bodyVariables.length == 1 ? 'variable' : 'variables'}. '
                          'The same values are sent to every number.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: muted,
                          ),
                        ),
                      ),
                      for (final n in t.bodyVariables) ...[
                        TextField(
                          controller: _varFor(n),
                          enabled: !_busy,
                          decoration: _dec('Value for {{$n}}'),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (t != null && t.hasMediaHeader) ...[
                      _label('Header ${t.headerFormat.toLowerCase()}'),
                      OutlinedButton.icon(
                        onPressed: _busy || _uploading ? null : _pickHeader,
                        icon: _uploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _mediaId.isEmpty
                                    ? Icons.upload_file_rounded
                                    : Icons.check_circle_rounded,
                                size: 18,
                                color: _mediaId.isEmpty ? null : good,
                              ),
                        label: Text(
                          _mediaId.isEmpty
                              ? 'Upload the file to send (up to 16 MB)'
                              : 'Ready: $_mediaName',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    _label('Phone numbers'),
                    TextField(
                      controller: _numbers,
                      enabled: !_busy,
                      minLines: 5,
                      maxLines: 12,
                      keyboardType: TextInputType.multiline,
                      onChanged: (_) => setState(() {}),
                      decoration: _dec(
                        'Numbers',
                        hint: '919876543210\n919812345678',
                        helper:
                            'One per line, or separated by commas. Include the country '
                            'code (91 for India). Up to 1000.',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Text(
                        [
                          '$count valid ${count == 1 ? 'number' : 'numbers'}',
                          if (rejected > 0)
                            '$rejected skipped (too short or too long)',
                        ].join(' · '),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: count == 0 ? muted : good,
                        ),
                      ),
                    ),
                    if (_tenDigit > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                        child: Text(
                          '$_tenDigit ${_tenDigit == 1 ? 'number has' : 'numbers have'} only 10 digits. '
                          'Without the country code (91) WhatsApp cannot deliver them.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: warn,
                            height: 1.4,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ActionChip(
                            avatar: const Icon(
                              Icons.content_paste_rounded,
                              size: 16,
                            ),
                            label: const Text('Paste from clipboard'),
                            onPressed: _busy ? null : _paste,
                          ),
                          if (_tenDigit > 0)
                            ActionChip(
                              avatar: const Icon(Icons.add_rounded, size: 16),
                              label: Text(
                                'Add 91 to $_tenDigit ${_tenDigit == 1 ? 'number' : 'numbers'}',
                              ),
                              tooltip:
                                  'Put the India country code 91 in front of 10-digit numbers',
                              onPressed: _busy ? null : _addCode,
                            ),
                        ],
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final n in _parsed.take(12))
                            InputChip(
                              label: Text(n),
                              onDeleted: _busy ? null : () => _removeNumber(n),
                              deleteButtonTooltipMessage: 'Remove $n',
                            ),
                          if (count > 12)
                            InfoChip('and ${count - 12} more', color: muted),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    SheetNotice(_notice),
                    FilledButton.icon(
                      onPressed: _busy || _uploading ? null : _review,
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: Text(
                        count == 0
                            ? 'Review'
                            : 'Review $count ${count == 1 ? 'number' : 'numbers'}',
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// The last look before sending: the message as the customer will see it,
  /// who it goes to, and anything worth a second thought.
  Widget _reviewView() {
    final t = _template!;
    final stats = _stats;
    final count = stats.valid.length;
    final sample = stats.valid.take(5).toList();
    final fieldValues = {
      for (final n in t.bodyVariables) n: _varFor(n).text.trim(),
    };
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
          examples: fieldValues,
        ),
        if (t.hasMediaHeader && _mediaName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Header file: $_mediaName',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
            ),
          ),
        _label('Who gets it'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  '$count ${count == 1 ? 'number' : 'numbers'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final n in sample) InfoChip(n),
                  if (count > sample.length)
                    InfoChip('and ${count - sample.length} more', color: muted),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Numbers on your blocked list are skipped automatically.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        for (final w in [
          if (_tenDigit > 0)
            '$_tenDigit ${_tenDigit == 1 ? 'number has' : 'numbers have'} only '
                '10 digits. Without the country code (91) WhatsApp cannot '
                'deliver them. Go back and tap "Add 91" if they are Indian numbers.',
          if (stats.rejected > 0)
            '${stats.rejected} ${stats.rejected == 1 ? 'entry was' : 'entries were'} '
                'skipped because ${stats.rejected == 1 ? 'it is' : 'they are'} '
                'too short or too long.',
          if (stats.duplicates > 0)
            '${stats.duplicates} repeated ${stats.duplicates == 1 ? 'number was' : 'numbers were'} '
                'removed, so nobody gets the message twice.',
        ])
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: warn,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    w,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: ink,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        SheetNotice(_notice),
        FilledButton.icon(
          onPressed: _busy ? null : _send,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: Text('Send to $count ${count == 1 ? 'number' : 'numbers'}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : () => setState(() => _reviewing = false),
          child: const Text('Back to edit'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'You will be asked to confirm once more. Messages cannot be recalled once sent.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
          ),
        ),
      ],
    );
  }
}
