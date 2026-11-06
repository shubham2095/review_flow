import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/brand.dart';

/// A slim bar shown while screens display data saved earlier because the
/// server cannot be reached. It checks quietly for the connection coming back
/// and goes away by itself; "Retry" checks right now.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: ApiService.servingSavedData,
      builder: (context, savedAt, _) => AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: savedAt == null
            ? const SizedBox(width: double.infinity)
            : _Bar(savedAt: savedAt),
      ),
    );
  }
}

class _Bar extends StatefulWidget {
  const _Bar({required this.savedAt});

  final DateTime savedAt;

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> {
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // Notice the connection coming back without anyone tapping.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    await ApiService.instance.checkReachable();
    if (mounted) setState(() => _checking = false);
  }

  String get _age {
    final d = DateTime.now().difference(widget.savedAt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFFFF3D6),
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 18,
              color: Color(0xFF8A5A00),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "You're offline. Showing data saved $_age.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
            TextButton(
              onPressed: _checking ? null : _check,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Retry',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF8A5A00),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
