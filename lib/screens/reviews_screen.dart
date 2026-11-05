import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/gbp_models.dart';
import '../services/api_service.dart';
import '../services/gbp_service.dart';
import '../services/location_store.dart';
import '../theme/brand.dart';
import '../widgets/count_up.dart';
import '../widgets/fade_in.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import 'pages.dart';

enum _Filter { all, unreplied, r5, r4, r3, r2, r1 }

int? _ratingOf(_Filter f) {
  switch (f) {
    case _Filter.r5:
      return 5;
    case _Filter.r4:
      return 4;
    case _Filter.r3:
      return 3;
    case _Filter.r2:
      return 2;
    case _Filter.r1:
      return 1;
    default:
      return null;
  }
}

/// Google reviews for the selected location (or all locations): server-side
/// filters, infinite scroll, reply with an optional AI draft, and sync.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _scroll = ScrollController();
  List<GbpReview> _reviews = [];
  PageMeta? _meta;
  int _totalAll = 0;
  int _unreplied = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _syncing = false;
  String? _error;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    LocationStore.selectedId.addListener(_reloadAll);
    _reloadAll();
  }

  @override
  void dispose() {
    _scroll.dispose();
    LocationStore.selectedId.removeListener(_reloadAll);
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<PagedResult<GbpReview>> _fetch(int page) => GbpService.reviewsPage(
        page: page,
        locationId: LocationStore.selectedId.value,
        unreplied: _filter == _Filter.unreplied,
        rating: _ratingOf(_filter),
      );

  /// Reloads the first page and the header counts (location changed, pull to
  /// refresh, sync).
  Future<void> _reloadAll() async {
    if (mounted && _reviews.isEmpty) setState(() => _loading = true);
    final id = LocationStore.selectedId.value;
    try {
      final results = await Future.wait([
        _fetch(1),
        GbpService.reviewsPage(page: 1, perPage: 1, locationId: id),
        GbpService.reviewsPage(page: 1, perPage: 1, locationId: id, unreplied: true),
      ]);
      if (!mounted) return;
      setState(() {
        _reviews = results[0].items;
        _meta = results[0].meta;
        _totalAll = results[1].meta.total;
        _unreplied = results[2].meta.total;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Reloads only the list when the filter changes.
  Future<void> _reloadList() async {
    setState(() => _loading = true);
    try {
      final r = await _fetch(1);
      if (!mounted) return;
      setState(() {
        _reviews = r.items;
        _meta = r.meta;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final meta = _meta;
    if (_loadingMore || _loading || meta == null || !meta.hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final r = await _fetch(meta.currentPage + 1);
      if (!mounted) return;
      setState(() {
        _reviews = [..._reviews, ...r.items];
        _meta = r.meta;
      });
    } catch (e) {
      _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setFilter(_Filter f) {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      _reviews = [];
      _meta = null;
    });
    _reloadList();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final res = await GbpService.sync();
      _snack(
        res.message.isNotEmpty
            ? res.message
            : 'Synced ${res.reviews} reviews from Google.',
      );
      await LocationStore.refresh().catchError((_) {});
      await _reloadAll();
    } catch (e) {
      _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _openReply(GbpReview review) async {
    final updated = await showModalBottomSheet<GbpReview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ReplySheet(review: review),
    );
    if (updated == null || !mounted) return;
    setState(() {
      if (!review.hasReply && _unreplied > 0) _unreplied--;
      _reviews = _filter == _Filter.unreplied
          ? _reviews.where((r) => r.id != updated.id).toList()
          : [for (final r in _reviews) r.id == updated.id ? updated : r];
    });
    _snack('Reply posted to Google');
  }

  double get _avgRating {
    final selected = LocationStore.selected;
    if (selected != null) return selected.rating;
    final all = LocationStore.locations.value;
    final count = all.fold<int>(0, (s, l) => s + l.reviewCount);
    if (count == 0) return 0;
    return all.fold<double>(0, (s, l) => s + l.rating * l.reviewCount) / count;
  }

  @override
  Widget build(BuildContext context) {
    final showLocation =
        LocationStore.selectedId.value == null &&
        LocationStore.locations.value.length > 1;
    final hasMore = _meta?.hasMore ?? false;
    final empty = _reviews.isEmpty;
    // header + (cards, or one empty/loading row) + optional "loading more" row
    final count = 1 + (empty ? 1 : _reviews.length) + (!empty && hasMore ? 1 : 0);

    return Scaffold(
      backgroundColor: surface,
      body: RefreshIndicator(
        color: brand,
        onRefresh: _reloadAll,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _Header(
                total: _totalAll,
                avg: _avgRating,
                unreplied: _unreplied,
                filter: _filter,
                syncing: _syncing,
                onFilter: _setFilter,
                onSync: _sync,
              );
            }
            if (empty) {
              if (_loading) {
                return const SizedBox(
                  height: 420,
                  child: SkeletonList(
                    count: 4,
                    itemHeight: 104,
                    padding: EdgeInsets.zero,
                  ),
                );
              }
              return _Empty(
                error: _error,
                hasAny: _filter != _Filter.all || _totalAll > 0,
                onSync: _sync,
                onRetry: _reloadAll,
                onOverview: () => widget.onNavigate(kPageOverview),
              );
            }
            final index = i - 1;
            if (index >= _reviews.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final review = _reviews[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FadeIn(
                delay: index < 8 ? index * 50 : 0,
                child: _ReviewCard(
                  review: review,
                  showLocation: showLocation,
                  onReply: () => _openReply(review),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.avg,
    required this.unreplied,
    required this.filter,
    required this.syncing,
    required this.onFilter,
    required this.onSync,
  });

  final int total;
  final double avg;
  final int unreplied;
  final _Filter filter;
  final bool syncing;
  final ValueChanged<_Filter> onFilter;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final replied = total - unreplied;
    final rate = total <= 0 ? 0.0 : (replied / total).clamp(0.0, 1.0);

    Widget hero() {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [royalNavy, royalIndigo, royalViolet],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: royalNavy.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (avg == 0)
                      Text(
                        '-',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 40,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      )
                    else
                      CountUp(
                        value: avg,
                        decimals: 1,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 40,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        '/ 5',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 5; i++)
                      Icon(
                        i < avg.round()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 17,
                        color: royalGold,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$total ${total == 1 ? 'review' : 'reviews'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: rate),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 7,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(royalGold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    total == 0
                        ? 'No reviews yet'
                        : unreplied > 0
                            ? '${(rate * 100).round()}% replied, $unreplied waiting'
                            : 'All reviews replied',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    String label(_Filter f) {
      switch (f) {
        case _Filter.all:
          return 'All';
        case _Filter.unreplied:
          return 'Unreplied';
        default:
          return '${_ratingOf(f)} star';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeIn(child: hero()),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: f == _Filter.unreplied
                          ? Icon(Icons.hourglass_bottom_rounded,
                              size: 14, color: filter == f ? brand : warn)
                          : (_ratingOf(f) != null
                              ? Icon(Icons.star_rounded,
                                  size: 15, color: filter == f ? brand : star)
                              : null),
                      label: Text(f == _Filter.all || f == _Filter.unreplied
                          ? label(f)
                          : '${_ratingOf(f)}'),
                      selected: filter == f,
                      onSelected: (_) => onFilter(f),
                      showCheckmark: false,
                      side: BorderSide(
                        color: filter == f
                            ? brand.withValues(alpha: 0.4)
                            : const Color(0xFFE3E8F2),
                      ),
                      backgroundColor: Colors.white,
                      selectedColor: brand.withValues(alpha: 0.14),
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: filter == f ? brand : ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: syncing ? null : onSync,
              icon: syncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(syncing ? 'Syncing...' : 'Sync from Google'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.error,
    required this.hasAny,
    required this.onSync,
    required this.onRetry,
    required this.onOverview,
  });

  final String? error;
  final bool hasAny;
  final VoidCallback onSync;
  final VoidCallback onRetry;
  final VoidCallback onOverview;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return StateView.error(
        title: 'Could not load reviews',
        text: error!,
        onRetry: onRetry,
      );
    }
    if (hasAny) {
      return const StateView(
        icon: Icons.filter_alt_off_rounded,
        title: 'No reviews match this filter',
        text: 'Try another filter.',
      );
    }
    return Column(
      children: [
        StateView(
          icon: Icons.rate_review_outlined,
          title: 'No reviews yet',
          text:
              'Sync from Google to bring in your reviews. If Google is not connected yet, connect it from the Overview.',
          actionLabel: 'Sync from Google',
          onAction: onSync,
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 4),
        ),
        TextButton(onPressed: onOverview, child: const Text('Go to Overview')),
      ],
    );
  }
}

String _dateLabel(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return 'Just now';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 30) {
    return diff.inDays == 1 ? 'Yesterday' : '${diff.inDays} days ago';
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.showLocation,
    required this.onReply,
  });

  final GbpReview review;
  final bool showLocation;
  final VoidCallback onReply;

  Color get _sentimentColor {
    switch ((review.sentiment ?? '').toUpperCase()) {
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
    final initial = review.authorName.isEmpty
        ? '?'
        : review.authorName[0].toUpperCase();
    final photo = review.authorPhoto;

    // A low-rated review still waiting for a reply is the one to answer first.
    final urgent = !review.hasReply && review.rating <= 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration().copyWith(
        border: Border.all(
          color: urgent ? bad.withValues(alpha: 0.35) : const Color(0xFFEEF1F7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: brand.withValues(alpha: 0.12),
                foregroundImage: (photo != null && photo.isNotEmpty)
                    ? NetworkImage(photo)
                    : null,
                onForegroundImageError: (photo != null && photo.isNotEmpty)
                    ? (_, _) {}
                    : null,
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
                      review.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    Text(
                      _dateLabel(review.reviewedAt),
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
                Icon(
                  i < review.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 16,
                  color: star,
                ),
            ],
          ),
          if (showLocation && (review.locationName ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place_rounded, size: 13, color: brand),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    review.locationName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
          if (review.hasReply)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: good.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your reply',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: good,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.reply!,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ink),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  final GbpReview review;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.review.draftReply ?? '',
  );
  bool _drafting = false;
  bool _sending = false;
  String? _hint;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _draft() async {
    setState(() {
      _drafting = true;
      _hint = null;
    });
    try {
      final res = await GbpService.suggestReply(widget.review.id);
      if (!mounted) return;
      _controller.text = res.draft;
      setState(() {
        _hint = res.isAi
            ? 'AI draft ready. ${res.credits} credits left.'
            : 'AI is unavailable right now, so this is a standard template.';
      });
    } catch (e) {
      _message(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _drafting = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _message('Reply cannot be empty');
      return;
    }
    setState(() => _sending = true);
    try {
      final updated = await GbpService.replyToReview(widget.review.id, text);
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      _message(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _drafting || _sending;

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
            const SizedBox(height: 16),
            Text(
              'Reply to ${widget.review.authorName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < 5; i++)
                  Icon(
                    i < widget.review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: star,
                  ),
              ],
            ),
            if ((widget.review.comment ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  widget.review.comment!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.4,
                    color: muted,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              maxLines: 6,
              minLines: 3,
              maxLength: 4000,
              decoration: InputDecoration(
                hintText: 'Write your reply or use an AI draft...',
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_hint != null) ...[
              Text(
                _hint!,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _draft,
                    icon: _drafting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('AI draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : _send,
                    icon: _sending
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
      ),
    );
  }
}
