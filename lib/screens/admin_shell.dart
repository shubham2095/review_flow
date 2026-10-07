import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../theme/brand.dart';
import 'admin_screen.dart';

/// Super admin ka main layout. Sidebar mein admin sections hain, aur neeche
/// "User view" se normal client app khulti hai.
class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.name,
    required this.email,
    required this.onSignedOut,
    required this.onUserView,
  });

  final String name;
  final String email;
  final VoidCallback onSignedOut;
  final VoidCallback onUserView;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _section = 0;

  static const _items = [
    ('Overview', Icons.dashboard_rounded),
    ('Users', Icons.people_alt_rounded),
    ('Plans', Icons.workspace_premium_rounded),
    ('Credit packs', Icons.bolt_rounded),
    ('Top-up', Icons.add_card_rounded),
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
    setState(() => _section = i);
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.trim().isEmpty
        ? 'A'
        : widget.name.trim()[0].toUpperCase();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: royalNavy,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
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
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: Colors.white,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [royalNavy, royalIndigo, royalViolet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: royalIndigo.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: royalGold, width: 1.4),
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: royalGold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Panel',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              widget.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                  child: Row(
                    children: [
                      Container(width: 14, height: 1.5, color: royalGold),
                      const SizedBox(width: 8),
                      Text(
                        'MANAGE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: royalIndigo,
                        ),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < _items.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    child: Material(
                      color: _section == i
                          ? royalIndigo.withValues(alpha: 0.07)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _pick(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: _section == i
                                      ? const LinearGradient(
                                          colors: [royalIndigo, royalViolet],
                                        )
                                      : null,
                                  color: _section == i
                                      ? null
                                      : ink.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _items[i].$2,
                                  size: 18,
                                  color: _section == i ? Colors.white : ink,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  _items[i].$1,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    color: _section == i ? royalIndigo : ink,
                                  ),
                                ),
                              ),
                              if (_section == i)
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
                  ),
                const Spacer(),
                const Divider(indent: 20, endIndent: 20),
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: Text(
                    'User view',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onUserView();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: bad),
                  title: Text(
                    'Sign out',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: bad,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _logout();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: KeyedSubtree(
            key: ValueKey(_section),
            child: AdminSectionView(
              section: _section,
              onSignedOut: widget.onSignedOut,
            ),
          ),
        ),
      ),
    );
  }
}
