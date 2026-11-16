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
import '../widgets/wa_ui.dart';
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
    showToast(context, text);
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
                    Semantics(
                      label: 'Chatbot ${b.name}',
                      child: Switch(
                        value: b.isActive,
                        onChanged: _busy ? null : (_) => _toggle(b),
                      ),
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
          SectionTitle(
            'Keyword rules (${b.rules.length})',
            padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
            trailing: TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => _sheet(_RuleSheet(chatbotId: b.id)),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add rule'),
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
                            Text(
                              ruleSentence(r),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: r.isActive ? ink : muted,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ruleReplyLine(r),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                color: inkSoft,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: 'Rule "${r.keyword}"',
                        child: Switch(
                          value: r.isActive,
                          onChanged: _busy ? null : (v) => _toggleRule(b, r, v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SectionTitle(
            'Try a message',
            padding: EdgeInsets.fromLTRB(4, 14, 4, 10),
          ),
          _RuleTester(bot: b),
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

/// A rule read as a sentence: "When a message contains "price"".
String ruleSentence(WaChatRule r) {
  final k = '"${r.keyword}"';
  return switch (r.matchType) {
    'exact' => 'When a message is exactly $k',
    'starts_with' => 'When a message starts with $k',
    'regex' => 'When a message matches the pattern $k',
    _ => 'When a message contains $k',
  };
}

/// What the rule sends back, as one line.
String ruleReplyLine(WaChatRule r) => r.responseType == 'template'
    ? 'Sends the template ${r.templateName}'
    : 'Replies: ${r.responseText}';

/// Does [message] match the rule? An approximation of the server for the
/// "Try a message" box: it ignores upper and lower case.
bool ruleMatches(WaChatRule r, String message) {
  final text = message.trim().toLowerCase();
  final key = r.keyword.trim().toLowerCase();
  if (text.isEmpty || key.isEmpty) return false;
  switch (r.matchType) {
    case 'exact':
      return text == key;
    case 'starts_with':
      return text.startsWith(key);
    case 'regex':
      try {
        return RegExp(
          r.keyword.trim(),
          caseSensitive: false,
        ).hasMatch(message.trim());
      } catch (_) {
        return false;
      }
    default:
      return text.contains(key);
  }
}

/// The first active rule that matches, checking lower "order" numbers first.
WaChatRule? firstMatchingRule(List<WaChatRule> rules, String message) {
  final indexed = [
    for (var i = 0; i < rules.length; i++)
      if (rules[i].isActive) (i, rules[i]),
  ];
  indexed.sort((a, b) {
    final byPriority = a.$2.priority.compareTo(b.$2.priority);
    return byPriority != 0 ? byPriority : a.$1.compareTo(b.$1);
  });
  for (final e in indexed) {
    if (ruleMatches(e.$2, message)) return e.$2;
  }
  return null;
}

/// Type a customer message and see which rule would answer it. Nothing is
/// sent anywhere: it only runs on this phone.
class _RuleTester extends StatefulWidget {
  const _RuleTester({required this.bot});

  final WaChatbot bot;

  @override
  State<_RuleTester> createState() => _RuleTesterState();
}

class _RuleTesterState extends State<_RuleTester> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _result() {
    final b = widget.bot;
    final text = _c.text.trim();
    if (text.isEmpty) return '';
    final rule = firstMatchingRule(b.rules, text);
    final lead = b.isActive
        ? ''
        : 'The chatbot is off, so it would not reply. ';
    if (rule != null) {
      return '$lead${ruleSentence(rule)}. ${ruleReplyLine(rule)}';
    }
    if (b.aiEnabled) return '${lead}No rule matches. AI replies are on.';
    if (b.fallback.isNotEmpty) {
      return '${lead}No rule matches. The "When nothing matches" reply is '
          'used: ${b.fallback}';
    }
    return '${lead}No rule matches and no fallback reply is set.';
  }

  @override
  Widget build(BuildContext context) {
    final result = _result();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _c,
            onChanged: (_) => setState(() {}),
            decoration: waInputDecoration(
              'A customer writes',
              hint: 'What is the price?',
              helper: 'Only checks your rules on this phone. Nothing is sent.',
            ),
          ),
          if (result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  result,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: inkSoft,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Approximate: the server decides the real reply.',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

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
    return AppSheet(
      title: 'Chatbot settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            enabled: !_busy,
            decoration: waInputDecoration('Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _welcome,
            enabled: !_busy,
            minLines: 2,
            maxLines: 5,
            decoration: waInputDecoration(
              'Welcome message',
              helper: 'Sent when a customer writes for the first time.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fallback,
            enabled: !_busy,
            minLines: 2,
            maxLines: 5,
            decoration: waInputDecoration(
              'When nothing matches',
              helper: 'Sent when no keyword rule fits the message.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('AI replies'),
            subtitle: const Text('Let AI answer messages that no rule matches'),
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
              decoration: waInputDecoration(
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
              decoration: waInputDecoration('Follow-up message'),
            ),
          const SizedBox(height: 12),
          SheetNotice(_notice),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? Semantics(
                    label: 'Saving',
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Text('Save settings'),
          ),
        ],
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
    return AppSheet(
      title: _isNew ? 'Add a rule' : 'Edit rule',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _keyword,
            enabled: !_busy,
            decoration: waInputDecoration('Keyword', hint: 'price'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _match,
            isExpanded: true,
            decoration: waInputDecoration('A message matches when it'),
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
              decoration: waInputDecoration('Reply'),
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
            decoration: waInputDecoration(
              'Order',
              helper: 'Lower numbers are checked first.',
            ),
          ),
          const SizedBox(height: 14),
          SheetNotice(_notice),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? Semantics(
                    label: 'Saving',
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
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
    );
  }
}
