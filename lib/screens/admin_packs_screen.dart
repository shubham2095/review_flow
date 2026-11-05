import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
import '../theme/brand.dart';
import '../widgets/admin_ui.dart';
import '../widgets/fade_in.dart';

/// Credit packs that companies can buy on the web.
class AdminPacksScreen extends StatefulWidget {
  const AdminPacksScreen({super.key});

  @override
  State<AdminPacksScreen> createState() => _AdminPacksScreenState();
}

class _AdminPacksScreenState extends State<AdminPacksScreen> {
  List<AdminCreditPack> _packs = [];
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
      final p = await AdminService.packs();
      if (!mounted) return;
      setState(() {
        _packs = p;
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

  Future<void> _form([AdminCreditPack? pack]) async {
    final saved = await showAdminSheet<bool>(context, (_) => _PackForm(pack: pack));
    if (saved == true) {
      _snack(pack == null ? 'Pack created' : 'Pack updated');
      await _load();
    }
  }

  Future<void> _run(AdminCreditPack p, Future<void> Function() action, String done) async {
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

  Future<void> _delete(AdminCreditPack p) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete ${p.name}?',
      text: 'Pause the pack instead if you only want to hide it from buyers.',
      action: 'Delete',
      danger: true,
    );
    if (!ok) return;
    await _run(p, () => AdminService.deletePack(p.id), 'Pack deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        backgroundColor: royalIndigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New pack'),
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
                      title: 'Could not load credit packs',
                      text: _error!,
                      onRetry: _load,
                    )
                  else if (_packs.isEmpty)
                    const AdminMessage(
                      icon: Icons.bolt_outlined,
                      title: 'No credit packs yet',
                    )
                  else
                    for (var i = 0; i < _packs.length; i++)
                      FadeIn(
                        delay: i < 8 ? i * 50 : 0,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                          decoration: cardDecoration(),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: star.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.bolt_rounded, color: star),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _packs[i].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        color: ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_packs[i].credits} credits  ·  ₹${_packs[i].price.toStringAsFixed(_packs[i].price % 1 == 0 ? 0 : 2)} (GST ${_packs[i].gstRate}%)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AdminBadge(
                                _packs[i].isActive ? 'Active' : 'Paused',
                                _packs[i].isActive ? good : muted,
                              ),
                              if (_busy.contains(_packs[i].id))
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
                                        _form(_packs[i]);
                                      case 'toggle':
                                        _run(
                                          _packs[i],
                                          () => AdminService.togglePack(_packs[i].id),
                                          _packs[i].isActive ? 'Pack paused' : 'Pack activated',
                                        );
                                      case 'delete':
                                        _delete(_packs[i]);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'edit', child: Text('Edit pack')),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(_packs[i].isActive ? 'Pause' : 'Activate'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete', style: TextStyle(color: bad)),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
      ),
    );
  }
}

class _PackForm extends StatefulWidget {
  const _PackForm({required this.pack});

  final AdminCreditPack? pack;

  @override
  State<_PackForm> createState() => _PackFormState();
}

class _PackFormState extends State<_PackForm> {
  late final _name = TextEditingController(text: widget.pack?.name ?? '');
  late final _credits = TextEditingController(
    text: widget.pack == null ? '' : '${widget.pack!.credits}',
  );
  late final _price = TextEditingController(
    text: widget.pack == null
        ? ''
        : widget.pack!.price.toStringAsFixed(widget.pack!.price % 1 == 0 ? 0 : 2),
  );
  late final _gst = TextEditingController(text: '${widget.pack?.gstRate ?? 18}');
  late final _sort = TextEditingController(text: '${widget.pack?.sortOrder ?? 0}');
  late bool _active = widget.pack?.isActive ?? true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _credits.dispose();
    _price.dispose();
    _gst.dispose();
    _sort.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    final credits = int.tryParse(_credits.text.trim());
    final price = double.tryParse(_price.text.trim());
    if (_name.text.trim().isEmpty || credits == null || credits < 1 || price == null || price < 0) {
      _message('Enter a name, credits (1 or more) and a price.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AdminService.savePack(widget.pack?.id, {
        'name': _name.text.trim(),
        'credits': credits,
        'price': price,
        'gst_rate': int.tryParse(_gst.text.trim()) ?? 18,
        'sort_order': int.tryParse(_sort.text.trim()) ?? 0,
        'is_active': _active,
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
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminSheetHeader(widget.pack == null ? 'New credit pack' : 'Edit credit pack'),
            TextField(controller: _name, decoration: adminInput('Name')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _credits,
                    keyboardType: TextInputType.number,
                    decoration: adminInput('Credits'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: adminInput('Price (incl. GST)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _gst,
                    keyboardType: TextInputType.number,
                    decoration: adminInput('GST %'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _sort,
                    keyboardType: TextInputType.number,
                    decoration: adminInput('Sort order'),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('Paused packs are hidden from buyers'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(widget.pack == null ? 'Create pack' : 'Save pack'),
            ),
          ],
        ),
      ),
    );
  }
}
