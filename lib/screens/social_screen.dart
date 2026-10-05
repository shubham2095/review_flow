import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/social_models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  SocialBoard? _board;
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
      final json = await ApiService.instance.get('/social');
      if (!mounted) return;
      setState(() {
        _board = SocialBoard.fromJson(json);
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

  Future<void> _compose() async {
    final board = _board;
    if (board == null || board.clients.isEmpty) {
      _snack('Add a client first');
      return;
    }
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ComposeSheet(clients: board.clients),
    );
    if (result == 'published') {
      _snack('Post published ✅');
    } else if (result == 'scheduled') {
      _snack('Post scheduled 🗓️');
    } else if (result == 'failed') {
      _snack('Post was not published. Check the error in the list');
    }
    if (result != null) _load();
  }

  Future<void> _retry(SocialPostItem post) async {
    try {
      final res = await ApiService.instance.post('/social/${post.id}/retry');
      _snack(res['success'] == true ? 'Post published again ✅' : 'Retry failed: ${res['error'] ?? ''}');
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;

    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: board == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _compose,
              backgroundColor: brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_rounded),
              label: Text(
                'New post',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: board == null
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
                                  const Text('😕', style: TextStyle(fontSize: 40)),
                                  const SizedBox(height: 8),
                                  Text(_error ?? 'Could not load posts', textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  FilledButton(onPressed: _load, child: const Text('Try again')),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  if (!board.metaConnected) const _MetaWarning(),
                  if (board.posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('📭  No posts yet. Create a new post.')),
                    ),
                  for (final p in board.posts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PostCard(post: p, onRetry: () => _retry(p)),
                    ),
                ],
              ),
      ),
    );
  }
}

class _MetaWarning extends StatelessWidget {
  const _MetaWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warn.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warn.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Meta (Facebook/Instagram) is not connected. Use the web app to connect it.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onRetry});

  final SocialPostItem post;
  final VoidCallback onRetry;

  Color get _statusColor {
    switch (post.status) {
      case 'PUBLISHED':
        return good;
      case 'SCHEDULED':
        return brand;
      case 'FAILED':
        return bad;
      default:
        return muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(platformEmoji[post.platform] ?? '•', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  platformLabels[post.platform] ?? post.platform,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
                ),
              ),
              _StatusBadge(
                text: statusLabels[post.status] ?? post.status,
                color: _statusColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.body,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ink, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if ((post.clientName ?? '').isNotEmpty)
                Expanded(
                  child: Text(
                    '🏢 ${post.clientName}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                  ),
                ),
              if (post.dateLabel.isNotEmpty)
                Text(
                  '🗓️ ${post.dateLabel}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                ),
            ],
          ),
          if (post.status == 'FAILED') ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bad.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                post.error ?? 'Unknown error',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: bad),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({required this.clients});

  final List<SocialClientOption> clients;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _body = TextEditingController();
  String _platform = 'FACEBOOK';
  late int _clientId = widget.clients.first.id;
  DateTime? _scheduledAt;
  String? _imageData;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _body.addListener(() => setState(() {}));
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final mime = picked.mimeType ?? 'image/jpeg';
    if (mounted) setState(() => _imageData = 'data:$mime;base64,${base64Encode(bytes)}');
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _aiCaption() async {
    final prompt = _body.text.trim();
    if (prompt.isEmpty) {
      _message('Enter a topic or short idea first, then AI will write the caption');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ApiService.instance.post('/social/caption', body: {'prompt': prompt});
      _body.text = (res['body'] ?? '').toString();
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final text = _body.text.trim();
    if (text.isEmpty) {
      _message('Post cannot be empty');
      return;
    }
    final limit = platformCharLimit[_platform] ?? 2200;
    if (text.length > limit) {
      _message('${platformLabels[_platform]} allows max $limit characters');
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await ApiService.instance.post('/social', body: {
        'client_id': _clientId,
        'platform': _platform,
        'body': text,
        if (_imageData != null) 'media_data': _imageData,
        if (_scheduledAt != null) 'scheduled_at': _scheduledAt!.toIso8601String(),
      });
      if (!mounted) return;
      final status = res['status']?.toString();
      final result = status == 'SCHEDULED'
          ? 'scheduled'
          : (status == 'FAILED' ? 'failed' : 'published');
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final limit = platformCharLimit[_platform] ?? 2200;
    final count = _body.text.length;
    final over = count > limit;

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
            Text(
              '✍️ New social post',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: ink),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in platformLabels.entries)
                  ChoiceChip(
                    label: Text('${platformEmoji[p.key]} ${p.value}'),
                    selected: _platform == p.key,
                    onSelected: (_) => setState(() => _platform = p.key),
                  ),
              ],
            ),
            if (widget.clients.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _clientId,
                decoration: InputDecoration(
                  labelText: 'Client',
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                items: [
                  for (final c in widget.clients) DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _clientId = v ?? _clientId),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 6,
              minLines: 4,
              decoration: InputDecoration(
                hintText: 'Write a post, or enter a short idea for AI…',
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$count / $limit',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: over ? bad : muted,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_imageData == null)
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickImage,
                icon: const Icon(Icons.image_rounded, size: 18),
                label: const Text('Add image (optional)'),
              )
            else
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      base64Decode(_imageData!.split(',').last),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Remove image',
                    onPressed: () => setState(() => _imageData = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _aiCaption,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Generate caption with AI'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickSchedule,
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(
                _scheduledAt == null
                    ? 'Publish now (tap to schedule)'
                    : 'Schedule: ${_scheduledAt!.day}/${_scheduledAt!.month}/${_scheduledAt!.year} ${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')}',
              ),
            ),
            if (_scheduledAt != null)
              TextButton(
                onPressed: () => setState(() => _scheduledAt = null),
                child: const Text('Remove schedule, publish now'),
              ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: (_busy || over) ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_scheduledAt == null ? 'Publish' : 'Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}
