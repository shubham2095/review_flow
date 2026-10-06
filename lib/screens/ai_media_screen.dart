import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';

String _s(dynamic v) => v?.toString() ?? '';

Uint8List? _decodeDataUri(String data) {
  final comma = data.indexOf(',');
  if (!data.startsWith('data:') || comma < 0) return null;
  try {
    return base64Decode(data.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

class AiMediaScreen extends StatefulWidget {
  const AiMediaScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<AiMediaScreen> createState() => _AiMediaScreenState();
}

class _AiMediaScreenState extends State<AiMediaScreen> {
  List<Map<String, dynamic>> _items = [];
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final list = await ApiService.instance.getList('/ai-media');
      if (!mounted) return;
      setState(() {
        _items = list.cast<Map<String, dynamic>>();
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

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _generate() async {
    final prompt = await showDialog<String>(
      context: context,
      builder: (_) => const _PromptDialog(),
    );
    if (prompt == null || prompt.isEmpty) return;

    setState(() => _busy = true);
    try {
      final res = await ApiService.instance.post('/ai-media/generate', body: {'prompt': prompt});
      final media = (res['media'] as Map?)?.cast<String, dynamic>();
      if (media != null && mounted) setState(() => _items.insert(0, media));
      _snack(res['success'] == true ? 'Image generated ✅' : 'Image generated with fallback (AI was busy)');
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openItem(Map<String, dynamic> item) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _MediaActions(item: item),
    );
    if (result == 'deleted') {
      setState(() => _items.removeWhere((m) => m['id'] == item['id']));
      _snack('Image deleted');
    } else if (result == 'added') {
      _snack('Added to Posts & Photos as a draft');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _generate,
        backgroundColor: brand,
        foregroundColor: Colors.white,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text('Generate', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: _loading && _items.isEmpty
            ? ListView(children: const [SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))])
            : _error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('😕 $_error'))])
                : _items.isEmpty
                    ? ListView(children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('🖼️  No AI images yet. Tap Generate to create one.')),
                        ),
                      ])
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final item = _items[i];
                          final bytes = _decodeDataUri(_s(item['image_data']));
                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _openItem(item),
                            child: Container(
                              decoration: cardDecoration(),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: bytes == null
                                        ? const Center(child: Text('🖼️'))
                                        : Image.memory(
                                            bytes,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => const Center(child: Text('🖼️')),
                                          ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                      _s(item['prompt']),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: ink),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

/// Owns its own controller so it is disposed only after the dialog is gone.
class _PromptDialog extends StatefulWidget {
  const _PromptDialog();

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate image with AI'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'Describe the image, e.g. a cozy cafe with morning light'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Generate'),
        ),
      ],
    );
  }
}

class _MediaActions extends StatefulWidget {
  const _MediaActions({required this.item});

  final Map<String, dynamic> item;

  @override
  State<_MediaActions> createState() => _MediaActionsState();
}

class _MediaActionsState extends State<_MediaActions> {
  bool _busy = false;

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addToPhotos() async {
    List<Map<String, dynamic>> locations;
    try {
      locations = (await ApiService.instance.getList('/reviews')).cast<Map<String, dynamic>>();
    } on ApiException catch (e) {
      _message(e.message);
      return;
    }
    if (locations.isEmpty) {
      _message('No locations found. Connect Google first.');
      return;
    }
    if (!mounted) return;
    final locationId = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add to which location?'),
        children: [
          for (final l in locations)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, num.tryParse((l['id'])?.toString() ?? '')?.toInt()),
              child: Text(_s(l['title'])),
            ),
        ],
      ),
    );
    if (locationId == null) return;

    setState(() => _busy = true);
    try {
      await ApiService.instance.post('/ai-media/${widget.item['id']}/use-as-photo', body: {
        'gbp_location_id': locationId,
      });
      if (mounted) Navigator.of(context).pop('added');
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await ApiService.instance.delete('/ai-media/${widget.item['id']}');
      if (mounted) Navigator.of(context).pop('deleted');
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_s(widget.item['prompt']), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _addToPhotos,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('Add to Posts & Photos'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded, color: bad),
            label: const Text('Delete image', style: TextStyle(color: bad)),
          ),
        ],
      ),
    );
  }
}
