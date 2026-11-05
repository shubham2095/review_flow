import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/session.dart';
import '../theme/brand.dart';
import 'admin_companies_screen.dart';
import 'admin_packs_screen.dart';
import 'admin_payments_screen.dart';
import 'admin_plans_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_support_screen.dart';

/// Layout for the platform super admin: a royal drawer with the admin sections.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _section = 0;
  final Set<int> _visited = {0};

  static const _items = [
    ('Companies', 'Tenants, plans, credits and users', Icons.business_rounded),
    ('Plans', 'Pricing, limits and features', Icons.workspace_premium_rounded),
    ('Credit packs', 'AI credit packs for sale', Icons.bolt_rounded),
    ('Payments', 'Every plan invoice', Icons.payments_rounded),
    ('Support', 'Tickets from all companies', Icons.support_agent_rounded),
    ('Settings', 'Invoice details and AI provider', Icons.settings_rounded),
  ];

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AuthService.logout();
    if (mounted) widget.onSignedOut();
  }

  void _pick(int i) {
    Navigator.of(context).pop();
    setState(() {
      _section = i;
      _visited.add(i);
    });
  }

  Widget _page(int i) {
    switch (i) {
      case 0:
        return const AdminCompaniesScreen();
      case 1:
        return const AdminPlansScreen();
      case 2:
        return const AdminPacksScreen();
      case 3:
        return const AdminPaymentsScreen();
      case 4:
        return const AdminSupportScreen();
      default:
        return const AdminSettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Session.current;
    final name = user?.name ?? '';
    final initial = name.trim().isEmpty ? 'A' : name.trim()[0].toUpperCase();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: royalNavy,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: surface,
        appBar: AppBar(
          backgroundColor: royalIndigo,
          foregroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [royalNavy, royalIndigo, royalViolet],
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
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              _items[_section].$1,
              key: ValueKey(_section),
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: royalGold, width: 1.3),
                  ),
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    child: Text(
                      initial,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: Colors.white,
          width: MediaQuery.sizeOf(context).width * 0.8,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top + 20,
                  20,
                  22,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [royalNavy, royalIndigo, royalViolet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(bottomRight: Radius.circular(28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
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
                                name.isEmpty ? 'Super admin' : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                user?.email ?? '',
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
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: royalGold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: royalGold.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        'SUPER ADMIN',
                        style: GoogleFonts.plusJakartaSans(
                          color: royalGold,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _items.length; i++)
                _NavItem(
                  icon: _items[i].$3,
                  label: _items[i].$1,
                  subtitle: _items[i].$2,
                  selected: _section == i,
                  onTap: () => _pick(i),
                ),
              const Divider(indent: 20, endIndent: 20, height: 28),
              _NavItem(
                icon: Icons.logout_rounded,
                label: 'Logout',
                danger: true,
                onTap: () {
                  Navigator.of(context).pop();
                  _logout();
                },
              ),
            ],
          ),
        ),
        body: IndexedStack(
          index: _section,
          children: [
            for (var i = 0; i < _items.length; i++)
              _visited.contains(i) ? _page(i) : const SizedBox.shrink(),
          ],
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
    final color = danger ? bad : (selected ? royalIndigo : ink);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? royalIndigo.withValues(alpha: 0.07) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
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
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: selected && !danger ? Colors.white : color,
                  ),
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
                    decoration: const BoxDecoration(
                      color: royalGold,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
