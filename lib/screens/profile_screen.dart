import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/account_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../services/web_handoff.dart';
import '../theme/brand.dart';
import 'support_screen.dart';

/// Your account: details, photo, password, help, policies, sign out and
/// account deletion.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _fill(AppUser u) {
    _user = u;
    _name.text = u.name;
    _phone.text = u.phone ?? '';
    _address.text = u.address ?? '';
  }

  Future<void> _load() async {
    try {
      final u = await Session.refresh();
      if (!mounted) return;
      setState(() => _fill(u));
    } catch (e) {
      final cached = Session.current;
      if (cached != null && mounted) setState(() => _fill(cached));
      _message(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _dirty {
    final u = _user;
    if (u == null) return false;
    return _name.text.trim() != u.name ||
        _phone.text.trim() != (u.phone ?? '') ||
        _address.text.trim() != (u.address ?? '');
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _message('Your name cannot be empty.');
      return;
    }
    setState(() => _saving = true);
    try {
      await AccountService.updateProfile(
        name: name,
        phone: _phone.text.trim(),
        address: _address.text.trim(),
      );
      final u = await Session.refresh();
      if (!mounted) return;
      setState(() => _fill(u));
      _message('Profile saved');
    } catch (e) {
      _message(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      await AccountService.updateProfile(
        avatarDataUrl: AccountService.avatarDataUrl(bytes),
      );
      final u = await Session.refresh();
      if (!mounted) return;
      setState(() => _fill(u));
    } catch (e) {
      _message(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _changePassword() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _PasswordSheet(),
    );
    if (done == true) _message('Password changed');
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Your session will end on this phone.'),
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

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This removes your account and its data. Invoices and payment records '
          'are kept where the law requires it. We will open the deletion page '
          'where you can send your request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: bad),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (ok == true) await openPublicPage('/delete-account');
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      backgroundColor: surface,
      body: _loading && u == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: brand,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (u != null) _Header(user: u, uploading: _uploadingPhoto, onPhoto: _changePhoto),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: cardDecoration(),
                    child: ListenableBuilder(
                      listenable: Listenable.merge([_name, _phone, _address]),
                      builder: (context, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(controller: _name, decoration: _dec('Full name')),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: _dec('Mobile number'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _address,
                            minLines: 2,
                            maxLines: 4,
                            decoration: _dec('Address'),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: (_dirty && !_saving) ? _save : null,
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save changes'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Group(children: [
                    _Row(
                      icon: Icons.lock_reset_rounded,
                      label: 'Change password',
                      onTap: _changePassword,
                    ),
                    _Row(
                      icon: Icons.support_agent_rounded,
                      label: 'Help & support',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
                      ),
                    ),
                    _Row(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy policy',
                      onTap: () => openPublicPage('/privacy-policy'),
                    ),
                    _Row(
                      icon: Icons.description_outlined,
                      label: 'Terms and conditions',
                      onTap: () => openPublicPage('/terms-and-conditions'),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _Group(children: [
                    _Row(
                      icon: Icons.logout_rounded,
                      label: 'Log out',
                      onTap: _signOut,
                    ),
                    _Row(
                      icon: Icons.delete_forever_rounded,
                      label: 'Delete my account',
                      danger: true,
                      onTap: _deleteAccount,
                    ),
                  ]),
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.uploading, required this.onPhoto});

  final AppUser user;
  final bool uploading;
  final VoidCallback onPhoto;

  ImageProvider? get _avatar {
    final url = user.avatarUrl;
    if (url == null || url.isEmpty) return null;
    try {
      if (url.startsWith('data:')) {
        final Uint8List bytes = UriData.parse(url).contentAsBytes();
        return MemoryImage(bytes);
      }
      return NetworkImage(url);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = user.name.trim().isEmpty ? 'E' : user.name.trim()[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [royalNavy, royalIndigo, royalViolet]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: uploading ? null : onPhoto,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: royalGold, width: 1.6),
                  ),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    foregroundImage: _avatar,
                    child: uploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            initial,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: royalGold,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera_rounded, size: 14, color: royalNavy),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12.5),
                ),
                if ((user.businessName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.businessName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(color: royalGold, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pill(user.planName ?? (user.hasPlan ? 'Plan active' : 'No plan')),
                    _Pill(user.emailVerified ? 'Email verified' : 'Email not verified'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? bad : ink;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: color),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: danger ? bad : muted),
    );
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty || _next.text.isEmpty) {
      _message('Fill in all the fields.');
      return;
    }
    if (_next.text.length < 8) {
      _message('The new password must be at least 8 characters.');
      return;
    }
    if (_next.text != _confirm.text) {
      _message('The new passwords do not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AccountService.changePassword(
        current: _current.text,
        password: _next.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _message(friendlyException(e).message);
      }
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Change password',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: ink,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _current,
              obscureText: true,
              decoration: _dec('Current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _next,
              obscureText: true,
              decoration: _dec('New password (min 8 characters)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: _dec('Confirm new password'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  }
}
