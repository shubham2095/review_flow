import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
import '../theme/brand.dart';
import '../widgets/admin_ui.dart';
import '../widgets/fade_in.dart';

String _label(String key) => key.replaceAll('_', ' ');

/// Plans: price, AI credits, limits and the features each plan unlocks.
class AdminPlansScreen extends StatefulWidget {
  const AdminPlansScreen({super.key});

  @override
  State<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends State<AdminPlansScreen> {
  AdminPlansData? _data;
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AdminService.plans();
      if (!mounted) return;
      setState(() {
        _data = d;
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _form([AdminPlan? plan]) async {
    final d = _data;
    if (d == null) return;
    final saved = await showAdminSheet<bool>(
      context,
      (_) => _PlanForm(plan: plan, limitKeys: d.limitKeys, featureKeys: d.featureKeys),
    );
    if (saved == true) {
      _snack(plan == null ? 'Plan created' : 'Plan updated');
      await _load();
    }
  }

  Future<void> _run(AdminPlan p, Future<void> Function() action, String done) async {
    setState(() => _busy.add(p.id));
    try {
      await action();
      _snack(done);
      await _load();
    } catch (e) {
      _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  Future<void> _delete(AdminPlan p) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete ${p.name}?',
      text: 'Plans assigned to companies cannot be deleted. Deactivate those instead.',
      action: 'Delete',
      danger: true,
    );
    if (!ok) return;
    await _run(p, () => AdminService.deletePlan(p.id), 'Plan deleted');
  }

  @override
  Widget build(BuildContext context) {
    final plans = _data?.plans ?? [];

    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _data == null ? null : () => _form(),
        backgroundColor: royalIndigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New plan'),
      ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_error != null)
                    AdminMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load plans',
                      text: _error!,
                      onRetry: _load,
                    )
                  else if (plans.isEmpty)
                    const AdminMessage(
                      icon: Icons.workspace_premium_outlined,
                      title: 'No plans yet',
                      text: 'Create a plan so companies can subscribe.',
                    )
                  else
                    for (var i = 0; i < plans.length; i++)
                      FadeIn(
                        delay: i < 8 ? i * 50 : 0,
                        child: _PlanCard(
                          plan: plans[i],
                          busy: _busy.contains(plans[i].id),
                          onEdit: () => _form(plans[i]),
                          onToggle: () => _run(
                            plans[i],
                            () => AdminService.togglePlan(plans[i].id),
                            plans[i].isActive ? 'Plan deactivated' : 'Plan activated',
                          ),
                          onDelete: () => _delete(plans[i]),
                        ),
                      ),
                ],
              ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final AdminPlan plan;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = plan;
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
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: ink,
                  ),
                ),
              ),
              AdminBadge(p.isActive ? 'Active' : 'Inactive', p.isActive ? good : muted),
              if (!p.isPublic) ...[
                const SizedBox(width: 6),
                const AdminBadge('Hidden', warn),
              ],
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
                      case 'toggle':
                        onToggle();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit plan')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(p.isActive ? 'Deactivate' : 'Activate'),
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
                  '₹${p.price.toStringAsFixed(p.price % 1 == 0 ? 0 : 2)} / ${p.billingPeriod}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: brand,
                  ),
                ),
                if (p.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    p.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _Stat(Icons.bolt_rounded, '${p.credits} credits'),
                    _Stat(Icons.extension_rounded, '${p.modules} modules'),
                    _Stat(Icons.people_alt_rounded, '${p.subscribers} subscribers'),
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

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
      ],
    );
  }
}

class _PlanForm extends StatefulWidget {
  const _PlanForm({
    required this.plan,
    required this.limitKeys,
    required this.featureKeys,
  });

  final AdminPlan? plan;
  final List<String> limitKeys;
  final List<String> featureKeys;

  @override
  State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> {
  late final _name = TextEditingController(text: widget.plan?.name ?? '');
  late final _description = TextEditingController(text: widget.plan?.description ?? '');
  late final _price = TextEditingController(
    text: widget.plan == null
        ? ''
        : widget.plan!.price.toStringAsFixed(widget.plan!.price % 1 == 0 ? 0 : 2),
  );
  late final _sort = TextEditingController(text: '${widget.plan?.sortOrder ?? 0}');
  late String _period = widget.plan?.billingPeriod ?? 'monthly';
  late bool _active = widget.plan?.isActive ?? true;
  late bool _public = widget.plan?.isPublic ?? true;
  late final List<String> _limitKeys = {
    ...widget.limitKeys,
    ...?widget.plan?.limits.keys,
  }.toList();
  late final List<String> _featureKeys = {
    ...widget.featureKeys,
    ...?widget.plan?.features.keys,
  }.toList();
  final Map<String, TextEditingController> _limits = {};
  late final Map<String, bool> _features = {
    for (final k in _featureKeys) k: widget.plan?.features[k] ?? false,
  };
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final k in _limitKeys) {
      final v = widget.plan?.limits[k];
      _limits[k] = TextEditingController(text: (v == null || v < 0) ? '' : '$v');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _sort.dispose();
    for (final c in _limits.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _message('Plan name is required.');
      return;
    }
    final price = double.tryParse(_price.text.trim().isEmpty ? '0' : _price.text.trim());
    if (price == null || price < 0) {
      _message('Enter a valid price.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AdminService.savePlan(widget.plan?.id, {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'billing_period': _period,
        'price': price,
        'currency': widget.plan?.currency ?? 'INR',
        // Empty means unlimited; the API stores that as -1.
        'limits': {
          for (final e in _limits.entries)
            e.key: e.value.text.trim().isEmpty ? -1 : (int.tryParse(e.value.text.trim()) ?? -1),
        },
        'features': _features,
        'is_active': _active,
        'is_public': _public,
        'sort_order': int.tryParse(_sort.text.trim()) ?? 0,
      });
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
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminSheetHeader(widget.plan == null ? 'New plan' : 'Edit plan'),
              TextField(controller: _name, decoration: adminInput('Plan name')),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: adminInput('Description'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: adminInput('Price (incl. GST)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _period,
                      decoration: adminInput('Billing'),
                      items: const [
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                      ],
                      onChanged: (v) => setState(() => _period = v ?? 'monthly'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sort,
                keyboardType: TextInputType.number,
                decoration: adminInput('Sort order'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('Inactive plans cannot be bought'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show on pricing page'),
                value: _public,
                onChanged: (v) => setState(() => _public = v),
              ),
              const SizedBox(height: 8),
              Text(
                'Limits (empty = unlimited)',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
              ),
              const SizedBox(height: 10),
              for (final k in _limitKeys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _limits[k],
                    keyboardType: TextInputType.number,
                    decoration: adminInput(_label(k), hint: 'Unlimited'),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'Features',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
              ),
              for (final k in _featureKeys)
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_label(k)),
                  value: _features[k] ?? false,
                  onChanged: (v) => setState(() => _features[k] = v),
                ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(widget.plan == null ? 'Create plan' : 'Save plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
