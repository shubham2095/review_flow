import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/gbp_models.dart';
import '../services/api_service.dart';
import '../services/gbp_service.dart';
import '../services/location_store.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';
import 'pages.dart';

enum _Filter { all, unreplied, negative, positive }

/// Google reviews for the selected location (or all locations): filters,
/// reply with an optional AI draft, and sync from Google.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<GbpReview> _all = [];
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    LocationStore.selectedId.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    LocationStore.selectedId.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted && _all.isEmpty) setState(() => _loading = true);
    try {
      final list = await GbpService.reviews(
        locationId: LocationStore.selectedId.value,
      );
      if (!mounted) return;
      setState(() {
        _all = list;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      await _load();
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
      _all = [for (final r in _all) r.id == updated.id ? updated : r];
    });
    _snack('Reply posted to Google');
  }

  List<GbpReview> get _visible {
    switch (_filter) {
      case _Filter.all:
        return _all;
      case _Filter.unreplied:
        return _all.where((r) => !r.hasReply).toList();
      case _Filter.negative:
        return _all.where((r) => r.rating <= 2).toList();
      case _Filter.positive:
        return _all.where((r) => r.rating >= 4).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final showLocation =
        LocationStore.selectedId.value == null &&
        LocationStore.locations.value.length > 1;

    return Scaffold(
      backgroundColor: surface,
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: _loading && _all.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: visible.isEmpty ? 2 : visible.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return _Header(
                      reviews: _all,
                      filter: _filter,
                      syncing: _syncing,
                      onFilter: (f) => setState(() => _filter = f),
                      onSync: _sync,
                    );
                  }
                  if (visible.isEmpty) {
                    return _Empty(
                      error: _error,
                      hasAny: _all.isNotEmpty,
                      onSync: _sync,
                      onRetry: _load,
                      onOverview: () => widget.onNavigate(kPageOverview),
                    );
                  }
                  final review = visible[i - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FadeIn(
                      delay: i < 8 ? i * 50 : 0,
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
    required this.reviews,
    required this.filter,
    required this.syncing,
    required this.onFilter,
    required this.onSync,
  });

  final List<GbpReview> reviews;
  final _Filter filter;
  final bool syncing;
  final ValueChanged<_Filter> onFilter;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final total = reviews.length;
    final avg = total == 0
        ? 0.0
        : reviews.fold<int>(0, (s, r) => s + r.rating) / total;
    final unreplied = reviews.where((r) => !r.hasReply).length;
    final negative = reviews.where((r) => r.rating <= 2).length;

    Widget stat(IconData icon, String value, String label, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: ink,
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

    String label(_Filter f) {
      switch (f) {
        case _Filter.all:
          return 'All ($total)';
        case _Filter.unreplied:
          return 'Unreplied ($unreplied)';
        case _Filter.negative:
          return 'Negative ($negative)';
        case _Filter.positive:
          return 'Positive';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeIn(
            child: Row(
              children: [
                stat(Icons.reviews_rounded, '$total', 'Total', brand),
                const SizedBox(width: 8),
                stat(Icons.star_rounded, avg.toStringAsFixed(1), 'Avg', star),
                const SizedBox(width: 8),
                stat(
                  Icons.hourglass_bottom_rounded,
                  '$unreplied',
                  'Unreplied',
                  unreplied > 0 ? warn : good,
                ),
                const SizedBox(width: 8),
                stat(
                  Icons.thumb_down_alt_rounded,
                  '$negative',
                  'Negative',
                  negative > 0 ? bad : good,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label(f)),
                      selected: filter == f,
                      onSelected: (_) => onFilter(f),
                      showCheckmark: false,
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
    final failed = error != null;
    final title = failed
        ? 'Could not load reviews'
        : (hasAny ? 'No reviews match this filter' : 'No reviews yet');
    final text = failed
        ? error!
        : (hasAny
            ? 'Try another filter.'
            : 'Sync from Google to bring in your reviews. If Google is not connected yet, connect it from the Overview.');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Column(
        children: [
          Icon(
            failed ? Icons.cloud_off_rounded : Icons.rate_review_outlined,
            size: 44,
            color: muted,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 16),
          if (failed)
            FilledButton(onPressed: onRetry, child: const Text('Try again'))
          else if (!hasAny) ...[
            FilledButton(onPressed: onSync, child: const Text('Sync from Google')),
            TextButton(
              onPressed: onOverview,
              child: const Text('Go to Overview'),
            ),
          ],
        ],
      ),
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
