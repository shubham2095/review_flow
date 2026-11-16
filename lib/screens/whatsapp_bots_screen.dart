import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';
import '../widgets/offline_banner.dart';
import '../widgets/pressable.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/wa_ui.dart';
import 'whatsapp_chatbot_screen.dart';
import 'whatsapp_workflow_screen.dart';

/// Chatbots (keyword replies and AI) and automations (flows built on the web)
/// in two tabs.
class WhatsAppBotsScreen extends StatefulWidget {
  const WhatsAppBotsScreen({super.key});

  @override
  State<WhatsAppBotsScreen> createState() => _WhatsAppBotsScreenState();
}

class _WhatsAppBotsScreenState extends State<WhatsAppBotsScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));
  final _botsKey = GlobalKey<_BotsTabState>();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onBots = _tabs.index == 0;
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          'Chatbots and automations',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: ink,
            fontSize: 17,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        bottom: TabBar(
          controller: _tabs,
          labelColor: brand,
          indicatorColor: brand,
          tabs: const [
            Tab(text: 'Chatbots'),
            Tab(text: 'Automations'),
          ],
        ),
      ),
      floatingActionButton: onBots
          ? FloatingActionButton.extended(
              onPressed: () => _botsKey.currentState?.create(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New chatbot'),
            )
          : null,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _BotsTab(key: _botsKey),
                const _WorkflowsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BotsTab extends StatefulWidget {
  const _BotsTab({super.key});

  @override
  State<_BotsTab> createState() => _BotsTabState();
}

class _BotsTabState extends State<_BotsTab> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  List<WaChatbot> _items = [];
  WaLeadFlow? _lead;
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _installing = false;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await WhatsAppService.chatbots();
      // The lead funnel card is optional: a failure just hides it.
      WaLeadFlow? lead;
      try {
        lead = await WhatsAppService.leadFlow();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _lead = lead;
        _page = res.page;
        _hasMore = res.hasMore;
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final res = await WhatsAppService.chatbots(page: _page + 1);
      if (!mounted) return;
      setState(() {
        final have = _items.map((b) => b.id).toSet();
        _items = [..._items, ...res.items.where((b) => !have.contains(b.id))];
        _page = res.page;
        _hasMore = res.hasMore;
      });
    } catch (_) {
      // The next scroll tries again.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> create() async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _NewChatbotSheet(),
    );
    if (message == null) return;
    _snack(message);
    _load();
  }

  Future<void> _open(WaChatbot b) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => WhatsAppChatbotScreen(chatbotId: b.id)),
    );
    if (mounted) _load();
  }

  Future<void> _install() async {
    if (_installing) return;
    setState(() => _installing = true);
    try {
      _snack(await WhatsAppService.installLeadFlow());
      await _load();
    } catch (e) {
      _snack(errorLine(e));
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final error = _error;
    if (_loading) {
      return const SkeletonList(count: 4, itemHeight: 90, headerHeight: null);
    }
    if (error != null && _items.isEmpty) {
      final access = accessProblem(error);
      return Center(
        child: SingleChildScrollView(
          child: access != null
              ? StateView(
                  icon: access.icon,
                  title: access.title,
                  text: access.text,
                )
              : StateView.error(
                  title: 'Could not load chatbots',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    }
    final lead = _lead;
    final showLead = lead != null && lead.available;
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: _items.isEmpty && !showLead
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                StateView(
                  icon: Icons.smart_toy_outlined,
                  title: 'No chatbots yet',
                  text:
                      'A chatbot answers customers on its own: by keywords you set, or with AI.',
                ),
              ],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount:
                  _items.length + (showLead ? 1 : 0) + (_loadingMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (showLead && i == 0) {
                  return _LeadFlowCard(
                    flow: lead,
                    busy: _installing,
                    onInstall: _install,
                  );
                }
                final idx = showLead ? i - 1 : i;
                if (idx >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final b = _items[idx];
                return FadeIn(
                  delay: idx < 8 ? idx * 30 : 0,
                  child: Pressable(
                    onTap: () => _open(b),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: cardDecoration(),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: (b.isActive ? good : muted).withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              Icons.smart_toy_rounded,
                              color: b.isActive ? good : muted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    '${b.rulesCount} ${b.rulesCount == 1 ? 'rule' : 'rules'}',
                                    if (b.aiEnabled) 'AI replies',
                                    if (b.numberLabel.isNotEmpty) b.numberLabel,
                                  ].join(' · '),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          b.isActive
                              ? const StatusBadge('On', good)
                              : const StatusBadge('Off', muted),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _LeadFlowCard extends StatelessWidget {
  const _LeadFlowCard({
    required this.flow,
    required this.busy,
    required this.onInstall,
  });

  final WaLeadFlow flow;
  final bool busy;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [royalIndigo, royalViolet]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: royalGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'GBP lead automation',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (flow.installed)
                StatusBadge(flow.active ? 'On' : 'Off', Colors.white),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'A ready-made WhatsApp funnel: welcome, free profile check, then '
            'book a demo or send details.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : onInstall,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: royalIndigo,
            ),
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    flow.installed ? 'Refresh the flow' : 'Install the flow',
                  ),
          ),
        ],
      ),
    );
  }
}

class _NewChatbotSheet extends StatefulWidget {
  const _NewChatbotSheet();

  @override
  State<_NewChatbotSheet> createState() => _NewChatbotSheetState();
}

class _NewChatbotSheetState extends State<_NewChatbotSheet> {
  final _name = TextEditingController();
  final _welcome = TextEditingController();
  final _fallback = TextEditingController();
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _welcome.dispose();
    _fallback.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  );

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      HapticFeedback.lightImpact();
      setState(() => _notice = 'Give the chatbot a name.');
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await WhatsAppService.createChatbot(
        name: _name.text.trim(),
        welcome: _welcome.text.trim(),
        fallback: _fallback.text.trim(),
      );
      if (mounted) {
        Navigator.of(
          context,
        ).pop('Chatbot created. It is off until you turn it on.');
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
              'New chatbot',
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
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Name', hint: 'Shop assistant'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _welcome,
              enabled: !_busy,
              minLines: 2,
              maxLines: 5,
              decoration: _dec(
                'Welcome message (optional)',
                hint: 'Hi! How can we help?',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fallback,
              enabled: !_busy,
              minLines: 2,
              maxLines: 5,
              decoration: _dec(
                'When nothing matches (optional)',
                hint: 'Thanks, a team member will reply soon.',
              ),
            ),
            const SizedBox(height: 14),
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
                  : const Text('Create chatbot'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You add keyword rules next. Nothing is sent to customers until you switch it on.',
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
    );
  }
}

// ---------------------------------------------------------------------------

class _WorkflowsTab extends StatefulWidget {
  const _WorkflowsTab();

  @override
  State<_WorkflowsTab> createState() => _WorkflowsTabState();
}

class _WorkflowsTabState extends State<_WorkflowsTab>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  List<WaWorkflow> _items = [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await WhatsAppService.workflows();
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _page = res.page;
        _hasMore = res.hasMore;
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final res = await WhatsAppService.workflows(page: _page + 1);
      if (!mounted) return;
      setState(() {
        final have = _items.map((w) => w.id).toSet();
        _items = [..._items, ...res.items.where((w) => !have.contains(w.id))];
        _page = res.page;
        _hasMore = res.hasMore;
      });
    } catch (_) {
      // The next scroll tries again.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(WaWorkflow w) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WhatsAppWorkflowScreen(workflowId: w.id),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final error = _error;
    if (_loading) {
      return const SkeletonList(count: 4, itemHeight: 90, headerHeight: null);
    }
    if (error != null && _items.isEmpty) {
      final access = accessProblem(error);
      return Center(
        child: SingleChildScrollView(
          child: access != null
              ? StateView(
                  icon: access.icon,
                  title: access.title,
                  text: access.text,
                )
              : StateView.error(
                  title: 'Could not load automations',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    }
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                StateView(
                  icon: Icons.account_tree_outlined,
                  title: 'No automations yet',
                  text:
                      'Automations are flows such as "when a new contact is added, send a welcome". Build them on the Eydia website; you can switch them on and off here.',
                ),
              ],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _items.length + (_loadingMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final w = _items[i];
                return FadeIn(
                  delay: i < 8 ? i * 30 : 0,
                  child: Pressable(
                    onTap: () => _open(w),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  w.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              workflowBadge(w.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'When: ${w.triggerLabel}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF4A5468),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${w.nodesCount} steps · ran ${w.executionsCount} ${w.executionsCount == 1 ? 'time' : 'times'}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Badge for an automation status.
Widget workflowBadge(String status) {
  switch (status) {
    case 'active':
      return const StatusBadge('On', good);
    case 'paused':
      return const StatusBadge('Paused', warn);
    case 'draft':
      return const StatusBadge('Draft', muted);
    default:
      return StatusBadge(
        status.isEmpty
            ? 'Unknown'
            : status[0].toUpperCase() + status.substring(1),
        muted,
      );
  }
}
