import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  String _email = '';
  String _role = '';
  bool _verified = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _current.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _s(dynamic v) => v?.toString() ?? '';

  Future<void> _load() async {
    try {
      final me = await ApiService.instance.get('/me');
      if (!mounted) return;
      setState(() {
        _name.text = (me['name'] ?? '').toString();
        _phone.text = (me['phone'] ?? '').toString();
        _email = (me['email'] ?? '').toString();
        _role = (me['role'] ?? '').toString();
        _verified = me['email_verified'] == true;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthService.logout();
        widget.onSignedOut();
        return;
      }
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _snack('Name is required');
      return;
    }
    final wantsPasswordChange = _newPassword.text.isNotEmpty;
    if (wantsPasswordChange && _newPassword.text.length < 8) {
      _snack('New password must be at least 8 characters');
      return;
    }

    setState(() => _busy = true);
    try {
      await ApiService.instance.put('/profile', body: {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        if (wantsPasswordChange) 'current_password': _current.text,
        if (wantsPasswordChange) 'new_password': _newPassword.text,
      });
      _current.clear();
      _newPassword.clear();
      _snack('Profile saved ✅');
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendVerification() async {
    try {
      final res = await ApiService.instance.post('/email/send-verification');
      _snack(_s(res['message']).isEmpty ? 'Verification link sent' : _s(res['message']));
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _changeEmail() async {
    final controller = TextEditingController();
    final newEmail = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change email'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'New email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (newEmail == null || newEmail.isEmpty) return;
    try {
      await ApiService.instance.post('/email/change', body: {'email': newEmail});
      if (mounted) {
        setState(() {
          _email = newEmail;
          _verified = false;
        });
      }
      _snack('Email updated. Please verify your new email.');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

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

  InputDecoration _dec(String label, {bool enabled = true}) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? Colors.white : surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final initial = _name.text.trim().isEmpty ? '?' : _name.text.trim()[0].toUpperCase();

    return Scaffold(
      backgroundColor: surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: cardDecoration(),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: brand.withValues(alpha: 0.12),
                        child: Text(
                          initial,
                          style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: brand),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _name.text,
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                            ),
                            Text(_email, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: brand.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _role.replaceAll('_', ' ').toLowerCase(),
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: brand),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Profile information',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink)),
                      const SizedBox(height: 12),
                      TextField(controller: _name, decoration: _dec('Full name')),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: _dec('Phone'),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: _dec('Email (cannot be changed here)', enabled: false),
                        child: Text(_email, style: GoogleFonts.plusJakartaSans(color: muted)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Change password',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink)),
                      const SizedBox(height: 4),
                      Text(
                        'Leave empty to keep your current password.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: _current, obscureText: true, decoration: _dec('Current password')),
                      const SizedBox(height: 12),
                      TextField(controller: _newPassword, obscureText: true, decoration: _dec('New password')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Email verification',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink)),
                      const SizedBox(height: 6),
                      Text(
                        _verified ? '✅ Your email is verified.' : '⚠️ Your email is not verified yet.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                      ),
                      const SizedBox(height: 10),
                      if (!_verified)
                        OutlinedButton(onPressed: _sendVerification, child: const Text('Send verification email')),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: _changeEmail, child: const Text('Change email')),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save changes'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, color: bad),
                  label: const Text('Log out', style: TextStyle(color: bad)),
                ),
              ],
            ),
    );
  }
}
