import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/gbp_models.dart';
import '../services/api_service.dart';
import '../services/gbp_service.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';
import '../widgets/health_card.dart';

/// Audit (health score), One-Click Optimize and the marketing assistant.
class AiToolsScreen extends StatefulWidget {
  const AiToolsScreen({super.key});

  @override
  State<AiToolsScreen> createState() => _AiToolsScreenState();
}

class _AiToolsScreenState extends State<AiToolsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.fact_check_rounded),
                    label: Text('Audit'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.rocket_launch_rounded),
                    label: Text('Optimize'),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.chat_rounded),
                    label: Text('Assistant'),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [_AuditTab(), _OptimizeTab(), _AssistantTab()],
            ),
          ),
        ],
      ),
    );
  }
}

Color _priorityColor(String priority) {
  switch (priority) {
    case 'critical':
      return bad;
    case 'high':
      return warn;
    case 'medium':
      return brand;
    default:
      return muted;
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, this.index});

  final HealthAction action;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(action.priority);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: action.icon.isNotEmpty
                ? Text(action.icon, style: const TextStyle(fontSize: 18))
                : Text(
                    '${(index ?? 0) + 1}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    height: 1.35,
                  ),
                ),
                if (action.why.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    action.why,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              action.priority.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 44, color: muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Audit

class _AuditTab extends StatefulWidget {
  const _AuditTab();

  @override
  State<_AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<_AuditTab> {
  GbpHealth? _health;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final h = await GbpService.health();
      if (!mounted) return;
      setState(() {
        _health = h;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _health;
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: _loading && h == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_error != null && h == null)
                  _Failure(message: _error!, onRetry: _load)
                else if (h != null) ...[
                  FadeIn(child: HealthCard(health: h)),
                  if (h.actions.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
                      child: Text(
                        'Fix these first',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                    ),
                    for (var i = 0; i < h.actions.length; i++)
                      FadeIn(
                        delay: 120 + i * 70,
                        child: _ActionTile(action: h.actions[i], index: i),
                      ),
                  ],
                ],
              ],
            ),
    );
  }
}

// ------------------------------------------------------------- Optimize

class _OptimizeTab extends StatefulWidget {
  const _OptimizeTab();

  @override
  State<_OptimizeTab> createState() => _OptimizeTabState();
}

class _OptimizeTabState extends State<_OptimizeTab> {
  OptimizeResult? _result;
  bool _running = false;
  String? _error;

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final r = await GbpService.optimize();
      if (!mounted) return;
      setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [royalIndigo, royalViolet]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: royalGold.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rocket_launch_rounded, color: royalGold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'One-Click Optimize',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'The AI studies your profile score and gives a prioritized plan '
                'built for your business. It uses AI credits.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _running ? null : _run,
                style: FilledButton.styleFrom(
                  backgroundColor: royalGold,
                  foregroundColor: royalNavy,
                ),
                icon: _running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: royalNavy,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  _running
                      ? 'Analyzing your profile...'
                      : (r == null ? 'Run optimization' : 'Run again'),
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              _error!,
              style: GoogleFonts.plusJakartaSans(color: bad, fontSize: 13),
            ),
          ),
        if (r != null) ...[
          const SizedBox(height: 16),
          FadeIn(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Summary',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (r.isAi ? good : muted).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          r.isAi ? 'AI PLAN' : 'STANDARD PLAN',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: r.isAi ? good : muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    r.summary,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      height: 1.45,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Credits left: ${r.credits}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < r.actions.length; i++)
            FadeIn(
              delay: 100 + i * 70,
              child: _ActionTile(action: r.actions[i], index: i),
            ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------ Assistant

class _ChatMessage {
  _ChatMessage(this.text, {required this.fromUser, this.isError = false});

  final String text;
  final bool fromUser;
  final bool isError;
}

class _AssistantTab extends StatefulWidget {
  const _AssistantTab();

  @override
  State<_AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends State<_AssistantTab> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      'Hi, I am Eydia AI. Ask me how to get more Google reviews, write better '
      'posts or improve your local ranking.',
      fromUser: false,
    ),
  ];
  bool _sending = false;
  int? _credits;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(text, fromUser: true));
      _sending = true;
    });
    _scrollToEnd();
    try {
      final res = await GbpService.assistantChat(text);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(res.text, fromUser: false));
        _credits = res.credits;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(friendlyException(e).message, fromUser: false, isError: true),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _messages.length) {
                return const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return _Bubble(message: _messages[i]);
            },
          ),
        ),
        if (_credits != null)
          Text(
            'Credits left: $_credits',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                        null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Ask anything about your business...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.fromUser;
    final bg = user
        ? brand
        : (message.isError ? bad.withValues(alpha: 0.1) : Colors.white);
    final fg = user ? Colors.white : (message.isError ? bad : ink);

    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(user ? 18 : 4),
            bottomRight: Radius.circular(user ? 4 : 18),
          ),
        ),
        child: SelectableText(
          message.text,
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, height: 1.4, color: fg),
        ),
      ),
    );
  }
}
