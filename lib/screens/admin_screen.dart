import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';

String _s(dynamic v) => v?.toString() ?? '';

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

double _n(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(_s(v)) ?? 0;
}

const _roles = {'SUPER_ADMIN': 'Super admin', 'CLIENT_OWNER': 'Client owner'};

/// Super admin panel: overview, users, plans, credit packs, and credit top-up.
/// Only shown in the app for SUPER_ADMIN accounts. The API enforces the same role.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Future<void> _handle(ApiException e) async {
    if (e.statusCode == 401) {
      await AuthService.logout();
      widget.onSignedOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: surface,
        body: Column(
          children: [
            Material(
              color: Colors.white,
              child: TabBar(
                isScrollable: true,
                labelColor: brand,
                unselectedLabelColor: muted,
                indicatorColor: brand,
                labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Users'),
                  Tab(text: 'Plans'),
                  Tab(text: 'Credit packs'),
                  Tab(text: 'Top-up'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _OverviewTab(onError: _handle),
                  _UsersTab(onError: _handle),
                  _PlansTab(onError: _handle),
                  _PacksTab(onError: _handle),
                  _TopupTab(onError: _handle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _ErrorHandler = Future<void> Function(ApiException e);

/// Shared list loader used by every admin tab.
mixin _Loader<T extends StatefulWidget> on State<T> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];

  Future<void> loadList(String path, _ErrorHandler onError) async {
    if (mounted) setState(() => loading = true);
    try {
      final list = await ApiService.instance.getList(path);
      if (mounted) {
        setState(() {
          items = list.cast<Map<String, dynamic>>();
          error = null;
        });
      }
    } on ApiException catch (e) {
      await onError(e);
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Widget _errorBox(String message, VoidCallback onRetry) {
  return Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('😕 $message', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

InputDecoration _dec(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: muted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: ink)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: cardDecoration(),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ---------- Overview ----------

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({required this.onError});

  final _ErrorHandler onError;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  Map<String, dynamic>? _data;
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
      final json = await ApiService.instance.get('/admin/overview');
      if (mounted) setState(() => _data = json);
    } on ApiException catch (e) {
      await widget.onError(e);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = (_data?['stats'] as Map?) ?? {};
    final recent = ((_data?['recent_users'] as List?) ?? []).cast<Map<String, dynamic>>();

    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_loading && _data == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            _errorBox(_error!, _load)
          else ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _StatTile('🏢', 'Agencies', '${stats['agencies'] ?? 0}', brand),
                _StatTile('👤', 'Users', '${stats['users'] ?? 0}', brandDeep),
                _StatTile('🏪', 'Clients', '${stats['clients'] ?? 0}', good),
                _StatTile('⭐', 'Reviews', '${stats['reviews'] ?? 0}', star),
              ],
            ),
            const SizedBox(height: 16),
            Text('Recent users', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 8),
            for (final u in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: cardDecoration(),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_s(u['name']), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink)),
                            Text(_s(u['email']), style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted)),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(
                          _roles[_s(u['role'])] ?? _s(u['role']),
                          textAlign: TextAlign.end,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: brand),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.emoji, this.label, this.value, this.color);

  final String emoji;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 22, color: color),
          ),
        ],
      ),
    );
  }
}

// ---------- Users ----------

class _UsersTab extends StatefulWidget {
  const _UsersTab({required this.onError});

  final _ErrorHandler onError;

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> with _Loader<_UsersTab> {
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await loadList('/admin/users', widget.onError);
    try {
      _plans = (await ApiService.instance.getList('/admin/plans')).cast<Map<String, dynamic>>();
    } on ApiException catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _openSheet({Map<String, dynamic>? user}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _UserSheet(user: user, plans: _plans),
    );
    if (changed == true) _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        backgroundColor: brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text('Add user', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _loadAll,
        child: loading && items.isEmpty
            ? ListView(children: const [SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))])
            : error != null
                ? ListView(children: [_errorBox(error!, _loadAll)])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      for (final u in items)
                        _Card(
                          onTap: () => _openSheet(user: u),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_s(u['name']),
                                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink)),
                                    Text(_s(u['email']), style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted)),
                                    Text(
                                      '${_s(u['agency'])}${_s(u['plan']).isEmpty ? '' : '  •  ${_s(u['plan'])}'}',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                                    ),
                                  ],
                                ),
                              ),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 110),
                                child: Text(
                                  _roles[_s(u['role'])] ?? _s(u['role']),
                                  textAlign: TextAlign.end,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: brand),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _UserSheet extends StatefulWidget {
  const _UserSheet({this.user, required this.plans});

  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> plans;

  @override
  State<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<_UserSheet> {
  late final _name = TextEditingController(text: _s(widget.user?['name']));
  late final _email = TextEditingController(text: _s(widget.user?['email']));
  final _password = TextEditingController();
  late String _role = _s(widget.user?['role']).isEmpty ? 'CLIENT_OWNER' : _s(widget.user?['role']);
  int? _planId;
  bool _busy = false;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final current = _s(widget.user?['plan']);
      for (final p in widget.plans) {
        if (_s(p['name']) == current) _planId = _i(p['id']);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
      _snack(context, 'Name and email are required');
      return;
    }
    if (!_isEdit && _password.text.length < 8) {
      _snack(context, 'Password must be at least 8 characters');
      return;
    }
    setState(() => _busy = true);
    try {
      final body = {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'role': _role,
        if (_password.text.isNotEmpty) 'password': _password.text,
        if (_planId != null) 'plan_id': _planId,
      };
      if (_isEdit) {
        await ApiService.instance.put('/admin/users/${_i(widget.user!['id'])}', body: body);
      } else {
        await ApiService.instance.post('/admin/users', body: body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await ApiService.instance.delete('/admin/users/${_i(widget.user!['id'])}');
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: _isEdit ? 'Edit user' : 'Add user',
      children: [
        TextField(controller: _name, decoration: _dec('Name *')),
        const SizedBox(height: 12),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: _dec('Email *')),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: _dec(_isEdit ? 'New password' : 'Password *', hint: _isEdit ? 'Leave empty to keep current' : null),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _role,
          decoration: _dec('Role', hint: 'Super admin gets the admin panel. Client owner sees only the client app.'),
          items: [for (final r in _roles.entries) DropdownMenuItem(value: r.key, child: Text(r.value))],
          onChanged: (v) => setState(() => _role = v ?? _role),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
              isExpanded: true,
              initialValue: _planId,
          decoration: _dec('Plan (optional)'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('No change')),
            for (final p in widget.plans) DropdownMenuItem<int?>(value: _i(p['id']), child: Text(_s(p['name']))),
          ],
          onChanged: (v) => setState(() => _planId = v),
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
              : Text(_isEdit ? 'Save changes' : 'Create user'),
        ),
        if (_isEdit && _s(widget.user?['role']) != 'SUPER_ADMIN')
          TextButton.icon(
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded, color: bad),
            label: const Text('Delete user', style: TextStyle(color: bad)),
          ),
      ],
    );
  }
}

// ---------- Plans ----------

class _PlansTab extends StatefulWidget {
  const _PlansTab({required this.onError});

  final _ErrorHandler onError;

  @override
  State<_PlansTab> createState() => _PlansTabState();
}

class _PlansTabState extends State<_PlansTab> with _Loader<_PlansTab> {
  @override
  void initState() {
    super.initState();
    loadList('/admin/plans', widget.onError);
  }

  Future<void> _openSheet({Map<String, dynamic>? plan}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _PlanSheet(plan: plan),
    );
    if (changed == true) loadList('/admin/plans', widget.onError);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        backgroundColor: brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('New plan', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: () => loadList('/admin/plans', widget.onError),
        child: loading && items.isEmpty
            ? ListView(children: const [SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))])
            : error != null
                ? ListView(children: [_errorBox(error!, () => loadList('/admin/plans', widget.onError))])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      for (final p in items)
                        _Card(
                          onTap: () => _openSheet(plan: p),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_s(p['name']),
                                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink)),
                                    Text(
                                      '₹${_n(p['price']).toStringAsFixed(0)} / month  •  ${_i(p['credits'])} credits  •  GST ${_i(p['gst_rate'])}%',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                                    ),
                                    Text('Code: ${_s(p['code'])}',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted)),
                                  ],
                                ),
                              ),
                              _ActiveBadge(active: p['is_active'] == true),
                            ],
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? good : muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(
        active ? 'Active' : 'Hidden',
        style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _PlanSheet extends StatefulWidget {
  const _PlanSheet({this.plan});

  final Map<String, dynamic>? plan;

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  late final _name = TextEditingController(text: _s(widget.plan?['name']));
  late final _code = TextEditingController(text: _s(widget.plan?['code']));
  late final _price = TextEditingController(text: widget.plan == null ? '' : _n(widget.plan!['price']).toStringAsFixed(0));
  late final _gst = TextEditingController(text: widget.plan == null ? '18' : _i(widget.plan!['gst_rate']).toString());
  late final _credits = TextEditingController(text: widget.plan == null ? '' : _i(widget.plan!['credits']).toString());
  late final _sort = TextEditingController(text: widget.plan == null ? '0' : _i(widget.plan!['sort']).toString());
  late final _features = TextEditingController(
    text: ((widget.plan?['features'] as List?) ?? []).map((e) => e.toString()).join('\n'),
  );
  late bool _active = widget.plan == null ? true : widget.plan!['is_active'] == true;
  bool _busy = false;

  bool get _isEdit => widget.plan != null;

  @override
  void dispose() {
    for (final c in [_name, _code, _price, _gst, _credits, _sort, _features]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _code.text.trim().isEmpty) {
      _snack(context, 'Name and code are required');
      return;
    }
    setState(() => _busy = true);
    try {
      final body = {
        'name': _name.text.trim(),
        'code': _code.text.trim(),
        'price': int.tryParse(_price.text.trim()) ?? 0,
        'gst_rate': int.tryParse(_gst.text.trim()) ?? 18,
        'credits': int.tryParse(_credits.text.trim()) ?? 0,
        'sort': int.tryParse(_sort.text.trim()) ?? 0,
        'features': _features.text,
        // Permissions edit list nahi hai, isliye existing values hi wapas bhejte hain.
        'permissions': (widget.plan?['permissions'] as List?) ?? [],
        'is_active': _active,
      };
      if (_isEdit) {
        await ApiService.instance.put('/admin/plans/${_i(widget.plan!['id'])}', body: body);
      } else {
        await ApiService.instance.post('/admin/plans', body: body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await ApiService.instance.delete('/admin/plans/${_i(widget.plan!['id'])}');
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: _isEdit ? 'Edit plan' : 'New plan',
      children: [
        TextField(controller: _name, decoration: _dec('Name *')),
        const SizedBox(height: 10),
        TextField(controller: _code, decoration: _dec('Code *', hint: 'e.g. GROWTH')),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: _dec('Price (₹)'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(controller: _gst, keyboardType: TextInputType.number, decoration: _dec('GST %')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(controller: _credits, keyboardType: TextInputType.number, decoration: _dec('Credits/month')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(controller: _sort, keyboardType: TextInputType.number, decoration: _dec('Sort order')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _features,
          maxLines: 4,
          decoration: _dec('Features', hint: 'One feature per line'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Visible to clients'),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEdit ? 'Save changes' : 'Create plan'),
        ),
        if (_isEdit)
          TextButton.icon(
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded, color: bad),
            label: const Text('Delete plan', style: TextStyle(color: bad)),
          ),
      ],
    );
  }
}

// ---------- Credit packs ----------

class _PacksTab extends StatefulWidget {
  const _PacksTab({required this.onError});

  final _ErrorHandler onError;

  @override
  State<_PacksTab> createState() => _PacksTabState();
}

class _PacksTabState extends State<_PacksTab> with _Loader<_PacksTab> {
  @override
  void initState() {
    super.initState();
    loadList('/admin/credit-packages', widget.onError);
  }

  Future<void> _openSheet({Map<String, dynamic>? pack}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _PackSheet(pack: pack),
    );
    if (changed == true) loadList('/admin/credit-packages', widget.onError);
  }

  Future<void> _toggle(Map<String, dynamic> pack) async {
    try {
      await ApiService.instance.post('/admin/credit-packages/${_i(pack['id'])}/toggle');
      loadList('/admin/credit-packages', widget.onError);
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        backgroundColor: brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('New pack', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: () => loadList('/admin/credit-packages', widget.onError),
        child: loading && items.isEmpty
            ? ListView(children: const [SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))])
            : error != null
                ? ListView(children: [_errorBox(error!, () => loadList('/admin/credit-packages', widget.onError))])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      for (final p in items)
                        _Card(
                          onTap: () => _openSheet(pack: p),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_s(p['name']),
                                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink)),
                                    Text(
                                      '${_i(p['credits'])} credits  •  ₹${_n(p['price']).toStringAsFixed(0)}  •  GST ${_i(p['gst_rate'])}%',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _toggle(p),
                                child: Text(p['is_active'] == true ? 'Pause' : 'Activate'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _PackSheet extends StatefulWidget {
  const _PackSheet({this.pack});

  final Map<String, dynamic>? pack;

  @override
  State<_PackSheet> createState() => _PackSheetState();
}

class _PackSheetState extends State<_PackSheet> {
  late final _name = TextEditingController(text: _s(widget.pack?['name']));
  late final _credits = TextEditingController(text: widget.pack == null ? '' : _i(widget.pack!['credits']).toString());
  late final _price = TextEditingController(text: widget.pack == null ? '' : _n(widget.pack!['price']).toStringAsFixed(0));
  late final _gst = TextEditingController(text: widget.pack == null ? '18' : _i(widget.pack!['gst_rate']).toString());
  late final _sort = TextEditingController(text: widget.pack == null ? '0' : _i(widget.pack!['sort']).toString());
  late bool _active = widget.pack == null ? true : widget.pack!['is_active'] == true;
  bool _busy = false;

  bool get _isEdit => widget.pack != null;

  @override
  void dispose() {
    for (final c in [_name, _credits, _price, _gst, _sort]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || (int.tryParse(_credits.text.trim()) ?? 0) < 1) {
      _snack(context, 'Name and credits (at least 1) are required');
      return;
    }
    setState(() => _busy = true);
    try {
      final body = {
        'name': _name.text.trim(),
        'credits': int.tryParse(_credits.text.trim()) ?? 0,
        'price': int.tryParse(_price.text.trim()) ?? 0,
        'gst_rate': int.tryParse(_gst.text.trim()) ?? 18,
        'sort': int.tryParse(_sort.text.trim()) ?? 0,
        'is_active': _active,
      };
      if (_isEdit) {
        await ApiService.instance.put('/admin/credit-packages/${_i(widget.pack!['id'])}', body: body);
      } else {
        await ApiService.instance.post('/admin/credit-packages', body: body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await ApiService.instance.delete('/admin/credit-packages/${_i(widget.pack!['id'])}');
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: _isEdit ? 'Edit credit pack' : 'New credit pack',
      children: [
        TextField(controller: _name, decoration: _dec('Name *')),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(controller: _credits, keyboardType: TextInputType.number, decoration: _dec('Credits *')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(controller: _price, keyboardType: TextInputType.number, decoration: _dec('Price (₹)')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: TextField(controller: _gst, keyboardType: TextInputType.number, decoration: _dec('GST %'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _sort, keyboardType: TextInputType.number, decoration: _dec('Sort order'))),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Available to buy'),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEdit ? 'Save changes' : 'Create pack'),
        ),
        if (_isEdit)
          TextButton.icon(
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded, color: bad),
            label: const Text('Delete pack', style: TextStyle(color: bad)),
          ),
      ],
    );
  }
}

// ---------- Top-up ----------

class _TopupTab extends StatefulWidget {
  const _TopupTab({required this.onError});

  final _ErrorHandler onError;

  @override
  State<_TopupTab> createState() => _TopupTabState();
}

class _TopupTabState extends State<_TopupTab> {
  List<Map<String, dynamic>> _agencies = [];
  int? _agencyId;
  final _credits = TextEditingController();
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadAgencies();
  }

  @override
  void dispose() {
    _credits.dispose();
    super.dispose();
  }

  Future<void> _loadAgencies() async {
    try {
      final users = (await ApiService.instance.getList('/admin/users')).cast<Map<String, dynamic>>();
      final seen = <int, String>{};
      for (final u in users) {
        final id = _i(u['agency_id']);
        if (id > 0) seen[id] = _s(u['agency']).isEmpty ? 'Agency $id' : _s(u['agency']);
      }
      if (!mounted) return;
      setState(() {
        _agencies = [for (final e in seen.entries) {'id': e.key, 'name': e.value}];
        if (_agencies.isNotEmpty) _agencyId = _i(_agencies.first['id']);
      });
    } on ApiException catch (e) {
      await widget.onError(e);
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _topup() async {
    final credits = int.tryParse(_credits.text.trim()) ?? 0;
    if (_agencyId == null || credits < 1) {
      _snack(context, 'Pick an agency and enter credits (at least 1)');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ApiService.instance.post('/admin/topup', body: {'agency_id': _agencyId, 'credits': credits});
      if (!mounted) return;
      _credits.clear();
      _snack(context, 'Added $credits credits. New balance: ${_i(res['balance'])}');
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_loading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (_agencies.isEmpty)
          const Text('No agencies found.')
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Add AI credits to an agency',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _agencyId,
                  decoration: _dec('Agency'),
                  items: [
                    for (final a in _agencies) DropdownMenuItem(value: _i(a['id']), child: Text(_s(a['name']))),
                  ],
                  onChanged: (v) => setState(() => _agencyId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _credits,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Credits to add'),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _busy ? null : _topup,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add credits'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Admin ka ek section dikhata hai. Sidebar (AdminShell) isi se navigate karta hai.
class AdminSectionView extends StatelessWidget {
  const AdminSectionView({super.key, required this.section, required this.onSignedOut});

  final int section; // 0 Overview, 1 Users, 2 Plans, 3 Credit packs, 4 Top-up
  final VoidCallback onSignedOut;

  Future<void> _handle(ApiException e) async {
    if (e.statusCode == 401) {
      await AuthService.logout();
      onSignedOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case 0:
        return _OverviewTab(onError: _handle);
      case 1:
        return _UsersTab(onError: _handle);
      case 2:
        return _PlansTab(onError: _handle);
      case 3:
        return _PacksTab(onError: _handle);
      default:
        return _TopupTab(onError: _handle);
    }
  }
}
