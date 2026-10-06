import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/brand.dart';

const _gold = Color(0xFFD4AF37);

/// Light top bar that matches the web app header: white surface, dark text,
/// brand accents. Status bar icons are dark on this surface.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    required this.initial,
    required this.onAvatarTap,
  });

  final String title;
  final String initial;
  final VoidCallback onAvatarTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: kToolbarHeight + 10,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF141E3C).withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 1.2,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _gold.withValues(alpha: 0),
                  _gold.withValues(alpha: 0.8),
                  _gold.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
      leading: Builder(
        builder: (ctx) => IconButton(
          tooltip: 'Menu',
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE6EAF2)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset('assets/images/eydia_logo.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: onAvatarTap,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: brand.withValues(alpha: 0.12),
              child: Text(
                initial,
                style: GoogleFonts.plusJakartaSans(
                  color: brand,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
