import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../screens/pages.dart';
import '../theme/brand.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.name,
    required this.email,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  final String name;
  final String email;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'E' : name.trim()[0].toUpperCase();

    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.sizeOf(context).width * 0.8,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // The person's own card opens their profile.
          Semantics(
            button: true,
            label: 'Open my profile',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).pop();
                onSelect(kPageAccount);
              },
              child: _DrawerHeader(name: name, email: email, initial: initial),
            ),
          ),
          const SizedBox(height: 12),
          _SectionLabel('WORKSPACE'),
          _NavItem(
            icon: Icons.dashboard_rounded,
            label: 'Overview',
            subtitle: 'Health score and what to do next',
            selected: selectedIndex == kPageOverview,
            onTap: () => onSelect(kPageOverview),
          ),
          _NavItem(
            icon: Icons.rate_review_rounded,
            label: 'Reviews',
            subtitle: 'Reviews, replies and sync',
            selected: selectedIndex == kPageReviews,
            onTap: () => onSelect(kPageReviews),
          ),
          _NavItem(
            icon: Icons.photo_library_rounded,
            label: 'Posts & Photos',
            subtitle: 'Google posts, offers and photos',
            selected: selectedIndex == kPagePosts,
            onTap: () => onSelect(kPagePosts),
          ),
          _NavItem(
            icon: Icons.insights_rounded,
            label: 'Insights',
            subtitle: 'Searches, calls, clicks and directions',
            selected: selectedIndex == kPageInsights,
            onTap: () => onSelect(kPageInsights),
          ),
          _NavItem(
            icon: Icons.auto_awesome_rounded,
            label: 'AI Tools',
            subtitle: 'Audit, optimize and AI assistant',
            selected: selectedIndex == kPageAiTools,
            onTap: () => onSelect(kPageAiTools),
          ),
          _NavItem(
            icon: Icons.storefront_rounded,
            label: 'Business profile',
            subtitle: 'Hours, contact and description',
            selected: selectedIndex == kPageBusinessProfile,
            onTap: () => onSelect(kPageBusinessProfile),
          ),
          _NavItem(
            icon: Icons.bolt_rounded,
            label: 'Automation',
            subtitle: 'Auto replies and scheduled posts',
            selected: selectedIndex == kPageAutomation,
            onTap: () => onSelect(kPageAutomation),
          ),
          _SectionLabel('ACCOUNT'),
          _NavItem(
            icon: Icons.workspace_premium_rounded,
            label: 'Plans & billing',
            subtitle: 'Your plan, credits and payments',
            selected: selectedIndex == kPageBilling,
            onTap: () => onSelect(kPageBilling),
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'My Profile',
            subtitle: 'Your details and password',
            selected: selectedIndex == kPageAccount,
            onTap: () => onSelect(kPageAccount),
          ),
          const SizedBox(height: 12),
          const Divider(indent: 20, endIndent: 20, height: 24),
          _NavItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            danger: true,
            onTap: onLogout,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.paddingOf(context).bottom + 16),
            // The real version, so support can ask "which version are you on?".
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snap) {
                final info = snap.data;
                return Text(
                  info == null
                      ? 'Eydia'
                      : 'Eydia  ·  v${info.version} (${info.buildNumber})',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.name, required this.email, required this.initial});

  final String name;
  final String email;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 20, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [royalNavy, royalIndigo, royalViolet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Color(0x332B3FBF), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: royalGold, width: 1.6),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  child: Text(
                    initial,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Welcome' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  royalGold.withValues(alpha: 0.9),
                  royalGold.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 1.5,
            color: royalGold,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: royalIndigo,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger ? bad : (selected ? royalIndigo : ink);
    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? royalIndigo.withValues(alpha: 0.07) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).pop();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: selected && !danger
                        ? const LinearGradient(colors: [royalIndigo, royalViolet])
                        : null,
                    color: selected && !danger ? null : color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: selected && !danger
                        ? [BoxShadow(color: royalIndigo.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: Icon(icon, color: selected && !danger ? Colors.white : color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: royalGold, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
