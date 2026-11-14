import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/skeleton.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/state_view.dart';
import 'whatsapp_campaigns_screen.dart' show StatusBadge;
import 'whatsapp_template_picker.dart';

const _matchLabels = {
  'contains': 'Contains',
  'exact': 'Exactly',
  'starts_with': 'Starts with',
  'regex': 'Pattern (regex)',
};

/// One chatbot: on/off, its settings and its keyword rules.
class WhatsAppChatbotScreen extends StatefulWidget {
  const WhatsAppChatbotScreen({super.key, required this.chatbotId});

  final String chatbotId;

  @override
  State<WhatsAppChatbotScreen> createState() => _WhatsAppChatbotScreenState();
}

class _WhatsAppChatbotScreenState extends State<WhatsAppChatbotScreen> {
  WaChatbot? _bot;
  bool _loading = true;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await WhatsAppService.chatbot(widget.chatbotId);
      if (!mounted) return;
      setState(() {
        _bot = b;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggle(WaChatbot b) async {
    if (_busy) return;
    if (!b.isActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Turn on "${b.name}"?'),
          content: const Text(
            'It starts replying to customers on its own right away, using '
            'the rules and settings below.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Turn on'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final fresh = await WhatsAppService.toggleChatbot(b.id);
      if (mounted) {
        setState(() => _bot = _withRules(fresh, b.rules));
      }
    } catch (e) {
      _snack(errorLine(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The toggle answer does not carry the rules, so keep the ones on screen.
  WaChatbot _withRules(WaChatbot fresh, List<WaChatRule> rules) => WaChatbot(
    id: fresh.id,
    name: fresh.name,
    isActive: fresh.isActive,
    isLeadFlow: fresh.isLeadFlow,
    welcome: fresh.welcome,
    fallback: fresh.fallback,
    aiEnabled: fresh.aiEnabled,
    aiInstructions: fresh.aiInstructions,
    followupEnabled: fresh.followupEnabled,
    followupMessage: fresh.followupMessage,
    rulesCount: rules.length,
    rules: rules,
    numberLabel: fresh.numberLabel,
  );

  Future<void> _sheet(Widget child) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => child,
    );
    if (message == null) return;
    _snack(message);
    _load();
  }

  Future<void> _delete(WaChatbot b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${b.name}"?'),
        content: const Text('The chatbot and all its rules are removed.'),
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
    setState(() => _busy = true);
    try {
      await WhatsAppService.deleteChatbot(b.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snack(errorLine(e));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleRule(WaChatbot b, WaChatRule r, bool on) async {
    try {
      await WhatsAppService.updateRule(b.id, r.id, active: on);
      await _load();
    } catch (e) {
      _snack(errorLine(e));
    }
  }

  Widget _body(WaChatbot b) {
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: ink,
                        ),
                      ),
                    ),
                    Switch(
                      value: b.isActive,
                      onChanged: _busy ? null : (_) => _toggle(b),
                    ),
                  ],
                ),
                Text(
                  b.isActive
                      ? 'On: replying to customers'
                      : 'Off: not replying',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: b.isActive ? good : muted,
                  ),
                ),
                if (b.numberLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Number ${b.numberLabel}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: muted,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _Line('Welcome', b.welcome),
                _Line('When nothing matches', b.fallback),
                _Line(
                  'AI replies',
                  b.aiEnabled
                      ? (b.aiInstructions.isEmpty ? 'On' : b.aiInstructions)
                      : 'Off',
                ),
                _Line(
                  'Follow-up',
                  b.followupEnabled
                      ? (b.followupMessage.isEmpty ? 'On' : b.followupMessage)
                      : 'Off',
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _sheet(_ChatbotSettingsSheet(bot: b)),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Edit settings'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Keyword rules (${b.rules.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: ink,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _sheet(_RuleSheet(chatbotId: b.id)),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add rule'),
                ),
              ],
            ),
          ),
          if (b.rules.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No rules yet. A rule says: when a customer\'s message matches a keyword, send this reply.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          for (final r in b.rules)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: cardDecoration(),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _busy
                    ? null
                    : () => _sheet(_RuleSheet(chatbotId: b.id, rule: r)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '"${r.keyword}"',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      color: ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  _matchLabels[r.matchType] ?? r.matchType,
                                  muted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              r.responseType == 'template'
                                  ? 'Sends template ${r.templateName}'
                                  : r.responseText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                color: const Color(0xFF4A5468),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: r.isActive,
                        onChanged: _busy ? null : (v) => _toggleRule(b, r, v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _busy ? null : () => _delete(b),
            style: TextButton.styleFrom(foregroundColor: bad),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete chatbot'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = _bot;
    final error = _error;
    Widget body;
    if (_loading) {
      body = const SkeletonList(count: 3, itemHeight: 80, headerHeight: 190);
    } else if (error != null && b == null) {
      final access = accessProblem(error);
      body = Center(
        child: SingleChildScrollView(
          child: access != null
              ? StateView(
                  icon: access.icon,
                  title: access.title,
                  text: access.text,
                )
              : StateView.error(
                  title: 'Could not load this chatbot',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    } else {
      body = _body(b!);
    }
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          'Chatbot',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
      ),
      body: body,
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          Text(
            value.isEmpty ? 'Not set' : value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: value.isEmpty ? muted : ink,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDec(String label, {String? hint, String? helper}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 3,
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );

Widget _grabber() => Center(
  child: Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: muted.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(4),
    ),
  ),
);

class _ChatbotSettingsSheet extends StatefulWidget {
  const _ChatbotSettingsSheet({required this.bot});

  final WaChatbot bot;

  @override
  State<_ChatbotSettingsSheet> createState() => _ChatbotSettingsSheetState();
}

class _ChatbotSettingsSheetState extends State<_ChatbotSettingsSheet> {
  late final _name = TextEditingController(text: widget.bot.name);
  late final _welcome = TextEditingController(text: widget.bot.welcome);
  late final _fallback = TextEditingController(text: widget.bot.fallback);
  late final _ai = TextEditingController(text: widget.bot.aiInstructions);
  late final _follow = TextEditingController(text: widget.bot.followupMessage);
  late bool _aiOn = widget.bot.aiEnabled;
  late bool _followOn = widget.bot.followupEnabled;
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _welcome.dispose();
    _fallback.dispose();
    _ai.dispose();
    _follow.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      HapticFeedback.lightImpact();
      setState(() => _notice = 'The chatbot needs a name.');
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await WhatsAppService.updateChatbot(
        widget.bot.id,
        name: _name.text.trim(),
        welcome: _welcome.text.trim(),
        fallback: _fallback.text.trim(),
        aiEnabled: _aiOn,
        aiInstructions: _ai.text.trim(),
        followupEnabled: _followOn,
        followupMessage: _follow.text.trim(),
      );
      if (mounted) Navigator.of(context).pop('Settings saved.');
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _grabber(),
              const SizedBox(height: 14),
              Text(
                'Chatbot settings',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: ink,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                enabled: !_busy,
                decoration: _fieldDec('Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _welcome,
                enabled: !_busy,
                minLines: 2,
                maxLines: 5,
                decoration: _fieldDec('Welcome message'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fallback,
                enabled: !_busy,
                minLines: 2,
                maxLines: 5,
                decoration: _fieldDec('When nothing matches'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('AI replies'),
                subtitle: const Text(
                  'Let AI answer messages that no rule matches',
                ),
                value: _aiOn,
                onChanged: _busy ? null : (v) => setState(() => _aiOn = v),
              ),
              if (_aiOn)
                TextField(
                  controller: _ai,
                  enabled: !_busy,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 8000,
                  decoration: _fieldDec(
                    'Instructions for the AI',
                    hint:
                        'We sell sarees. Be friendly and short. Prices start at ₹999.',
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Follow-up'),
                subtitle: const Text('Nudge customers who stop replying'),
                value: _followOn,
                onChanged: _busy ? null : (v) => setState(() => _followOn = v),
              ),
              if (_followOn)
                TextField(
                  controller: _follow,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: _fieldDec('Follow-up message'),
                ),
              const SizedBox(height: 12),
              SheetNotice(_notice),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleSheet extends StatefulWidget {
  const _RuleSheet({required this.chatbotId, this.rule});

  final String chatbotId;
  final WaChatRule? rule;

  @override
  State<_RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends State<_RuleSheet> {
  late final _keyword = TextEditingController(text: widget.rule?.keyword ?? '');
  late final _text = TextEditingController(
    text: widget.rule?.responseText ?? '',
  );
  late final _priority = TextEditingController(
    text: '${widget.rule?.priority ?? 0}',
  );
  late String _match = widget.rule?.matchType ?? 'contains';
  late String _type = widget.rule?.responseType ?? 'text';
  late String _template = widget.rule?.templateName ?? '';
  bool _busy = false;
  String? _notice;

  bool get _isNew => widget.rule == null;

  @override
  void dispose() {
    _keyword.dispose();
    _text.dispose();
    _priority.dispose();
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
        title: 'Reply with a template',
        subtitle: 'Only approved templates without fields can be used.',
      ),
    );
    if (t != null) setState(() => _template = t.name);
  }

  String? _validate() {
    if (_keyword.text.trim().isEmpty) return 'Write the keyword to look for.';
    if (_match == 'regex') {
      try {
        RegExp(_keyword.text.trim());
      } catch (_) {
        return 'That pattern is not valid.';
      }
    }
    if (_type == 'text' && _text.text.trim().isEmpty) {
      return 'Write the reply to send.';
    }
    if (_type == 'template' && _template.isEmpty) return 'Choose a template.';
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      HapticFeedback.lightImpact();
      setState(() => _notice = problem);
      return;
    }
    final priority = int.tryParse(_priority.text.trim()) ?? 0;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      if (_isNew) {
        await WhatsAppService.addRule(
          widget.chatbotId,
          keyword: _keyword.text.trim(),
          matchType: _match,
          responseType: _type,
          responseText: _type == 'text' ? _text.text.trim() : '',
          templateName: _type == 'template' ? _template : '',
          priority: priority,
        );
      } else {
        await WhatsAppService.updateRule(
          widget.chatbotId,
          widget.rule!.id,
          keyword: _keyword.text.trim(),
          matchType: _match,
          responseType: _type,
          responseText: _type == 'text' ? _text.text.trim() : '',
          templateName: _type == 'template' ? _template : '',
          priority: priority,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(_isNew ? 'Rule added.' : 'Rule saved.');
      }
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

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this rule?'),
        content: Text('The reply for "${widget.rule!.keyword}" is removed.'),
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
    setState(() => _busy = true);
    try {
      await WhatsAppService.deleteRule(widget.chatbotId, widget.rule!.id);
      if (mounted) Navigator.of(context).pop('Rule deleted.');
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
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _grabber(),
              const SizedBox(height: 14),
              Text(
                _isNew ? 'Add a rule' : 'Edit rule',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: ink,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _keyword,
                enabled: !_busy,
                decoration: _fieldDec('Keyword', hint: 'price'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _match,
                isExpanded: true,
                decoration: _fieldDec('A message matches when it'),
                items: [
                  for (final e in _matchLabels.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _match = v!),
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'text', label: Text('Text reply')),
                  ButtonSegment(value: 'template', label: Text('Template')),
                ],
                selected: {_type},
                onSelectionChanged: _busy
                    ? null
                    : (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),
              if (_type == 'text')
                TextField(
                  controller: _text,
                  enabled: !_busy,
                  minLines: 3,
                  maxLines: 8,
                  decoration: _fieldDec('Reply'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickTemplate,
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: Text(
                    _template.isEmpty ? 'Choose a template' : _template,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _priority,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _fieldDec(
                  'Order',
                  helper: 'Lower numbers are checked first.',
                ),
              ),
              const SizedBox(height: 14),
              SheetNotice(_notice),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isNew ? 'Add rule' : 'Save rule'),
              ),
              if (!_isNew)
                TextButton.icon(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: bad),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete rule'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
