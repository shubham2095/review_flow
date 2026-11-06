import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/brand.dart';

/// Wraps the content of a bottom sheet so anything inside it can show a message
/// that is actually visible. A snack bar belongs to the screen underneath and
/// can sit behind the sheet; this notice floats at the top of the sheet itself,
/// stays put while the sheet scrolls, and goes away after a few seconds.
///
/// Inside a sheet: `NoticeScope.show(context, 'text')`. Outside any scope it
/// falls back to a normal snack bar, so the same call works everywhere.
class NoticeScope extends StatefulWidget {
  const NoticeScope({super.key, required this.child});

  final Widget child;

  /// Shows [text] in the nearest sheet, or as a snack bar when there is none.
  static void show(BuildContext context, String text, {bool error = true}) {
    final state = context.findAncestorStateOfType<_NoticeScopeState>();
    if (state != null) {
      state._show(text, error);
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  State<NoticeScope> createState() => _NoticeScopeState();
}

class _NoticeScopeState extends State<NoticeScope> {
  String? _text;
  bool _error = true;
  Timer? _timer;

  void _show(String text, bool error) {
    if (!mounted) return;
    if (error) HapticFeedback.lightImpact();
    _timer?.cancel();
    setState(() {
      _text = text;
      _error = error;
    });
    _timer = Timer(const Duration(seconds: 4), _hide);
  }

  void _hide() {
    if (mounted) setState(() => _text = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    final tone = _error ? bad : good;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 10,
          left: 16,
          right: 16,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: text == null
                ? const SizedBox.shrink()
                : Semantics(
                    liveRegion: true,
                    child: Material(
                      key: ValueKey(text),
                      color: Colors.white,
                      elevation: 6,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _hide,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: tone.withValues(alpha: 0.35)),
                            color: tone.withValues(alpha: 0.06),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _error
                                    ? Icons.error_outline_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 18,
                                color: tone,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  text,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    height: 1.35,
                                    color: ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
