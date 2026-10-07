import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/review_models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';

class LocationReviewsScreen extends StatefulWidget {
  const LocationReviewsScreen({
    super.key,
    required this.location,
    required this.onSignedOut,
  });

  final LocationSummary location;
  final VoidCallback onSignedOut;

  @override
  State<LocationReviewsScreen> createState() => _LocationReviewsScreenState();
}

class _LocationReviewsScreenState extends State<LocationReviewsScreen> {
  final List<ReviewItem> _reviews = [];
  ReviewStats? _stats;
  String _filter = 'all';
  int _currentPage = 0;
  int _lastPage = 1;
  bool _loading = false;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPage(reset: true);
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_loading) return;
    final nextPage = reset ? 1 : _currentPage + 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await ApiService.instance.get(
        '/reviews/${widget.location.id}?filter=$_filter&page=$nextPage',
      );
      final page = LocationReviewsPage.fromJson(json);
      if (!mounted) return;
      setState(() {
        if (reset) _reviews.clear();
        _reviews.addAll(page.reviews);
        _stats = page.stats;
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthService.logout();
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        widget.onSignedOut();
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setFilter(String f) {
    if (f == _filter) return;
    setState(() => _filter = f);
    _loadPage(reset: true);
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final res = await ApiService.instance.post(
        '/reviews/${widget.location.id}/sync',
      );
      final synced = res['synced'] ?? 0;
      _snack(res['message']?.toString() ?? '$synced reviews synced ✅');
      await _loadPage(reset: true);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _openReply(ReviewItem review) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ReplySheet(review: review),
    );
    if (result == 'sent') {
      _snack('Reply sent to Google ✅');
    } else if (result == 'saved') {
      _snack('Reply saved (not posted to Google)');
    }
    if (result != null) _loadPage(reset: true);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: brand,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [brand, brandDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 1.2,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      royalGold.withValues(alpha: 0),
                      royalGold.withValues(alpha: 0.9),
                      royalGold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          title: Text(
            widget.location.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          actions: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: _syncing
                  ? const Padding(
                      key: ValueKey('syncing'),
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : IconButton(
                      key: const ValueKey('idle'),
                      tooltip: 'Sync with Google',
                      icon: const Icon(Icons.sync_rounded),
                      onPressed: _sync,
                    ),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: brand,
          onRefresh: () => _loadPage(reset: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (_stats != null) FadeIn(child: _StatsStrip(stats: _stats!)),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'unreplied', label: Text('Unreplied')),
                  ButtonSegment(value: 'negative', label: Text('Negative')),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => _setFilter(s.first),
              ),
              const SizedBox(height: 14),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('😕 $_error', style: const TextStyle(color: bad)),
                ),
              if (_reviews.isEmpty && !_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('📭  No reviews for this filter')),
                ),
              for (var i = 0; i < _reviews.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FadeIn(
                    delay: i < 12 ? i * 60 : 0,
                    child: _ReviewCard(
                      review: _reviews[i],
                      onReply: () => _openReply(_reviews[i]),
                    ),
                  ),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_loading && _currentPage < _lastPage)
                Center(
                  child: OutlinedButton(
                    onPressed: () => _loadPage(),
                    child: const Text('Load more reviews'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats});

  final ReviewStats stats;

  @override
  Widget build(BuildContext context) {
    Widget item(
      String emoji,
      double value,
      int decimals,
      String label,
      Color color,
    ) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Text(
                    decimals > 0
                        ? v.toStringAsFixed(decimals)
                        : v.round().toString(),
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 10, color: muted),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        item('💬', stats.total.toDouble(), 0, 'Total', brand),
        const SizedBox(width: 8),
        item('⭐', stats.avg, 1, 'Avg', star),
        const SizedBox(width: 8),
        item(
          '⏳',
          stats.unreplied.toDouble(),
          0,
          'Unreplied',
          stats.unreplied > 0 ? warn : good,
        ),
        const SizedBox(width: 8),
        item(
          '👎',
          stats.negative.toDouble(),
          0,
          'Negative',
          stats.negative > 0 ? bad : good,
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onReply});

  final ReviewItem review;
  final VoidCallback onReply;

  Color get _sentimentColor {
    switch (review.sentiment) {
      case 'POSITIVE':
        return good;
      case 'NEGATIVE':
        return bad;
      default:
        return muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = review.reviewerName.isEmpty
        ? '?'
        : review.reviewerName[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: brand.withValues(alpha: 0.12),
                child: Text(
                  initial,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: brand,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    Text(
                      review.dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < 5; i++)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 260 + i * 90),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Icon(
                    i < review.starRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: star,
                  ),
                ),
            ],
          ),
          if ((review.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: ink,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (review.replied)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: good.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '💬 Your reply: ${review.replied ? review.replyText : ''}',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ink),
              ),
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _sentimentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    (review.sentiment ?? 'NEUTRAL').toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _sentimentColor,
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply_rounded, size: 18),
                  label: const Text('Reply'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ReplySheet extends StatefulWidget {
  const _ReplySheet({required this.review});

  final ReviewItem review;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _draft() async {
    setState(() => _busy = true);
    try {
      final res = await ApiService.instance.post(
        '/reviews/${widget.review.id}/generate',
        timeout: kAiTimeout,
      );
      _controller.text = (res['reply'] ?? '').toString();
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _message('Reply cannot be empty');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ApiService.instance.post(
        '/reviews/${widget.review.id}/reply',
        body: {'reply_text': text},
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(res['posted_to_google'] == true ? 'sent' : 'saved');
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          const SizedBox(height: 16),
          Text(
            '↩️ Reply to ${widget.review.reviewerName}',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: ink,
            ),
          ),
          if ((widget.review.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"${widget.review.comment}"',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLines: 5,
            minLines: 3,
            decoration: InputDecoration(
              hintText: 'Write your reply or use an AI draft…',
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _draft,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('AI draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _send,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
