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
import 'whatsapp_template_picker.dart';

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

  /// Numbers typed so far, digits only, duplicates removed, in order.
  List<String> get _parsed {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in _numbers.text.split(RegExp(r'[\n,;]'))) {
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10 && digits.length <= 15 && seen.add(digits)) {
        out.add(digits);
      }
    }
    return out;
  }

  /// Entries that were typed but are too short or too long to be a number.
  int get _rejected {
    var count = 0;
    for (final raw in _numbers.text.split(RegExp(r'[\n,;]'))) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final digits = trimmed.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 10 || digits.length > 15) count++;
    }
    return count;
  }

  /// Ten-digit entries probably lack the country code.
  int get _tenDigit => _parsed.where((n) => n.length == 10).length;

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
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

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
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          'New bulk send',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                        const Icon(Icons.description_outlined, color: brand),
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
                        const Icon(Icons.chevron_right_rounded, color: muted),
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
                              color: const Color(0xFF4A5468),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          if (t != null && t.bodyVariables.isNotEmpty) ...[
            _label('Fill in the fields'),
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                'Everyone gets the same values.',
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
                      child: CircularProgressIndicator(strokeWidth: 2),
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
                if (rejected > 0) '$rejected skipped (too short or too long)',
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
          const SizedBox(height: 22),
          SheetNotice(_notice),
          FilledButton.icon(
            onPressed: _busy || _uploading ? null : _send,
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
            label: Text(
              count == 0
                  ? 'Send'
                  : 'Send to $count ${count == 1 ? 'number' : 'numbers'}',
            ),
          ),
        ],
      ),
    );
  }
}
