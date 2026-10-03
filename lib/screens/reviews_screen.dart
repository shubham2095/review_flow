import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/review_models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';
import 'location_reviews_screen.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late Future<List<LocationSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<LocationSummary>> _load() async {
    try {
      final list = await ApiService.instance.getList('/reviews');
      return list
          .cast<Map<String, dynamic>>()
          .map(LocationSummary.fromJson)
          .toList();
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

  void _openLocation(LocationSummary loc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationReviewsScreen(
          location: loc,
          onSignedOut: widget.onSignedOut,
        ),
      ),
    );
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
        body: RefreshIndicator(
          color: brand,
          onRefresh: _refresh,
          child: FutureBuilder<List<LocationSummary>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _CenteredList(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _CenteredList(
                  child: _ErrorBox(
                    message: '${snapshot.error}',
                    onRetry: _refresh,
                  ),
                );
              }
              final locations = snapshot.requireData;
              if (locations.isEmpty) {
                return const _CenteredList(
                  child: Text('📭  Koi location nahi mili'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: locations.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _LocationCard(
                    loc: locations[i],
                    onTap: () => _openLocation(locations[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.loc, required this.onTap});

  final LocationSummary loc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [brand, brandDeep]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('📍', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loc.address,
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
                  const Icon(Icons.chevron_right_rounded, color: muted),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniStat(
                    emoji: '⭐',
                    value: loc.avgRating.toStringAsFixed(1),
                    color: star,
                  ),
                  _MiniStat(
                    emoji: '💬',
                    value: '${loc.totalReviews} reviews',
                    color: brand,
                  ),
                  _MiniStat(
                    emoji: '⏳',
                    value: '${loc.unrepliedCount} unreplied',
                    color: loc.unrepliedCount > 0 ? warn : good,
                  ),
                  _MiniStat(
                    emoji: '⚠️',
                    value: '${loc.negativeCount} negative',
                    color: loc.negativeCount > 0 ? bad : good,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.emoji, required this.value, required this.color});

  final String emoji;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$emoji  $value',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😕', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Dobara try karo')),
        ],
      ),
    );
  }
}
