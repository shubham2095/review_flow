import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/team_models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<TeamMember>? _members;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final list = await ApiService.instance.getList('/team');
      if (!mounted) return;
      setState(() {
        _members = list
            .cast<Map<String, dynamic>>()
            .map(TeamMember.fromJson)
            .toList();
        _error = null;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthService.logout();
        widget.onSignedOut();
        return;
      }
      if (mounted) {
        setState(() {
          _error = e.statusCode == 403
              ? 'Only the client owner can manage the team.'
              : e.message;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addMember() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _MemberSheet(),
    );
    if (result == 'added') {
      _snack('Team member added ✅');
      _load();
    }
  }

  Future<void> _editMember(TeamMember member) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _MemberSheet(member: member),
    );
    if (result == 'updated') {
      _snack('Team member updated ✅');
      _load();
    } else if (result == 'deleted') {
      _snack('Team member removed');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;

    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: members == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addMember,
              backgroundColor: brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(
                'Add member',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: members == null
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.7,
                    child: Center(
                      child: _loading
                          ? const CircularProgressIndicator()
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '🔒',
                                    style: TextStyle(fontSize: 40),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _error ?? 'Could not load team',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: _load,
                                    child: const Text('Try again'),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              )
            : members.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.6,
                    child: Center(
                      child: FadeIn(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('👥', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            Text(
                              'No team members yet',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add your first member.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: members.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FadeIn(
                    delay: i < 12 ? i * 60 : 0,
                    child: _MemberCard(
                      member: members[i],
                      onTap: () => _editMember(members[i]),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.onTap});

  final TeamMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = member.name.isEmpty ? '?' : member.name[0].toUpperCase();
    final isManager = member.role == 'MARKETING_MANAGER';
    final color = isManager ? brandDeep : brand;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: cardDecoration(),
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Text(
                    initial,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Container(
                  key: ValueKey(member.role),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    roleLabels[member.role] ?? member.role,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberSheet extends StatefulWidget {
  const _MemberSheet({this.member});

  final TeamMember? member;

  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  late final _name = TextEditingController(text: widget.member?.name ?? '');
  late final _email = TextEditingController(text: widget.member?.email ?? '');
  final _password = TextEditingController();
  late String _role = widget.member?.role ?? 'STAFF';
  bool _busy = false;

  bool get _isEdit => widget.member != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    if (name.isEmpty || email.isEmpty) {
      _message('Name and email are required');
      return;
    }
    if (!_isEdit && password.length < 8) {
      _message('Password must be at least 8 characters');
      return;
    }
    if (_isEdit && password.isNotEmpty && password.length < 8) {
      _message('New password must be at least 8 characters');
      return;
    }

    setState(() => _busy = true);
    try {
      if (_isEdit) {
        await ApiService.instance.put(
          '/team/${widget.member!.id}',
          body: {
            'name': name,
            'email': email,
            'role': _role,
            if (password.isNotEmpty) 'password': password,
          },
        );
        if (mounted) Navigator.of(context).pop('updated');
      } else {
        await ApiService.instance.post(
          '/team',
          body: {
            'name': name,
            'email': email,
            'password': password,
            'role': _role,
          },
        );
        if (mounted) Navigator.of(context).pop('added');
      }
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove team member?'),
        content: Text(
          '${widget.member!.name} will lose access to this account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await ApiService.instance.delete('/team/${widget.member!.id}');
      if (mounted) Navigator.of(context).pop('deleted');
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEdit ? 'Edit team member' : 'Add team member',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: ink,
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: _dec('Name *')),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _dec('Email *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: _dec(
                _isEdit ? 'New password' : 'Password *',
                hint: _isEdit
                    ? 'Leave empty to keep current password'
                    : 'At least 8 characters',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _role,
              decoration: _dec('Role'),
              items: [
                for (final e in roleLabels.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Add member'),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded, color: bad),
                label: const Text(
                  'Remove member',
                  style: TextStyle(color: bad),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
