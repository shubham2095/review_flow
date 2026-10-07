import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/dashboard_data.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';
import '../widgets/health_ring.dart';

const _brand = Color(0xFF4C6FFF);
const _brandDeep = Color(0xFF7C5CFF);
const _ink = Color(0xFF1B2437);
const _muted = Color(0xFF7A8599);

typedef _Payload = ({DashboardData data, String name});

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_Payload> _future;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Payload> _load() async {
    try {
      final results = await Future.wait([
        ApiService.instance.get('/dashboard'),
        ApiService.instance.get('/me'),
      ]);
      return (
        data: DashboardData.fromJson(results[0]),
        name: (results[1]['name'] ?? '').toString(),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthService.logout();
        widget.onSignedOut();
      }
      rethrow;
    }
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // Error FutureBuilder mein dikhega.
    }
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final res = await ApiService.instance.post('/dashboard/sync');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synced ${res['synced'] ?? 0} reviews ✅')),
      );
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyException(e).message)));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Status bar brand color ka rahega, taaki header ke saath seamless lage.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: RefreshIndicator(
          color: _brand,
          onRefresh: _refresh,
          child: FutureBuilder<_Payload>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _DashboardSkeleton();
              }
              if (snapshot.hasError) {
                return _CenteredList(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('😕', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(
                          'Could not load your dashboard',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: _ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          friendlyException(snapshot.error!).message,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _muted),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _refresh,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final payload = snapshot.requireData;
              return _DashboardBody(
                data: payload.data,
                name: payload.name,
                syncing: _syncing,
                onSync: _sync,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CenteredList extends StatelessWidget {
  const _CenteredList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Center(child: child),
        ),
      ],
    );
  }
}

/// Shimmering placeholder shown while the first load is in flight, shaped
/// like the real layout so the page doesn't "jump" once data arrives.
class _DashboardSkeleton extends StatefulWidget {
  const _DashboardSkeleton();

  @override
  State<_DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<_DashboardSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut).drive(Tween(begin: 0.3, end: 0.75));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _box({double? width, required double height, double radius = 14}) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _muted.withValues(alpha: _opacity.value * 0.25),
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
        _box(height: 170, radius: 30),
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
    required this.name,
    required this.syncing,
    required this.onSync,
  });

  final DashboardData data;
  final String name;
  final bool syncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        _FadeIn(delay: 0, child: _Header(name: name, data: data)),
        const SizedBox(height: 16),
        _FadeIn(
          delay: 120,
          child: _HealthCard(overall: data.overall, subScores: data.subScores),
        ),
        const SizedBox(height: 20),
        _FadeIn(delay: 220, child: _StatsRow(data: data)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: syncing ? null : onSync,
          icon: syncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
                )
              : const Icon(Icons.sync_rounded),
          label: Text(syncing ? 'Syncing reviews…' : 'Sync reviews now'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _brand,
            minimumSize: const Size.fromHeight(46),
            side: const BorderSide(color: _brand, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
        ),
        if (data.doNext.isNotEmpty) ...[
          const _SectionTitle(emoji: '✅', text: "Today's actions"),
          for (var i = 0; i < data.doNext.length; i++)
            _FadeIn(
              delay: 300 + i * 90,
              child: _DoNextCard(item: data.doNext[i]),
            ),
        ],
        if (data.locations.isNotEmpty) ...[
          const _SectionTitle(emoji: '📍', text: 'Locations'),
          _FadeIn(
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
          const _SectionTitle(emoji: '💬', text: 'Recent reviews'),
          for (var i = 0; i < data.recentReviews.length; i++)
            _FadeIn(
              delay: 480 + i * 80,
              child: _ReviewCard(review: data.recentReviews[i]),
            ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.data});

  final String name;
  final DashboardData data;

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
    final firstName = name.trim().split(' ').first;
    final locCount = data.locations.length;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_brand, _brandDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: _FloatingBubble(size: 160, alpha: 0.08, duration: 4200),
            ),
            Positioned(
              right: 30,
              bottom: -60,
              child: _FloatingBubble(size: 120, alpha: 0.06, duration: 3400),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
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
                  firstName.isEmpty
                      ? '$_greeting 👋'
                      : '$_greeting, $firstName 👋',
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
                      icon: data.hasGoogle ? '🔗' : '⚠️',
                      text: data.hasGoogle
                          ? 'Google connected'
                          : 'Google not connected',
                    ),
                    _HeaderChip(
                      icon: '📍',
                      text: '$locCount ${locCount == 1 ? 'location' : 'locations'}',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

/// Slow, ambient up-down drift for the header's decorative bubbles. Purely
/// visual (Transform.translate), so it never affects layout size.
class _FloatingBubble extends StatefulWidget {
  const _FloatingBubble({required this.size, required this.alpha, required this.duration});

  final double size;
  final double alpha;
  final int duration;

  @override
  State<_FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<_FloatingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: Duration(milliseconds: widget.duration))..repeat(reverse: true);
  late final Animation<double> _dy =
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut).drive(Tween(begin: -8, end: 8));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dy,
      builder: (_, child) => Transform.translate(offset: Offset(0, _dy.value), child: child),
      child: _Bubble(size: widget.size, alpha: widget.alpha),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.text});

  final String icon;
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
      child: Text(
        '$icon  $text',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.overall, required this.subScores});

  final int overall;
  final List<SubScore> subScores;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Text(
            'Business Health',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 16),
          _GlowPulse(color: healthColor(overall), child: HealthRing(score: overall)),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              for (var i = 0; i < subScores.length; i++)
                _SubScoreTile(score: subScores[i], index: i),
            ],
          ),
        ],
      ),
    );
  }
}

/// Soft breathing glow behind the health ring. Decorative box-shadow only,
/// so it never changes the ring's size or the card's layout.
class _GlowPulse extends StatefulWidget {
  const _GlowPulse({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  State<_GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<_GlowPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  late final Animation<double> _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (_, child) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.12 + _t.value * 0.14),
              blurRadius: 24 + _t.value * 20,
              spreadRadius: _t.value * 4,
            ),
          ],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _SubScoreTile extends StatelessWidget {
  const _SubScoreTile({required this.score, required this.index});

  final SubScore score;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: score.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: score.color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(score.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  score.label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score.score.toDouble()),
                duration: Duration(milliseconds: 900 + index * 80),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text(
                  '${v.round()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: score.color,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score.score / 100),
              duration: Duration(milliseconds: 900 + index * 80),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                color: score.color,
                backgroundColor: score.color.withValues(alpha: 0.15),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            score.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _muted),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatData('⭐', 'Total reviews', data.totalReviews.toDouble(), 0, const Color(0xFF4C6FFF)),
      _StatData('⭐', 'Avg rating', data.avgRating, 1, const Color(0xFFF59E0B)),
      _StatData('✅', 'Replied', data.replied.toDouble(), 0, const Color(0xFF22C55E)),
      _StatData('⏳', 'Unreplied', data.unreplied.toDouble(), 0, const Color(0xFFEF4444)),
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

class _StatData {
  _StatData(this.emoji, this.label, this.value, this.decimals, this.color);

  final String emoji;
  final String label;
  final double value;
  final int decimals;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _StatData stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
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
                child: Text(stat.emoji, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stat.label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _muted),
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
                  color: _ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.emoji, required this.text});

  final String emoji;
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
                colors: [_brand, _brandDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$emoji  $text',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoNextCard extends StatelessWidget {
  const _DoNextCard({required this.item});

  final DoNextItem item;

  Color get _impactColor {
    switch (item.impact) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF97316);
      case 'medium':
        return const Color(0xFF4C6FFF);
      default:
        return _muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _impactColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(item.icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.why,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _impactColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              item.impact.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _impactColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.loc, required this.index});

  final LocationItem loc;
  final int index;

  @override
  Widget build(BuildContext context) {
    final gradients = [
      [const Color(0xFF4C6FFF), const Color(0xFF7C5CFF)],
      [const Color(0xFFF97316), const Color(0xFFF59E0B)],
      [const Color(0xFF22C55E), const Color(0xFF14B8A6)],
      [const Color(0xFFEC4899), const Color(0xFF8B5CF6)],
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
            loc.title,
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
              _Pill(text: '⭐ ${loc.avgRating.toStringAsFixed(1)}'),
              const SizedBox(width: 6),
              _Pill(text: '💬 ${loc.totalReviews}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final RecentReview review;

  @override
  Widget build(BuildContext context) {
    final initial = review.reviewerName.isEmpty
        ? '💬'
        : review.reviewerName[0].toUpperCase();
    final avatarColor = healthColor(review.starRating * 20);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
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
                        review.reviewerName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                    for (var i = 0; i < 5; i++)
                      Icon(
                        i < review.starRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 16,
                        color: const Color(0xFFF59E0B),
                      ),
                  ],
                ),
                if (review.comment != null && review.comment!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    review.comment!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _muted),
                  ),
                ],
                if (review.locationTitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '📍 ${review.locationTitle}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _brand),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child, required this.delay});

  final Widget child;
  final int delay;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _show ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: _show ? 1 : 0.96,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() => cardDecoration();
