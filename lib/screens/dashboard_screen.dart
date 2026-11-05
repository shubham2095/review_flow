import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/gbp_models.dart';
import '../services/api_service.dart';
import '../services/gbp_service.dart';
import '../services/location_store.dart';
import '../services/session.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';
import '../widgets/health_card.dart';
import '../widgets/health_ring.dart';
import 'pages.dart';

/// Overview: business health, review stats, what to do next, locations and
/// recent reviews, all from GET /gbp/overview.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<GbpOverview> _future;
  bool _syncing = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  GbpConnection? _connection;

  Future<GbpOverview> _load() async {
    // The connection call is a bonus (Google account, reconnect prompt): a
    // failure there must never blank the dashboard.
    final connection = GbpService.connection().then<GbpConnection?>(
      (c) => c,
      onError: (Object _) => null,
    );
    final data = await GbpService.overview();
    _connection = await connection;
    await LocationStore.setLocations(data.locations);
    return data;
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // The error is shown by the FutureBuilder.
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _connect() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      final status = await GbpService.connectGoogle();
      switch (status) {
        case GbpConnectStatus.success:
          _snack('Google connected');
          await _sync(afterConnect: true);
        case GbpConnectStatus.cancelled:
          _snack('Google connection was cancelled.');
        case GbpConnectStatus.invalidState:
          _snack('The connection link expired. Please try again.');
        case GbpConnectStatus.tokenFailed:
          _snack('Google did not accept the connection. Please try again.');
      }
    } catch (e) {
      _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _sync({bool afterConnect = false}) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final res = await GbpService.sync();
      if (!afterConnect || res.message.isNotEmpty) {
        _snack(
          res.message.isNotEmpty
              ? res.message
              : 'Synced ${res.reviews} reviews from ${res.locations} locations.',
        );
      }
      await _refresh();
    } catch (e) {
      _snack(friendlyException(e).message);
      await _refresh();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _runAction(HealthAction a) {
    switch (a.cta) {
      case 'Connect Google':
        _connect();
      case 'Add Location':
        _sync();
      case 'View Negative' || 'Open Reviews':
        widget.onNavigate(kPageReviews);
      case 'Optimize':
        widget.onNavigate(kPageAiTools);
      case 'Upload Photos' || 'Create Post':
        widget.onNavigate(kPagePosts);
      default:
        widget.onNavigate(
          a.module == 'Reviews' ? kPageReviews : kPageOverview,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: surface,
        body: RefreshIndicator(
          color: brand,
          onRefresh: _refresh,
          child: FutureBuilder<GbpOverview>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _DashboardSkeleton();
              }
              if (snapshot.hasError) {
                return _ErrorView(
                  message: friendlyException(snapshot.error!).message,
                  onRetry: _refresh,
                );
              }
              return _DashboardBody(
                data: snapshot.requireData,
                connection: _connection,
                syncing: _syncing,
                connecting: _connecting,
                onSync: _sync,
                onConnect: _connect,
                onAction: _runAction,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 44, color: muted),
                  const SizedBox(height: 10),
                  Text(
                    'Could not load your dashboard',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onRetry, child: const Text('Try again')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shimmering placeholder shaped like the real layout, so the page does not
/// jump once data arrives.
class _DashboardSkeleton extends StatefulWidget {
  const _DashboardSkeleton();

  @override
  State<_DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<_DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  ).drive(Tween(begin: 0.3, end: 0.75));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _box({required double height, double radius = 14}) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Container(
        height: height,
        decoration: BoxDecoration(
          color: muted.withValues(alpha: _opacity.value * 0.25),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _box(height: 150, radius: 30),
        const SizedBox(height: 16),
        _box(height: 300, radius: 24),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _box(height: 112, radius: 20)),
            const SizedBox(width: 12),
            Expanded(child: _box(height: 112, radius: 20)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _box(height: 112, radius: 20)),
            const SizedBox(width: 12),
            Expanded(child: _box(height: 112, radius: 20)),
          ],
        ),
      ],
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.connection,
    required this.syncing,
    required this.connecting,
    required this.onSync,
    required this.onConnect,
    required this.onAction,
  });

  final GbpOverview data;
  final GbpConnection? connection;
  final bool syncing;
  final bool connecting;
  final VoidCallback onSync;
  final VoidCallback onConnect;
  final ValueChanged<HealthAction> onAction;

  @override
  Widget build(BuildContext context) {
    final needsReconnect = connection?.needsReconnect ?? false;
    final connected = (connection?.connected ?? data.googleConnected) && !needsReconnect;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        FadeIn(child: _Header(data: data, connection: connection)),
        const SizedBox(height: 16),
        if (needsReconnect)
          FadeIn(
            delay: 80,
            child: _SetupCard(
              icon: Icons.sync_problem_rounded,
              title: 'Reconnect your Google account',
              text: (connection?.lastError ?? '').isNotEmpty
                  ? 'Google stopped accepting the connection: ${connection!.lastError}'
                  : 'Google no longer accepts the saved connection. Reconnect to keep reviews and posts working.',
              button: 'Reconnect Google',
              busy: connecting,
              onTap: onConnect,
            ),
          )
        else if (!connected)
          FadeIn(
            delay: 80,
            child: _SetupCard(
              icon: Icons.link_rounded,
              title: 'Connect your Google Business Profile',
              text:
                  'Connect Google to bring in your locations, reviews and insights.',
              button: 'Connect Google',
              busy: connecting,
              onTap: onConnect,
            ),
          )
        else if (data.locations.isEmpty)
          FadeIn(
            delay: 80,
            child: _SetupCard(
              icon: Icons.place_rounded,
              title: 'Import your locations',
              text:
                  'Sync to bring your business locations and reviews from Google.',
              button: 'Import from Google',
              busy: syncing,
              onTap: onSync,
            ),
          ),
        if (needsReconnect || !connected || data.locations.isEmpty)
          const SizedBox(height: 16),
        FadeIn(delay: 120, child: HealthCard(health: data.health)),
        const SizedBox(height: 20),
        FadeIn(delay: 220, child: _StatsGrid(data: data)),
        if (data.totalReviews > 0) ...[
          const SizedBox(height: 16),
          FadeIn(delay: 280, child: _RatingBars(data: data)),
        ],
        if (connected) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: syncing ? null : onSync,
            icon: syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: brand),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(syncing ? 'Syncing from Google...' : 'Sync from Google now'),
            style: OutlinedButton.styleFrom(
              foregroundColor: brand,
              minimumSize: const Size.fromHeight(46),
              side: const BorderSide(color: brand, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
        if (data.health.actions.isNotEmpty) ...[
          const _SectionTitle("Today's actions"),
          for (var i = 0; i < data.health.actions.length; i++)
            FadeIn(
              delay: 300 + i * 80,
              child: _ActionCard(
                action: data.health.actions[i],
                onTap: () => onAction(data.health.actions[i]),
              ),
            ),
        ],
        if (data.locations.isNotEmpty) ...[
          const _SectionTitle('Locations'),
          FadeIn(
            delay: 400,
            child: SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: data.locations.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) =>
                    _LocationCard(loc: data.locations[i], index: i),
              ),
            ),
          ),
        ],
        if (data.recentReviews.isNotEmpty) ...[
          const _SectionTitle('Recent reviews'),
          for (var i = 0; i < data.recentReviews.length; i++)
            FadeIn(
              delay: 480 + i * 70,
              child: _ReviewCard(review: data.recentReviews[i]),
            ),
        ],
      ],
    );
  }
}

String _ago(DateTime? t) {
  if (t == null) return 'Not synced yet';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Synced just now';
  if (d.inMinutes < 60) return 'Synced ${d.inMinutes} min ago';
  if (d.inHours < 24) return 'Synced ${d.inHours} h ago';
  return 'Synced ${d.inDays} d ago';
}

class _Header extends StatelessWidget {
  const _Header({required this.data, required this.connection});

  final GbpOverview data;
  final GbpConnection? connection;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _date {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = Session.current?.name.trim() ?? '';
    final first = name.isEmpty ? '' : name.split(' ').first;
    final count = data.locations.length;
    final needsReconnect = connection?.needsReconnect ?? false;
    final connected = (connection?.connected ?? data.googleConnected) && !needsReconnect;
    final email = connection?.googleEmail ?? '';

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [brand, brandDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _date.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 11,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              first.isEmpty ? _greeting : '$_greeting, $first',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeaderChip(
                  icon: connected
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  text: needsReconnect
                      ? 'Reconnect needed'
                      : (connected
                          ? (email.isEmpty ? 'Google connected' : email)
                          : 'Google not connected'),
                ),
                _HeaderChip(
                  icon: Icons.place_rounded,
                  text: '$count ${count == 1 ? 'location' : 'locations'}',
                ),
                if (connected)
                  _HeaderChip(
                    icon: Icons.schedule_rounded,
                    text: _ago(data.lastSyncedAt),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.button,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final String button;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: royalGold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: busy ? null : onTap,
            style: FilledButton.styleFrom(
              backgroundColor: royalGold,
              foregroundColor: royalNavy,
            ),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: royalNavy,
                    ),
                  )
                : Text(button),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.data});

  final GbpOverview data;

  @override
  Widget build(BuildContext context) {
    final items = [
      _Stat(Icons.reviews_rounded, 'Total reviews', data.totalReviews.toDouble(), 0, brand),
      _Stat(Icons.star_rounded, 'Avg rating', data.averageRating, 1, star),
      _Stat(Icons.check_circle_rounded, 'Replied', data.replied.toDouble(), 0, good),
      _Stat(Icons.hourglass_bottom_rounded, 'Unreplied', data.unreplied.toDouble(), 0, bad),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      mainAxisExtent: 112,
      children: [for (final s in items) _StatCard(stat: s)],
    );
  }
}

class _Stat {
  _Stat(this.icon, this.label, this.value, this.decimals, this.color);

  final IconData icon;
  final String label;
  final double value;
  final int decimals;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: stat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(stat.icon, size: 16, color: stat.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stat.label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: stat.value),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Text(
                stat.decimals > 0
                    ? v.toStringAsFixed(stat.decimals)
                    : v.round().toString(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBars extends StatelessWidget {
  const _RatingBars({required this.data});

  final GbpOverview data;

  @override
  Widget build(BuildContext context) {
    final total = data.totalReviews == 0 ? 1 : data.totalReviews;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rating breakdown',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 12),
          for (var s = 5; s >= 1; s--)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '$s',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ),
                  const Icon(Icons.star_rounded, size: 14, color: star),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (data.ratingDistribution[s] ?? 0) / total,
                        minHeight: 8,
                        color: s >= 4 ? good : (s == 3 ? star : bad),
                        backgroundColor: const Color(0xFFEEF1F7),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${data.ratingDistribution[s] ?? 0}',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 4, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [brand, brandDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.onTap});

  final HealthAction action;
  final VoidCallback onTap;

  Color get _color {
    switch (action.priority) {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: cardDecoration(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(action.icon, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        action.why,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                      if (action.cta.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${action.cta} >',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: brand,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    action.priority.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.loc, required this.index});

  final GbpLocation loc;
  final int index;

  @override
  Widget build(BuildContext context) {
    const gradients = [
      [Color(0xFF4C6FFF), Color(0xFF7C5CFF)],
      [Color(0xFFF97316), Color(0xFFF59E0B)],
      [Color(0xFF22C55E), Color(0xFF14B8A6)],
      [Color(0xFFEC4899), Color(0xFF8B5CF6)],
    ];
    final g = gradients[index % gradients.length];

    return Container(
      width: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: g,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: g.first.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loc.address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11),
          ),
          const Spacer(),
          Row(
            children: [
              _Pill(icon: Icons.star_rounded, text: loc.rating.toStringAsFixed(1)),
              const SizedBox(width: 6),
              _Pill(icon: Icons.chat_bubble_rounded, text: '${loc.reviewCount}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final GbpReview review;

  @override
  Widget build(BuildContext context) {
    final initial = review.authorName.isEmpty
        ? '?'
        : review.authorName[0].toUpperCase();
    final avatarColor = healthColor(review.rating * 20);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: avatarColor.withValues(alpha: 0.15),
            child: Text(
              initial,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: avatarColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                    for (var i = 0; i < 5; i++)
                      Icon(
                        i < review.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 16,
                        color: star,
                      ),
                  ],
                ),
                if ((review.comment ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    review.comment!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    if ((review.locationName ?? '').isNotEmpty)
                      Expanded(
                        child: Text(
                          review.locationName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: brand,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Text(
                      review.hasReply ? 'Replied' : 'Needs reply',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: review.hasReply ? good : warn,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
