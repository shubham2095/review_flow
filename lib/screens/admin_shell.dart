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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
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
    final initial = widget.name.trim().isEmpty ? 'A' : widget.name.trim()[0].toUpperCase();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: brand,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            _items[_section].$1,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                child: Text(
                  initial,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2437),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Panel',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                            ),
                            Text(
                              widget.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                  child: Text(
                    'MANAGE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: muted,
                    ),
                  ),
                ),
                for (var i = 0; i < _items.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: Material(
                      color: _section == i ? brand.withValues(alpha: 0.10) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _pick(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          child: Row(
                            children: [
                              Icon(_items[i].$2, size: 20, color: _section == i ? brand : ink),
                              const SizedBox(width: 14),
                              Text(
                                _items[i].$1,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  color: _section == i ? brand : ink,
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
                  title: Text('User view', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onUserView();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: bad),
                  title: Text(
                    'Sign out',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: bad),
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
        body: AdminSectionView(section: _section, onSignedOut: widget.onSignedOut),
      ),
    );
  }
}
