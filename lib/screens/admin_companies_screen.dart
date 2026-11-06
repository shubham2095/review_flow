import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
import '../theme/brand.dart';
import '../widgets/admin_ui.dart';
import '../widgets/skeleton.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';

/// All companies (tenants) on the platform.
class AdminCompaniesScreen extends StatefulWidget {
  const AdminCompaniesScreen({super.key});

  @override
  State<AdminCompaniesScreen> createState() => _AdminCompaniesScreenState();
}

class _AdminCompaniesScreenState extends State<AdminCompaniesScreen> {
  List<AdminCompany> _companies = [];
  List<AdminPlanOption> _plans = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await AdminService.companies();
      if (!mounted) return;
      setState(() {
        _companies = r.companies;
        _plans = r.plans;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    NoticeScope.show(context, text);
  }

  Future<void> _run(AdminCompany c, Future<void> Function() action, String done) async {
    setState(() => _busy.add(c.id));
    try {
      await action();
      // An action that already said something specific passes no message.
      if (done.isNotEmpty) _snack(done);
      await _load();
    } catch (e) {
      _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _busy.remove(c.id));
    }
  }

  Future<void> _form([AdminCompany? c]) async {
    final saved = await showAdminSheet<bool>(
      context,
      (_) => _CompanyForm(company: c, plans: _plans),
    );
    if (saved == true) {
      _snack(c == null ? 'Company created' : 'Company updated');
      await _load();
    }
  }

  Future<void> _assignPlan(AdminCompany c) async {
    final planId = await showAdminSheet<String>(
      context,
      (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminSheetHeader('Plan for ${c.name}'),
              if (_plans.isEmpty) const Text('No active plans. Create one first.'),
              for (final p in _plans)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.name),
                  trailing: p.id == c.planId
                      ? const Icon(Icons.check_circle_rounded, color: good)
                      : null,
                  onTap: () => Navigator.pop(ctx, p.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (planId == null) return;
    await _run(c, () => AdminService.assignPlan(c.id, planId), 'Plan assigned');
  }

  Future<void> _addCredits(AdminCompany c) async {
    final amount = await showAdminSheet<int>(context, (_) => _CreditsSheet(name: c.name));
    if (amount == null) return;
    await _run(
      c,
      () async {
        final balance = await AdminService.addCredits(c.id, amount);
        _snack('Added $amount credits. Balance: $balance');
      },
      '',
    );
  }

  Future<void> _toggle(AdminCompany c) async {
    final suspend = !c.suspended;
    final ok = await adminConfirm(
      context,
      title: suspend ? 'Suspend ${c.name}?' : 'Reactivate ${c.name}?',
      text: suspend
          ? 'Their users will be blocked until you reactivate the company.'
          : 'Their users will be able to sign in again.',
      action: suspend ? 'Suspend' : 'Reactivate',
      danger: suspend,
    );
    if (!ok) return;
    await _run(
      c,
      () => AdminService.toggleCompany(c.id),
      suspend ? 'Company suspended' : 'Company reactivated',
    );
  }

  Future<void> _delete(AdminCompany c) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete ${c.name}?',
      text: 'The company and its workspace are removed. This cannot be undone.',
      action: 'Delete',
      danger: true,
    );
    if (!ok) return;
    await _run(c, () => AdminService.deleteCompany(c.id), 'Company deleted');
  }

  List<AdminCompany> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _companies;
    return _companies
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.ownerName.toLowerCase().contains(q) ||
              c.ownerEmail.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;

    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        backgroundColor: royalIndigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('New company'),
      ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: _loading
            ? const SkeletonList(count: 5, itemHeight: 92, headerHeight: 52)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: adminInput('Search companies or owners').copyWith(
                      prefixIcon: const Icon(Icons.search_rounded),
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Text(
                      '${_companies.length} companies',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                    ),
                  ),
                  if (_error != null)
                    AdminMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load companies',
                      text: _error!,
                      onRetry: _load,
                    )
                  else if (list.isEmpty)
                    const AdminMessage(
                      icon: Icons.business_outlined,
                      title: 'No companies found',
                    )
                  else
                    for (var i = 0; i < list.length; i++)
                      FadeIn(
                        delay: i < 8 ? i * 40 : 0,
                        child: _CompanyCard(
                          company: list[i],
                          busy: _busy.contains(list[i].id),
                          onEdit: () => _form(list[i]),
                          onPlan: () => _assignPlan(list[i]),
                          onCredits: () => _addCredits(list[i]),
                          onUsers: () => showAdminSheet<void>(
                            context,
                            (_) => _UsersSheet(company: list[i]),
                          ),
                          onToggle: () => _toggle(list[i]),
                          onDelete: () => _delete(list[i]),
                        ),
                      ),
                ],
              ),
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({
    required this.company,
    required this.busy,
    required this.onEdit,
    required this.onPlan,
    required this.onCredits,
    required this.onUsers,
    required this.onToggle,
    required this.onDelete,
  });

  final AdminCompany company;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onPlan;
  final VoidCallback onCredits;
  final VoidCallback onUsers;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = company;
    final agents = c.agentsLimit == null || c.agentsLimit! < 0
        ? '${c.agentsUsed} agents'
        : '${c.agentsUsed}/${c.agentsLimit} agents';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: ink,
                  ),
                ),
              ),
              AdminBadge(c.status, adminStatusColor(c.status)),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        onEdit();
                      case 'plan':
                        onPlan();
                      case 'credits':
                        onCredits();
                      case 'users':
                        onUsers();
                      case 'toggle':
                        onToggle();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit details')),
                    const PopupMenuItem(value: 'plan', child: Text('Change plan')),
                    const PopupMenuItem(value: 'credits', child: Text('Add credits')),
                    const PopupMenuItem(value: 'users', child: Text('Users and passwords')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(c.suspended ? 'Reactivate' : 'Suspend'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: bad)),
                    ),
                  ],
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.ownerName.isEmpty ? c.ownerEmail : '${c.ownerName}  ·  ${c.ownerEmail}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Meta(Icons.workspace_premium_rounded, c.planName ?? 'No plan',
                        c.planName == null ? warn : royalIndigo),
                    _Meta(Icons.people_alt_rounded, '${c.usersCount} users', muted),
                    _Meta(Icons.support_agent_rounded, agents, muted),
                    if (c.createdAt != null)
                      _Meta(Icons.event_rounded, 'Joined ${fmtDate(c.createdAt!)}', muted),
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

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text, this.color);

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CompanyForm extends StatefulWidget {
  const _CompanyForm({required this.company, required this.plans});

  final AdminCompany? company;
  final List<AdminPlanOption> plans;

  @override
  State<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends State<_CompanyForm> {
  late final _company = TextEditingController(text: widget.company?.name ?? '');
  late final _owner = TextEditingController(text: widget.company?.ownerName ?? '');
  late final _email = TextEditingController(text: widget.company?.ownerEmail ?? '');
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _planId;
  bool _busy = false;

  bool get _editing => widget.company != null;

  @override
  void dispose() {
    _company.dispose();
    _owner.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _message(String text) {
    NoticeScope.show(context, text);
  }

  Future<void> _save() async {
    if (_company.text.trim().isEmpty ||
        _owner.text.trim().isEmpty ||
        _email.text.trim().isEmpty) {
      _message('Company, owner name and email are required.');
      return;
    }
    if (!_editing && _password.text.length < 8) {
      _message('Password must be at least 8 characters.');
      return;
    }
    if (_editing && _password.text.isNotEmpty && _password.text.length < 8) {
      _message('The new password must be at least 8 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'company_name': _company.text.trim(),
        'owner_name': _owner.text.trim(),
        'owner_email': _email.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        if (_password.text.isNotEmpty) 'password': _password.text,
        if (!_editing && _planId != null) 'plan_id': _planId,
      };
      if (_editing) {
        await AdminService.updateCompany(widget.company!.id, body);
      } else {
        await AdminService.createCompany(body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _message(friendlyException(e).message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminSheetHeader(_editing ? 'Edit company' : 'New company'),
            TextField(controller: _company, decoration: adminInput('Company name')),
            const SizedBox(height: 12),
            TextField(controller: _owner, decoration: adminInput('Owner name')),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: adminInput('Owner email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: adminInput('Phone (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: adminInput(
                _editing ? 'New password (leave empty to keep)' : 'Password (min 8)',
              ),
            ),
            if (!_editing && widget.plans.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _planId,
                isExpanded: true,
                decoration: adminInput('Plan (optional)'),
                items: [
                  for (final p in widget.plans)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() => _planId = v),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_editing ? 'Save changes' : 'Create company'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditsSheet extends StatefulWidget {
  const _CreditsSheet({required this.name});

  final String name;

  @override
  State<_CreditsSheet> createState() => _CreditsSheetState();
}

class _CreditsSheetState extends State<_CreditsSheet> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_amount.text.trim());
    if (n == null || n < 1 || n > 1000000) {
      NoticeScope.show(context, 'Enter a number between 1 and 1,000,000.');
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminSheetHeader('Add credits to ${widget.name}'),
            Wrap(
              spacing: 8,
              children: [
                for (final n in [50, 100, 500, 1000])
                  ActionChip(
                    label: Text('$n'),
                    onPressed: () => setState(() => _amount.text = '$n'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: adminInput('Credits to add'),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Add credits')),
          ],
        ),
      ),
    );
  }
}

class _UsersSheet extends StatefulWidget {
  const _UsersSheet({required this.company});

  final AdminCompany company;

  @override
  State<_UsersSheet> createState() => _UsersSheetState();
}

class _UsersSheetState extends State<_UsersSheet> {
  List<AdminUser> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final u = await AdminService.companyUsers(widget.company.id);
      if (!mounted) return;
      setState(() {
        _users = u;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset(AdminUser u) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New password for ${u.name}'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password (min 8)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (password == null || !mounted) return;
    if (password.length < 8) {
      NoticeScope.show(context, 'Password must be at least 8 characters.');
      return;
    }
    try {
      final msg = await AdminService.resetUserPassword(widget.company.id, u.id, password);
      if (mounted) {
        NoticeScope.show(context, msg.isEmpty ? 'Password updated' : msg);
      }
    } catch (e) {
      if (mounted) {
        NoticeScope.show(context, friendlyException(e).message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminSheetHeader('Users of ${widget.company.name}'),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                AdminMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load users',
                  text: _error!,
                  onRetry: _load,
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final u in _users)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            u.name,
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('${u.email}  ·  ${u.role}'),
                          trailing: TextButton(
                            onPressed: () => _reset(u),
                            child: const Text('Reset password'),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
