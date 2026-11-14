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

const _languages = {
  'en_US': 'English (US)',
  'en': 'English',
  'en_GB': 'English (UK)',
  'hi': 'Hindi',
  'mr': 'Marathi',
  'gu': 'Gujarati',
  'ta': 'Tamil',
  'te': 'Telugu',
  'kn': 'Kannada',
  'ml': 'Malayalam',
  'bn': 'Bengali',
  'pa': 'Punjabi',
  'ur': 'Urdu',
  'es': 'Spanish',
  'pt_BR': 'Portuguese (Brazil)',
  'fr': 'French',
  'de': 'German',
  'ar': 'Arabic',
  'id': 'Indonesian',
};

const _categories = {
  'UTILITY': 'Utility (order updates, reminders)',
  'MARKETING': 'Marketing (offers, promotions)',
  'AUTHENTICATION': 'Authentication (one-time codes)',
};

/// Builds a template and submits it to Meta for approval. Pops with the
/// server's message once it is submitted.
class WhatsAppTemplateCreateScreen extends StatefulWidget {
  const WhatsAppTemplateCreateScreen({super.key});

  @override
  State<WhatsAppTemplateCreateScreen> createState() =>
      _WhatsAppTemplateCreateScreenState();
}

class _WhatsAppTemplateCreateScreenState
    extends State<WhatsAppTemplateCreateScreen> {
  final _name = TextEditingController();
  final _body = TextEditingController();
  final _headerText = TextEditingController();
  final _footer = TextEditingController();
  final _examples = <int, TextEditingController>{};

  String _language = 'en_US';
  String _category = 'UTILITY';
  String _headerFormat = 'NONE';
  String _handle = '';
  String _sampleName = '';
  final List<WaTemplateButton> _buttons = [];
  bool _uploading = false;
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _body.dispose();
    _headerText.dispose();
    _footer.dispose();
    for (final c in _examples.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// The {{1}}, {{2}} numbers used in the body, in order.
  List<int> get _variables {
    final found =
        RegExp(r'\{\{\s*(\d+)\s*\}\}')
            .allMatches(_body.text)
            .map((m) => int.parse(m.group(1)!))
            .toSet()
            .toList()
          ..sort();
    return found;
  }

  TextEditingController _exampleFor(int n) =>
      _examples.putIfAbsent(n, TextEditingController.new);

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

  void _error(String text) {
    HapticFeedback.lightImpact();
    setState(() => _notice = text);
  }

  Future<void> _pickSample() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_headerFormat == 'IMAGE')
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
    if (bytes.length > 5 * 1024 * 1024) {
      _error('The sample must be 5 MB or smaller.');
      return;
    }
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final allowed = switch (_headerFormat) {
      'IMAGE' => const ['jpg', 'jpeg', 'png'],
      'VIDEO' => const ['mp4'],
      _ => const ['pdf'],
    };
    if (!allowed.contains(ext)) {
      _error(
        'For this header choose a ${allowed.join(', ').toUpperCase()} file.',
      );
      return;
    }

    setState(() {
      _uploading = true;
      _notice = null;
    });
    try {
      final handle = await WhatsAppService.uploadTemplateSample(bytes, name);
      if (handle.isEmpty) throw StateError('no handle');
      if (mounted) {
        setState(() {
          _handle = handle;
          _sampleName = name;
        });
      }
    } catch (e) {
      if (mounted) _error(errorLine(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _addButton() async {
    final b = await showDialog<WaTemplateButton>(
      context: context,
      builder: (_) => const _ButtonDialog(),
    );
    if (b != null) setState(() => _buttons.add(b));
  }

  String? _validate() {
    final name = _name.text.trim();
    if (name.isEmpty) return 'Give the template a name.';
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(name)) {
      return 'The name can only use lowercase letters, numbers and underscores, like order_update.';
    }
    final body = _body.text.trim();
    if (body.isEmpty) return 'Write the message text.';
    if (body.length > 1024) {
      return 'The message is longer than 1024 characters.';
    }
    final vars = _variables;
    for (var i = 0; i < vars.length; i++) {
      if (vars[i] != i + 1) {
        return 'Fields must be numbered in order: {{1}}, {{2}}, {{3}}.';
      }
    }
    for (final n in vars) {
      if (_exampleFor(n).text.trim().isEmpty) {
        return 'Add an example for {{$n}}. Meta uses it to review the template.';
      }
    }
    if (_headerFormat == 'TEXT' && _headerText.text.trim().isEmpty) {
      return 'Write the header text, or choose no header.';
    }
    if (const {'IMAGE', 'VIDEO', 'DOCUMENT'}.contains(_headerFormat) &&
        _handle.isEmpty) {
      return 'Upload a sample file for the header first.';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      _error(problem);
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final message = await WhatsAppService.createTemplate(
        name: _name.text.trim(),
        language: _language,
        category: _category,
        body: _body.text.trim(),
        headerFormat: _headerFormat,
        headerText: _headerText.text.trim(),
        headerHandle: _headerFormat == 'NONE' || _headerFormat == 'TEXT'
            ? ''
            : _handle,
        bodyExamples: [for (final n in _variables) _exampleFor(n).text.trim()],
        footer: _footer.text.trim(),
        buttons: _buttons,
      );
      if (mounted) Navigator.of(context).pop(message);
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
    final vars = _variables;
    final media = const {'IMAGE', 'VIDEO', 'DOCUMENT'}.contains(_headerFormat);
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          'New template',
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
          _label('Name and type'),
          TextField(
            controller: _name,
            enabled: !_busy,
            autocorrect: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
            ],
            decoration: _dec(
              'Template name',
              hint: 'order_update',
              helper: 'Lowercase letters, numbers and underscores only.',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _language,
            isExpanded: true,
            decoration: _dec('Language'),
            items: [
              for (final e in _languages.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _language = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: _dec('Category'),
            items: [
              for (final e in _categories.entries)
                DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy ? null : (v) => setState(() => _category = v!),
          ),
          _label('Header (optional)'),
          DropdownButtonFormField<String>(
            initialValue: _headerFormat,
            isExpanded: true,
            decoration: _dec('Header'),
            items: const [
              DropdownMenuItem(value: 'NONE', child: Text('No header')),
              DropdownMenuItem(value: 'TEXT', child: Text('Text')),
              DropdownMenuItem(value: 'IMAGE', child: Text('Image')),
              DropdownMenuItem(value: 'VIDEO', child: Text('Video')),
              DropdownMenuItem(
                value: 'DOCUMENT',
                child: Text('Document (PDF)'),
              ),
            ],
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    _headerFormat = v!;
                    _handle = '';
                    _sampleName = '';
                  }),
          ),
          if (_headerFormat == 'TEXT') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _headerText,
              enabled: !_busy,
              maxLength: 60,
              decoration: _dec('Header text'),
            ),
          ],
          if (media) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy || _uploading ? null : _pickSample,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _handle.isEmpty
                          ? Icons.upload_file_rounded
                          : Icons.check_circle_rounded,
                      size: 18,
                      color: _handle.isEmpty ? null : good,
                    ),
              label: Text(
                _handle.isEmpty
                    ? 'Upload a sample (up to 5 MB)'
                    : 'Sample ready: $_sampleName',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                'Meta reviews a sample of the header. You choose the real file '
                'when you send the template.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: muted,
                ),
              ),
            ),
          ],
          _label('Message'),
          TextField(
            controller: _body,
            enabled: !_busy,
            minLines: 4,
            maxLines: 10,
            maxLength: 1024,
            onChanged: (_) => setState(() {}),
            decoration: _dec(
              'Message text',
              hint: 'Hi {{1}}, your order {{2}} is on its way.',
              helper: 'Use {{1}}, {{2}}… where a name or detail changes.',
            ),
          ),
          for (final n in vars) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _exampleFor(n),
              enabled: !_busy,
              decoration: _dec('Example for {{$n}}', hint: 'e.g. Priya'),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _footer,
            enabled: !_busy,
            maxLength: 60,
            decoration: _dec('Footer (optional)'),
          ),
          _label('Buttons (optional)'),
          for (var i = 0; i < _buttons.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    _buttons[i].type == 'URL'
                        ? Icons.open_in_new_rounded
                        : _buttons[i].type == 'PHONE_NUMBER'
                        ? Icons.call_rounded
                        : Icons.reply_rounded,
                    size: 18,
                    color: brand,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _buttons[i].text,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        Text(
                          switch (_buttons[i].type) {
                            'URL' => _buttons[i].url,
                            'PHONE_NUMBER' => _buttons[i].phone,
                            _ => 'Quick reply',
                          },
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _buttons.removeAt(i)),
                  ),
                ],
              ),
            ),
          if (_buttons.length < 3)
            OutlinedButton.icon(
              onPressed: _busy ? null : _addButton,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add a button'),
            ),
          const SizedBox(height: 20),
          SheetNotice(_notice),
          FilledButton(
            onPressed: _busy || _uploading ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit for approval'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              'Meta reviews every template. Approval usually takes a few '
              'minutes to 24 hours. You can only send it once approved.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonDialog extends StatefulWidget {
  const _ButtonDialog();

  @override
  State<_ButtonDialog> createState() => _ButtonDialogState();
}

class _ButtonDialogState extends State<_ButtonDialog> {
  final _text = TextEditingController();
  final _value = TextEditingController();
  String _type = 'QUICK_REPLY';
  String? _problem;

  @override
  void dispose() {
    _text.dispose();
    _value.dispose();
    super.dispose();
  }

  void _ok() {
    final text = _text.text.trim();
    final value = _value.text.trim();
    if (text.isEmpty) {
      setState(() => _problem = 'Write the button label.');
      return;
    }
    if (_type == 'URL' && !RegExp(r'^https?://\S+$').hasMatch(value)) {
      setState(() => _problem = 'Enter a full link starting with https://');
      return;
    }
    if (_type == 'PHONE_NUMBER' &&
        value.replaceAll(RegExp(r'\D'), '').length < 8) {
      setState(() => _problem = 'Enter the full phone number.');
      return;
    }
    Navigator.pop(
      context,
      WaTemplateButton(
        type: _type,
        text: text,
        url: _type == 'URL' ? value : '',
        phone: _type == 'PHONE_NUMBER' ? value : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a button'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(
                  value: 'QUICK_REPLY',
                  child: Text('Quick reply'),
                ),
                DropdownMenuItem(value: 'URL', child: Text('Open a link')),
                DropdownMenuItem(
                  value: 'PHONE_NUMBER',
                  child: Text('Call a number'),
                ),
              ],
              onChanged: (v) => setState(() {
                _type = v!;
                _problem = null;
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              maxLength: 25,
              decoration: const InputDecoration(labelText: 'Button label'),
            ),
            if (_type != 'QUICK_REPLY')
              TextField(
                controller: _value,
                keyboardType: _type == 'URL'
                    ? TextInputType.url
                    : TextInputType.phone,
                decoration: InputDecoration(
                  labelText: _type == 'URL' ? 'Link' : 'Phone number',
                  hintText: _type == 'URL'
                      ? 'https://example.com'
                      : '+91 98765 43210',
                ),
              ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _problem!,
                  style: const TextStyle(color: bad, fontSize: 12.5),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _ok, child: const Text('Add')),
      ],
    );
  }
}
