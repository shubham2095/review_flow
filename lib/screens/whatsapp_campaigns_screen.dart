import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';
import '../widgets/offline_banner.dart';
import '../widgets/pressable.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/wa_tab_scope.dart';
import 'whatsapp_bulk_create_screen.dart';
import 'whatsapp_bulk_detail_screen.dart';
import 'whatsapp_campaign_create_screen.dart';
import 'whatsapp_campaign_detail_screen.dart';

/// Colour and label for a campaign status.
({Color color, String label}) campaignStatus(String status) {
  switch (status) {
    case 'running':
      return (color: brand, label: 'Sending');
    case 'scheduled':
      return (color: royalViolet, label: 'Scheduled');
    case 'paused':
      return (color: warn, label: 'Paused');
    case 'completed':
      return (color: good, label: 'Done');
    case 'cancelled':
      return (color: muted, label: 'Cancelled');
    case 'draft':
      return (color: muted, label: 'Draft');
    default:
      return (
        color: muted,
        label: status.isEmpty
            ? 'Unknown'
            : status[0].toUpperCase() + status.substring(1),
      );
  }
}

/// Campaigns (a template to your contacts) and bulk sends (a template to a
/// list of numbers) in two tabs.
class WhatsAppCampaignsScreen extends StatefulWidget {
  const WhatsAppCampaignsScreen({super.key, this.embedded = false});

  /// Inside the WhatsApp tabs: no AppBar (the shell has the top bar) and no
  /// second offline banner; the two inner tabs sit at the top of the page.
  final bool embedded;

  @override
  State<WhatsAppCampaignsScreen> createState() =>
      _WhatsAppCampaignsScreenState();
}

class _WhatsAppCampaignsScreenState extends State<WhatsAppCampaignsScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));
  final _campaignsKey = GlobalKey<_CampaignsTabState>();
  final _bulkKey = GlobalKey<_BulkTabState>();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _newCampaign() async {
    final created = await Navigator.of(context).push<WaCampaign>(
      MaterialPageRoute(builder: (_) => const WhatsAppCampaignCreateScreen()),
    );
    if (created == null || !mounted) return;
    await _campaignsKey.currentState?.reload();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WhatsAppCampaignDetailScreen(campaignId: created.id),
      ),
    );
    _campaignsKey.currentState?.reload();
  }

  Future<void> _newBulk() async {
    final created = await Navigator.of(context).push<WaBulkSend>(
      MaterialPageRoute(builder: (_) => const WhatsAppBulkCreateScreen()),
    );
    if (created == null || !mounted) return;
    await _bulkKey.currentState?.reload();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WhatsAppBulkDetailScreen(bulkId: created.id),
      ),
    );
    _bulkKey.currentState?.reload();
  }

  TabBar _tabBar() => TabBar(
    controller: _tabs,
    labelColor: brand,
    indicatorColor: brand,
    tabs: const [
      Tab(text: 'Campaigns'),
      Tab(text: 'Bulk sends'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final onCampaigns = _tabs.index == 0;
    return Scaffold(
      backgroundColor: surface,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                'Campaigns',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              foregroundColor: ink,
              bottom: _tabBar(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCampaigns ? _newCampaign : _newBulk,
        icon: const Icon(Icons.add_rounded),
        label: Text(onCampaigns ? 'New campaign' : 'New bulk send'),
      ),
      body: Column(
        children: [
          if (!widget.embedded) const OfflineBanner(),
          if (widget.embedded) Material(color: Colors.white, child: _tabBar()),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _CampaignsTab(key: _campaignsKey),
                _BulkTab(key: _bulkKey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CampaignsTab extends StatefulWidget {
  const _CampaignsTab({super.key});

  @override
  State<_CampaignsTab> createState() => _CampaignsTabState();
}

class _CampaignsTabState extends State<_CampaignsTab>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  Timer? _poll;
  List<WaCampaign> _items = [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  /// False while the whole Campaigns tab is hidden behind another WhatsApp tab:
  /// no polling then, and one catch-up refresh when it is shown again.
  bool _active = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nowActive = WaTabScope.isActive(context);
    final becameVisible = nowActive && !_active;
    _active = nowActive;
    if (becameVisible) _silent(force: true);
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    reload();
    // Running campaigns move on their own: keep their numbers fresh.
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _silent());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final res = await WhatsAppService.campaigns();
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

  /// [force] refreshes even when nothing is running (the catch-up on return).
  Future<void> _silent({bool force = false}) async {
    if (!mounted || !_active || _loading || _loadingMore || _page > 1) return;
    if (!force && !_items.any((c) => c.isRunning)) return;
    try {
      final res = await WhatsAppService.campaigns();
      if (mounted && _page == 1) {
        setState(() {
          _items = res.items;
          _hasMore = res.hasMore;
        });
      }
    } catch (_) {
      // Keep what is on screen.
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final res = await WhatsAppService.campaigns(page: _page + 1);
      if (!mounted) return;
      setState(() {
        final have = _items.map((c) => c.id).toSet();
        _items = [..._items, ...res.items.where((c) => !have.contains(c.id))];
        _page = res.page;
        _hasMore = res.hasMore;
      });
    } catch (_) {
      // The next scroll tries again.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(WaCampaign c) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WhatsAppCampaignDetailScreen(campaignId: c.id),
      ),
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final error = _error;
    if (_loading) {
      return const SkeletonList(count: 4, itemHeight: 96, headerHeight: null);
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
                  title: 'Could not load campaigns',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    reload();
                  },
                ),
        ),
      );
    }
    return RefreshIndicator(
      color: brand,
      onRefresh: reload,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                StateView(
                  icon: Icons.campaign_outlined,
                  title: 'No campaigns yet',
                  text:
                      'A campaign sends one approved template to your contacts and shows who got it, read it or replied.',
                ),
              ],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
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
                final c = _items[i];
                return FadeIn(
                  delay: i < 8 ? i * 30 : 0,
                  child: _CampaignTile(campaign: c, onTap: () => _open(c)),
                );
              },
            ),
    );
  }
}

class _CampaignTile extends StatelessWidget {
  const _CampaignTile({required this.campaign, required this.onTap});

  final WaCampaign campaign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final s = campaignStatus(c.status);
    final ratio = c.total == 0 ? 0.0 : (c.done / c.total).clamp(0.0, 1.0);
    return Pressable(
      onTap: onTap,
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
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(s.label, s.color),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              [
                if (c.templateName.isNotEmpty) c.templateName,
                if (c.status == 'scheduled' && c.scheduledAt != null)
                  fmtDateTime(c.scheduledAt!)
                else if (c.createdAt != null)
                  fmtDate(c.createdAt!),
              ].join(' · '),
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
            ),
            if (c.status != 'draft' && c.total > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  color: s.color,
                  backgroundColor: const Color(0xFFEEF1F7),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _Count('${c.total}', 'recipients'),
                if (c.status != 'draft') ...[
                  _Count('${c.delivered}', 'delivered'),
                  _Count('${c.read}', 'read'),
                  if (c.failed > 0) _Count('${c.failed}', 'failed', bad),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BulkTab extends StatefulWidget {
  const _BulkTab({super.key});

  @override
  State<_BulkTab> createState() => _BulkTabState();
}

class _BulkTabState extends State<_BulkTab> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  Timer? _poll;
  List<WaBulkSend> _items = [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  /// False while the whole Campaigns tab is hidden behind another WhatsApp tab:
  /// no polling then, and one catch-up refresh when it is shown again.
  bool _active = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nowActive = WaTabScope.isActive(context);
    final becameVisible = nowActive && !_active;
    _active = nowActive;
    if (becameVisible) _silent(force: true);
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    reload();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _silent());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final res = await WhatsAppService.bulkSends();
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

  /// [force] refreshes even when nothing is sending (the catch-up on return).
  Future<void> _silent({bool force = false}) async {
    if (!mounted || !_active || _loading || _loadingMore || _page > 1) return;
    if (!force && !_items.any((b) => b.processing)) return;
    try {
      final res = await WhatsAppService.bulkSends();
      if (mounted && _page == 1) {
        setState(() {
          _items = res.items;
          _hasMore = res.hasMore;
        });
      }
    } catch (_) {
      // Keep what is on screen.
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final res = await WhatsAppService.bulkSends(page: _page + 1);
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

  Future<void> _open(WaBulkSend b) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => WhatsAppBulkDetailScreen(bulkId: b.id)),
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final error = _error;
    if (_loading) {
      return const SkeletonList(count: 4, itemHeight: 96, headerHeight: null);
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
                  title: 'Could not load bulk sends',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    reload();
                  },
                ),
        ),
      );
    }
    return RefreshIndicator(
      color: brand,
      onRefresh: reload,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                StateView(
                  icon: Icons.send_outlined,
                  title: 'No bulk sends yet',
                  text:
                      'A bulk send sends one template to a list of phone numbers you type or paste.',
                ),
              ],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
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
                final b = _items[i];
                final failed = b.failed;
                final ratio = b.total == 0
                    ? 0.0
                    : (b.done / b.total).clamp(0.0, 1.0);
                return FadeIn(
                  delay: i < 8 ? i * 30 : 0,
                  child: Pressable(
                    onTap: () => _open(b),
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
                                  b.template,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              b.processing
                                  ? const StatusBadge('Sending', brand)
                                  : const StatusBadge('Done', good),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            b.createdAt == null
                                ? ''
                                : fmtDateTime(b.createdAt!),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 6,
                              color: failed > 0 && !b.processing ? warn : brand,
                              backgroundColor: const Color(0xFFEEF1F7),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 14,
                            runSpacing: 4,
                            children: [
                              _Count('${b.total}', 'numbers'),
                              _Count('${b.sent}', 'sent'),
                              _Count('${b.delivered}', 'delivered'),
                              if (failed > 0) _Count('$failed', 'failed', bad),
                            ],
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

// ---------------------------------------------------------------------------

/// Small coloured pill used for statuses in list rows and detail pages.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.text, this.color, {super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.value, this.label, [this.color = ink]);

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: color,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }
}
