import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';

String _s(dynamic v) => v?.toString() ?? '';

int _i(dynamic v) => num.tryParse((v)?.toString() ?? '')?.toInt() ?? 0;

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Map<String, dynamic>> _clients = [];
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
      final list = await ApiService.instance.getList('/clients');
      if (!mounted) return;
      setState(() {
        _clients = list.cast<Map<String, dynamic>>();
        _error = null;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthService.logout();
        widget.onSignedOut();
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openClient(int id) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ClientDetailScreen(clientId: id, onSignedOut: widget.onSignedOut),
      ),
    );
    _load();
  }

  Future<void> _addClient() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _ClientSheet(),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addClient,
        backgroundColor: brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: Text(
          'Add client',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: _loading && _clients.isEmpty
            ? ListView(
                children: const [
                  SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              )
            : _error != null
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!),
                  ),
                ],
              )
            : _clients.isEmpty
            ? ListView(
                children: [
                  FadeIn(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📭', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            Text(
                              'No clients yet',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add your first client.',
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
                itemCount: _clients.length,
                itemBuilder: (_, i) {
                  final c = _clients[i];
                  final name = _s(c['name']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FadeIn(
                      delay: i < 12 ? i * 60 : 0,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openClient(_i(c['id'])),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: cardDecoration(),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: brand.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: Text(
                                    name.isEmpty ? '?' : name[0].toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      color: brand,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          color: ink,
                                        ),
                                      ),
                                      Text(
                                        _s(c['industry']).isEmpty
                                            ? 'No industry set'
                                            : _s(c['industry']),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${_i(c['locations_count'])} loc  •  ${_i(c['leads_count'])} leads',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({
    super.key,
    required this.clientId,
    required this.onSignedOut,
  });

  final int clientId;
  final VoidCallback onSignedOut;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _connectingGoogle = false;
  bool _connectingMeta = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await ApiService.instance.get('/clients/${widget.clientId}');
      if (mounted) setState(() => _data = json);
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

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _edit() async {
    final client = (_data?['client'] as Map<String, dynamic>?) ?? {};
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ClientSheet(existing: client, clientId: widget.clientId),
    );
    if (saved == true) _load();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this client?'),
        content: const Text(
          'Locations and linked data for this client will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.instance.delete('/clients/${widget.clientId}');
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  /// Google Business Profile ka OAuth ek secure in-app browser tab mein khulta hai
  /// aur connect hote hi khud app mein wapas aa jata hai — koi manual "Continue"
  /// step nahi chahiye. Client secret kabhi bhi app ke andar nahi aata; token
  /// exchange hamesha server par hi hota hai.
  Future<void> _connectGoogle() async {
    setState(() => _connectingGoogle = true);
    try {
      final res = await ApiService.instance.post('/web-session');
      final loginUrl = res['login_url'] as String;
      final next = Uri.encodeComponent('/clients/${widget.clientId}/google/connect?mobile=1');
      final result = await FlutterWebAuth2.authenticate(
        url: '$loginUrl?next=$next',
        callbackUrlScheme: 'eydia',
      );
      final params = Uri.parse(result).queryParameters;
      if (params['status'] == 'success') {
        _snack('Google connected ✅');
        _load();
      } else {
        _snack(params['message'] ?? 'Could not connect Google.');
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      // User closed the browser tab, or the OS cancelled the flow.
      _snack('Google connection was cancelled.');
    } finally {
      if (mounted) setState(() => _connectingGoogle = false);
    }
  }

  /// Meta (Facebook/Instagram) OAuth bhi ab Google jaisa hi secure in-app
  /// browser tab mein khulta hai aur connect hote hi khud app mein wapas
  /// aa jata hai.
  Future<void> _connectMeta() async {
    setState(() => _connectingMeta = true);
    try {
      final res = await ApiService.instance.post('/web-session');
      final loginUrl = res['login_url'] as String;
      final next = Uri.encodeComponent('/clients/${widget.clientId}/meta/connect?mobile=1');
      final result = await FlutterWebAuth2.authenticate(
        url: '$loginUrl?next=$next',
        callbackUrlScheme: 'eydia',
      );
      final params = Uri.parse(result).queryParameters;
      if (params['status'] == 'success') {
        _snack('Meta connected ✅');
        _load();
      } else {
        _snack(params['message'] ?? 'Could not connect Meta.');
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Meta connection was cancelled.');
    } finally {
      if (mounted) setState(() => _connectingMeta = false);
    }
  }

  Future<void> _disconnect(String provider) async {
    try {
      await ApiService.instance.delete(
        '/clients/${widget.clientId}/$provider/disconnect',
      );
      _snack('Disconnected');
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _addLocation() async {
    final title = TextEditingController();
    final address = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final titleText = title.text.trim();
    final addressText = address.text.trim();
    title.dispose();
    address.dispose();
    if (ok != true) return;
    if (titleText.isEmpty) {
      _snack('Location name is required');
      return;
    }
    try {
      await ApiService.instance.post(
        '/clients/${widget.clientId}/locations',
        body: {
          'title': titleText,
          if (addressText.isNotEmpty) 'address': addressText,
        },
      );
      _snack('Location added ✅');
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _deleteLocation(int locationId) async {
    try {
      await ApiService.instance.delete(
        '/clients/${widget.clientId}/locations/$locationId',
      );
      _snack('Location removed');
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _importLocations() async {
    try {
      final res = await ApiService.instance.post(
        '/clients/${widget.clientId}/import-locations',
      );
      _snack('Imported ${res['imported'] ?? 0} location(s) ✅');
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final client = (d?['client'] as Map<String, dynamic>?) ?? {};
    final stats = (d?['stats'] as Map<String, dynamic>?) ?? {};
    final locations = ((d?['locations'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    final recent = ((d?['recent_reviews'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    final googleOn = d?['google_connected'] == true;
    final metaOn = d?['meta_connected'] == true;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        title: Text(
          _s(client['name']).isEmpty ? 'Client' : _s(client['name']),
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(onPressed: _edit, icon: const Icon(Icons.edit_rounded)),
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : d == null
          ? const Center(child: Text('Could not load client'))
          : RefreshIndicator(
              color: brand,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  FadeIn(
                    child: Row(
                      children: [
                        _Stat(
                          label: 'Reviews',
                          value: '${stats['total'] ?? 0}',
                          color: brand,
                        ),
                        const SizedBox(width: 8),
                        _Stat(
                          label: 'Avg rating',
                          value: '${stats['avg'] ?? 0}',
                          color: star,
                        ),
                        const SizedBox(width: 8),
                        _Stat(
                          label: 'Replied',
                          value: '${stats['replied'] ?? 0}',
                          color: good,
                        ),
                        const SizedBox(width: 8),
                        _Stat(
                          label: 'Pending',
                          value: '${stats['pending'] ?? 0}',
                          color: warn,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeIn(
                    delay: 90,
                    child: _Card(
                      title: 'Connections',
                      child: Column(
                        children: [
                          _ConnRow(
                            label: 'Google Business Profile',
                            connected: googleOn,
                            note: googleOn
                                ? 'Connected'
                                : (_connectingGoogle ? 'Connecting…' : 'Not connected'),
                            onConnect: (googleOn || _connectingGoogle) ? null : _connectGoogle,
                            onDisconnect: googleOn
                                ? () => _disconnect('google')
                                : null,
                          ),
                          const SizedBox(height: 8),
                          _ConnRow(
                            label: 'Meta (Facebook / Instagram)',
                            connected: metaOn,
                            note: metaOn
                                ? 'Connected'
                                : (_connectingMeta ? 'Connecting…' : 'Not connected'),
                            onConnect: (metaOn || _connectingMeta) ? null : _connectMeta,
                            onDisconnect: metaOn
                                ? () => _disconnect('meta')
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  FadeIn(
                    delay: 160,
                    child: _Card(
                      title: 'Locations (${locations.length})',
                      trailing: TextButton.icon(
                        onPressed: _addLocation,
                        icon: const Icon(
                          Icons.add_location_alt_rounded,
                          size: 18,
                        ),
                        label: const Text('Add'),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (locations.isEmpty)
                            Text(
                              'No locations yet.',
                              style: GoogleFonts.plusJakartaSans(color: muted),
                            ),
                          for (final l in locations)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Text(
                                '🏪',
                                style: TextStyle(fontSize: 18),
                              ),
                              title: Text(
                                _s(l['title']),
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              subtitle: Text(
                                _s(l['address']),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: bad,
                                ),
                                onPressed: () => _deleteLocation(_i(l['id'])),
                              ),
                            ),
                          if (googleOn) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _importLocations,
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 18,
                              ),
                              label: const Text('Import locations from Google'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (recent.isNotEmpty)
                    FadeIn(
                      delay: 230,
                      child: _Card(
                        title: 'Recent reviews',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final r in recent)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_s(r['reviewer_name'])}  •  ${'★' * _i(r['star_rating'])}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                      ),
                                    ),
                                    if (_s(r['comment']).isNotEmpty)
                                      Text(
                                        _s(r['comment']),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: muted,
                                        ),
                                      ),
                                  ],
                                ),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: cardDecoration(),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: ink,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ConnRow extends StatelessWidget {
  const _ConnRow({
    required this.label,
    required this.connected,
    required this.note,
    this.onConnect,
    this.onDisconnect,
  });

  final String label;
  final bool connected;
  final String note;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final color = connected ? good : warn;
    return Row(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Icon(
            connected ? Icons.check_circle_rounded : Icons.link_off_rounded,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              Text(
                note,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        if (onConnect != null)
          FilledButton.tonal(
            onPressed: onConnect,
            child: const Text('Connect'),
          ),
        if (onDisconnect != null)
          TextButton(
            onPressed: onDisconnect,
            child: const Text('Disconnect', style: TextStyle(color: bad)),
          ),
      ],
    );
  }
}

class _ClientSheet extends StatefulWidget {
  const _ClientSheet({this.existing, this.clientId});

  final Map<String, dynamic>? existing;
  final int? clientId;

  @override
  State<_ClientSheet> createState() => _ClientSheetState();
}

class _ClientSheetState extends State<_ClientSheet> {
  late final _name = TextEditingController(text: _s(widget.existing?['name']));
  late final _industry = TextEditingController(
    text: _s(widget.existing?['industry']),
  );
  late final _phone = TextEditingController(
    text: _s(widget.existing?['phone']),
  );
  late final _email = TextEditingController(
    text: _s(widget.existing?['email']),
  );
  bool _busy = false;

  bool get _isEdit => widget.clientId != null;

  @override
  void dispose() {
    _name.dispose();
    _industry.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _message('Name is required');
      return;
    }
    final body = {
      'name': _name.text.trim(),
      'industry': _industry.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
    };
    setState(() => _busy = true);
    try {
      if (_isEdit) {
        await ApiService.instance.put(
          '/clients/${widget.clientId}',
          body: body,
        );
      } else {
        await ApiService.instance.post('/clients', body: body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
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
              _isEdit ? 'Edit client' : 'Add client',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: ink,
              ),
            ),
            const SizedBox(height: 14),
            TextField(controller: _name, decoration: _dec('Business name *')),
            const SizedBox(height: 12),
            TextField(controller: _industry, decoration: _dec('Industry')),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _dec('Phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _dec('Email'),
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
                  : Text(_isEdit ? 'Save changes' : 'Add client'),
            ),
          ],
        ),
      ),
    );
  }
}
