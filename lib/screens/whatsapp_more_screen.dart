import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/brand.dart';
import '../widgets/fade_in.dart';
import '../widgets/pressable.dart';
import '../widgets/wa_ui.dart';
import 'wa_destinations.dart';
import 'whatsapp_analytics_screen.dart';
import 'whatsapp_blacklist_screen.dart';
import 'whatsapp_bots_screen.dart';
import 'whatsapp_templates_screen.dart';

/// The "More" tab: everything that is not one of the main tabs. Each row opens
/// its page full-screen (with a back arrow), exactly as it did from Home.
class WhatsAppMoreScreen extends StatelessWidget {
  const WhatsAppMoreScreen({super.key, required this.onOpenHome});

  /// Numbers are managed on the Home tab, so that row switches to it.
  final VoidCallback onOpenHome;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
  }

  @override
  @override
  Widget build(BuildContext context) {
    // Only what this person may use: the same rules as the side drawer.
    final rows = <(String, WaDestination, VoidCallback)>[
      (
        'Messaging',
        WaDestination.templates,
        () => _open(context, const WhatsAppTemplatesScreen()),
      ),
      (
        'Messaging',
        WaDestination.bots,
        () => _open(context, const WhatsAppBotsScreen()),
      ),
      (
        'Results',
        WaDestination.analytics,
        () => _open(context, const WhatsAppAnalyticsScreen()),
      ),
      ('Setup', WaDestination.numbers, onOpenHome),
      (
        'Setup',
        WaDestination.blocked,
        () => _open(context, const WhatsAppBlacklistScreen()),
      ),
    ].where((r) => r.$2.allows()).toList();

    final children = <Widget>[];
    String? section;
    for (var i = 0; i < rows.length; i++) {
      final (title, place, onTap) = rows[i];
      if (title != section) {
        section = title;
        children.add(SectionTitle(title));
      }
      children.add(
        FadeIn(
          delay: i * 40,
          child: _MoreRow(
            icon: place.icon,
            title: place.label,
            text: place.subtitle,
            onTap: onTap,
          ),
        ),
      );
    }
    if (rows.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nothing else is available for your account.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(color: muted),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: surface,
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: children,
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(minHeight: 64),
        decoration: cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: ExcludeSemantics(
                child: Icon(icon, size: 22, color: brand),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            const ExcludeSemantics(
              child: Icon(Icons.chevron_right_rounded, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
