import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DrawerHeader(name: name, email: email, initial: initial),
          const SizedBox(height: 12),
          _SectionLabel('MAIN MENU'),
          _NavItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            subtitle: 'Health score and overview',
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            icon: Icons.rate_review_rounded,
            label: 'Reviews',
            subtitle: 'Reviews, replies and sync',
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
          _NavItem(
            icon: Icons.groups_rounded,
            label: 'Leads',
            subtitle: 'Pipeline, new leads and stages',
            selected: selectedIndex == 2,
            onTap: () => onSelect(2),
          ),
          _NavItem(
            icon: Icons.campaign_rounded,
            label: 'Social',
            subtitle: 'Facebook, Instagram, LinkedIn, X',
            selected: selectedIndex == 3,
            onTap: () => onSelect(3),
          ),
          _NavItem(
            icon: Icons.insights_rounded,
            label: 'Insights',
            subtitle: 'Search, maps, calls and clicks',
            selected: selectedIndex == 4,
            onTap: () => onSelect(4),
          ),
          _NavItem(
            icon: Icons.language_rounded,
            label: 'Web modules',
            subtitle: 'Invoices, billing and more',
            selected: selectedIndex == 5,
            onTap: () => onSelect(5),
          ),
          const Spacer(),
          const Divider(indent: 20, endIndent: 20, height: 24),
          _NavItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            danger: true,
            onTap: onLogout,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.paddingOf(context).bottom + 16),
            child: Text(
              'Eydia • v1.0',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
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
          colors: [brand, brandDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text(
              initial,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
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
                const SizedBox(height: 2),
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
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: muted,
        ),
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
    final color = danger ? bad : (selected ? brand : ink);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? brand.withValues(alpha: 0.10) : Colors.transparent,
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
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
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
                  const Icon(Icons.circle, size: 8, color: brand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
