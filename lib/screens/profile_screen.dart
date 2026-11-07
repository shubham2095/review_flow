import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/account_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/platform_rules.dart';
import '../services/session.dart';
import '../services/web_handoff.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';
import '../widgets/password_rules.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/skeleton.dart';
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
  String? _nameError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    // A field's red message goes away as soon as it is edited.
    _name.addListener(() {
      if (_nameError != null) setState(() => _nameError = null);
    });
    _phone.addListener(() {
      if (_phoneError != null) setState(() => _phoneError = null);
    });
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
      if (cached != null && mounted && _user == null) setState(() => _fill(cached));
      _message(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Pull to refresh reloads the form, so ask before throwing edits away.
  Future<void> _refresh() async {
    if (_dirty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard your changes?'),
          content: const Text('What you edited has not been saved yet.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: bad),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _load();
  }

  void _discard() {
    final u = _user;
    if (u == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _fill(u);
      _nameError = null;
      _phoneError = null;
    });
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
    final phone = _phone.text.trim();
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final nameError = name.isEmpty ? 'Your name cannot be empty.' : null;
    final phoneError = phone.isNotEmpty &&
            (!RegExp(r'^[+\d\s\-()]+$').hasMatch(phone) ||
                digits.length < 7 ||
                digits.length > 15)
        ? 'Enter a valid mobile number, like +91 98765 43210.'
        : null;
    if (nameError != null || phoneError != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _nameError = nameError;
        _phoneError = phoneError;
      });
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
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        imageQuality: 80,
      );
    } catch (_) {
      _message('Could not open your photos. Check the photo permission for Eydia.');
      return;
    }
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
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _DeleteAccountSheet(),
    );
    if (deleted == true && mounted) widget.onSignedOut();
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
          ? const SkeletonList(count: 3, itemHeight: 130, headerHeight: 150)
          : RefreshIndicator(
              color: brand,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (u != null)
                    FadeIn(
                      child: _Header(
                        user: u,
                        uploading: _uploadingPhoto,
                        onPhoto: _changePhoto,
                      ),
                    ),
                  const SizedBox(height: 16),
                  FadeIn(
                    delay: 80,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: cardDecoration(),
                      child: ListenableBuilder(
                        listenable: Listenable.merge([_name, _phone, _address]),
                        builder: (context, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Your details',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _name,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              decoration: _dec('Full name').copyWith(errorText: _nameError),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.telephoneNumber],
                              decoration: _dec('Mobile number').copyWith(errorText: _phoneError),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _address,
                              minLines: 2,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.words,
                              decoration: _dec('Address'),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (_dirty) ...[
                                  OutlinedButton(
                                    onPressed: _saving ? null : _discard,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 50),
                                    ),
                                    child: const Text('Discard'),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: FilledButton(
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
                                ),
                              ],
                            ),
                          ],
                        ),
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
                  const SizedBox(height: 18),
                  // Support asks which version of the app someone is on.
                  const _VersionFooter(),
                ],
              ),
            ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final info = snap.data;
        if (info == null) return const SizedBox.shrink();
        return Center(
          child: Text(
            'Eydia ${info.version} (${info.buildNumber})',
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
          ),
        );
      },
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
  bool _show = false;

  // Problems are shown inside the sheet: a snack bar would sit behind it.
  String? _currentError;
  String? _nextError;
  String? _confirmError;
  String? _notice;

  @override
  void initState() {
    super.initState();
    for (final c in [_current, _next, _confirm]) {
      c.addListener(() {
        if (_currentError != null || _nextError != null || _confirmError != null) {
          setState(() {
            _currentError = null;
            _nextError = null;
            _confirmError = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    String? current;
    String? next;
    String? confirm;
    if (_current.text.isEmpty) current = 'Enter your current password.';
    final rule = PasswordRules.problem(_next.text);
    if (rule != null) {
      next = rule;
    } else if (_next.text == _current.text) {
      next = 'Choose a password different from the current one.';
    }
    if (_confirm.text != _next.text) confirm = 'The passwords do not match.';
    if (current != null || next != null || confirm != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _currentError = current;
        _nextError = next;
        _confirmError = confirm;
        _notice = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await AccountService.changePassword(
        current: _current.text,
        password: _next.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _notice = friendlyException(e).message;
        });
      }
    }
  }

  InputDecoration _dec(String label, {String? errorText}) => InputDecoration(
        labelText: label,
        errorText: errorText,
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
              obscureText: !_show,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.password],
              decoration: _dec('Current password', errorText: _currentError).copyWith(
                suffixIcon: IconButton(
                  tooltip: _show ? 'Hide passwords' : 'Show passwords',
                  icon: Icon(
                    _show ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: muted,
                  ),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _next,
              obscureText: !_show,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: _dec('New password', errorText: _nextError),
            ),
            ListenableBuilder(
              listenable: _next,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: PasswordRulesView(password: _next.text),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: !_show,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _busy ? null : _submit(),
              decoration: _dec('Confirm new password', errorText: _confirmError),
            ),
            const SizedBox(height: 16),
            SheetNotice(_notice),
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

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  // Shown inside the sheet: a snack bar would sit behind it.
  String? _notice;
  String? _passwordError;

  /// Deleting is permanent: the person has to type the word, not just tap.
  bool get _confirmed => _confirm.text.trim().toUpperCase() == 'DELETE';

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } on SignInCancelled {
      // The person closed the Google chooser: nothing happened, nothing to say.
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _busy = false;
          _notice = friendlyException(e).message;
        });
      }
    }
  }

  Future<void> _withPassword() async {
    if (_password.text.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() => _passwordError = 'Enter your password to confirm.');
      return;
    }
    await _run(() => AuthService.deleteAccount(password: _password.text));
  }

  Future<void> _withGoogle() async {
    await _run(() async {
      final idToken = await AuthService.googleIdToken();
      await AuthService.deleteAccount(idToken: idToken);
    });
  }

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
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: bad),
                const SizedBox(width: 8),
                Text(
                  'Delete your account',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'This permanently removes your profile, connected Google tokens and '
              'synced data. If you are the only member of your workspace, the '
              'workspace is deleted too. Invoices and payment records are kept '
              'only as long as the law requires.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirm,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Type DELETE to confirm',
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _hide,
              onChanged: (_) {
                if (_passwordError != null) setState(() => _passwordError = null);
              },
              decoration: InputDecoration(
                labelText: 'Your password',
                errorText: _passwordError,
                filled: true,
                fillColor: surface,
                suffixIcon: IconButton(
                  tooltip: _hide ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _hide ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: muted,
                  ),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SheetNotice(_notice),
            FilledButton(
              onPressed: (_busy || !_confirmed) ? null : _withPassword,
              style: FilledButton.styleFrom(backgroundColor: bad),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Delete my account'),
            ),
            const SizedBox(height: 4),
            // Google confirmation exists only where Google sign-in does
            // (platform_rules.dart). On iOS the password confirms; an account
            // made with Google can set one through "Forgot password".
            if (googleSignInAvailable)
              TextButton.icon(
                onPressed: (_busy || !_confirmed) ? null : _withGoogle,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                label: const Text('I signed in with Google: confirm with Google'),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Signed up with Google and never set a password? Use "Forgot password" on the sign-in screen to set one first.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
                ),
              ),
            TextButton(
              onPressed: _busy ? null : () => openPublicPage('/delete-account'),
              child: const Text('Prefer email? See the deletion page'),
            ),
          ],
        ),
      ),
    );
  }
}
