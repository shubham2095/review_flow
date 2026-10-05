import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/gbp_content_models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';

Color _statusColor(String status) {
  switch (status) {
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

String _statusLabel(String status) {
  switch (status) {
    case 'PUBLISHED':
      return 'Published';
    case 'SCHEDULED':
      return 'Scheduled';
    case 'FAILED':
      return 'Failed';
    default:
      return 'Draft';
  }
}

class PostsPhotosScreen extends StatefulWidget {
  const PostsPhotosScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<PostsPhotosScreen> createState() => _PostsPhotosScreenState();
}

class _PostsPhotosScreenState extends State<PostsPhotosScreen> {
  GbpContentBoard? _board;
  List<LocationOption> _locations = [];
  String? _error;
  bool _loading = true;
  int _section = 0; // 0 = posts, 1 = photos
  String _filter = 'ALL'; // ALL, PUBLISHED, SCHEDULED, OTHER

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.instance.get('/gbp-content'),
        ApiService.instance.getList('/reviews'),
      ]);
      if (!mounted) return;
      setState(() {
        _board = GbpContentBoard.fromJson(results[0] as Map<String, dynamic>);
        _locations = (results[1] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(LocationOption.fromJson)
            .toList();
        _error = null;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthService.logout();
        widget.onSignedOut();
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load posts: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action, String success) async {
    try {
      final res = await action();
      if (!mounted) return;
      final status = res['status']?.toString();
      if (status == 'FAILED') {
        _snack('Google did not accept it. Please try again later.');
      } else {
        _snack(success);
      }
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _openPostSheet({GbpPostItem? post}) async {
    if (_locations.isEmpty) {
      _snack('No locations found. Connect Google first.');
      return;
    }
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _PostSheet(post: post, locations: _locations),
    );
    if (result == 'saved') {
      _snack(post == null ? 'Post created ✅' : 'Post updated ✅');
      _load();
    } else if (result == 'failed') {
      _snack('Google did not accept the post');
      _load();
    }
  }

  Future<void> _addPhoto() async {
    if (_locations.isEmpty) {
      _snack('No locations found. Connect Google first.');
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final mime = picked.mimeType ?? 'image/jpeg';
    final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

    if (!mounted) return;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _PhotoSheet(imageData: dataUri, locations: _locations),
    );
    if (result == 'uploaded') {
      _snack('Photo uploaded ✅');
      _load();
    } else if (result == 'failed') {
      _snack('Google did not accept the photo');
      _load();
    }
  }

  bool _matchesFilter(String status) {
    switch (_filter) {
      case 'PUBLISHED':
        return status == 'PUBLISHED';
      case 'SCHEDULED':
        return status == 'SCHEDULED';
      case 'OTHER':
        return status == 'DRAFT' || status == 'FAILED';
      default:
        return true;
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
              onPressed: _section == 0 ? () => _openPostSheet() : _addPhoto,
              backgroundColor: brand,
              foregroundColor: Colors.white,
              icon: Icon(_section == 0 ? Icons.edit_rounded : Icons.add_photo_alternate_rounded),
              label: Text(
                _section == 0 ? 'New post' : 'Upload photo',
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
                                  Text(_error ?? 'Could not load posts', textAlign: TextAlign.center),
                                  const SizedBox(height: 12),
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
                  _StatsRow(board: board),
                  const SizedBox(height: 14),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Posts')),
                      ButtonSegment(value: 1, label: Text('Photos')),
                    ],
                    selected: {_section},
                    onSelectionChanged: (s) => setState(() => _section = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (_section == 0) ...[
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final f in const [
                          ['ALL', 'All'],
                          ['PUBLISHED', 'Published'],
                          ['SCHEDULED', 'Scheduled'],
                          ['OTHER', 'Draft / Failed'],
                        ])
                          ChoiceChip(
                            label: Text(f[1]),
                            selected: _filter == f[0],
                            onSelected: (_) => setState(() => _filter = f[0]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (board.posts.isEmpty)
                      const _Empty(text: '📝  No posts yet. Create your first post.')
                    else
                      for (final p in board.posts.where((p) => _matchesFilter(p.status)))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PostCard(
                            post: p,
                            onEdit: () => _openPostSheet(post: p),
                            onPublish: () => _run(
                              () async => ApiService.instance.post('/gbp-content/posts/${p.id}/publish'),
                              'Post published ✅',
                            ),
                            onDelete: () => _confirmDelete(
                              'Delete this post?',
                              () => ApiService.instance.delete('/gbp-content/posts/${p.id}'),
                              'Post deleted',
                            ),
                          ),
                        ),
                  ] else ...[
                    if (board.photos.isEmpty)
                      const _Empty(text: '📷  No photos yet. Upload your first photo.')
                    else
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.82,
                        children: [
                          for (final ph in board.photos)
                            _PhotoTile(
                              photo: ph,
                              onPublish: () => _run(
                                () async => ApiService.instance.post('/gbp-content/photos/${ph.id}/publish'),
                                'Photo published ✅',
                              ),
                              onDelete: () => _confirmDelete(
                                'Delete this photo?',
                                () => ApiService.instance.delete('/gbp-content/photos/${ph.id}'),
                                'Photo deleted',
                              ),
                            ),
                        ],
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  Future<void> _confirmDelete(
    String title,
    Future<Map<String, dynamic>> Function() action,
    String success,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await action();
      _snack(success);
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.board});

  final GbpContentBoard board;

  @override
  Widget build(BuildContext context) {
    final published = board.posts.where((p) => p.status == 'PUBLISHED').length;
    final scheduled = board.posts.where((p) => p.status == 'SCHEDULED').length;

    Widget tile(String emoji, String value, String label, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: color),
                ),
                Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: muted)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        tile('📝', '${board.posts.length}', 'Posts', brand),
        const SizedBox(width: 8),
        tile('✅', '$published', 'Published', good),
        const SizedBox(width: 8),
        tile('🗓️', '$scheduled', 'Scheduled', brandDeep),
        const SizedBox(width: 8),
        tile('📷', '${board.photos.length}', 'Photos', warn),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onEdit,
    required this.onPublish,
    required this.onDelete,
  });

  final GbpPostItem post;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(post.status);
    final canPublish = post.status == 'DRAFT' || post.status == 'FAILED';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(postTypeEmoji[post.type] ?? '📰', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                postTypeLabels[post.type] ?? post.type,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
              ),
              const Spacer(),
              _Badge(text: _statusLabel(post.status), color: color),
            ],
          ),
          if (post.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                post.imageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            post.body,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ink, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            '📍 ${post.locationTitle}${post.dateLabel.isEmpty ? '' : '  •  ${post.dateLabel}'}',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (canPublish)
                FilledButton.tonalIcon(
                  onPressed: onPublish,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Publish'),
                ),
              const Spacer(),
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, color: brand)),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: bad)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.onPublish, required this.onDelete});

  final GbpPhotoItem photo;
  final VoidCallback onPublish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(photo.status);
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: photo.imageUrl.isEmpty
                ? const SizedBox.shrink()
                : Image.network(
                    photo.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(child: Text('🖼️')),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _Badge(text: _statusLabel(photo.status), color: color)),
                    if (photo.status != 'PUBLISHED')
                      InkWell(
                        onTap: onPublish,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.send_rounded, size: 18, color: brand),
                        ),
                      ),
                    InkWell(
                      onTap: onDelete,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline_rounded, size: 18, color: bad),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  photo.locationTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(child: Text(text, textAlign: TextAlign.center)),
    );
  }
}

class _PostSheet extends StatefulWidget {
  const _PostSheet({this.post, required this.locations});

  final GbpPostItem? post;
  final List<LocationOption> locations;

  @override
  State<_PostSheet> createState() => _PostSheetState();
}

class _PostSheetState extends State<_PostSheet> {
  late final _body = TextEditingController(text: widget.post?.body ?? '');
  late final _cta = TextEditingController(text: widget.post?.ctaUrl ?? '');
  late String _type = widget.post?.type ?? 'UPDATE';
  late int _locationId = widget.locations.first.id;
  DateTime? _scheduledAt;
  bool _busy = false;

  bool get _isEdit => widget.post != null;

  @override
  void initState() {
    super.initState();
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _body.dispose();
    _cta.dispose();
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
    setState(() => _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _aiWrite() async {
    final business = widget.locations.firstWhere((l) => l.id == _locationId).title;
    setState(() => _busy = true);
    try {
      final res = await ApiService.instance.post('/gbp-content/generate-post', body: {
        'type': _type,
        'business': business,
      });
      _body.text = (res['body'] ?? '').toString();
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final text = _body.text.trim();
    if (text.isEmpty) {
      _message('Post cannot be empty');
      return;
    }
    if (text.length > 1500) {
      _message('Post can have max 1500 characters');
      return;
    }

    setState(() => _busy = true);
    try {
      if (_isEdit) {
        await ApiService.instance.put('/gbp-content/posts/${widget.post!.id}', body: {
          'type': _type,
          'body': text,
          'cta_url': _cta.text.trim().isEmpty ? null : _cta.text.trim(),
        });
        if (mounted) Navigator.of(context).pop('saved');
      } else {
        final res = await ApiService.instance.post('/gbp-content/posts', body: {
          'gbp_location_id': _locationId,
          'type': _type,
          'body': text,
          if (_cta.text.trim().isNotEmpty) 'cta_url': _cta.text.trim(),
          if (_scheduledAt != null) 'scheduled_at': _scheduledAt!.toIso8601String(),
        });
        if (mounted) Navigator.of(context).pop(res['status'] == 'FAILED' ? 'failed' : 'saved');
      }
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final count = _body.text.length;
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
              _isEdit ? 'Edit post' : 'New Google post',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: ink),
            ),
            const SizedBox(height: 14),
            if (!_isEdit) ...[
              DropdownButtonFormField<int>(
                initialValue: _locationId,
                decoration: _dec('Location'),
                items: [
                  for (final l in widget.locations) DropdownMenuItem(value: l.id, child: Text(l.title)),
                ],
                onChanged: (v) => setState(() => _locationId = v ?? _locationId),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              children: [
                for (final t in postTypeLabels.entries)
                  ChoiceChip(
                    label: Text('${postTypeEmoji[t.key]} ${t.value}'),
                    selected: _type == t.key,
                    onSelected: (_) => setState(() => _type = t.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 6,
              minLines: 4,
              decoration: _dec('What do you want to share?'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$count / 1500',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: count > 1500 ? bad : muted),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _aiWrite,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Write with AI (uses credits)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cta,
              keyboardType: TextInputType.url,
              decoration: _dec('Button link (optional)'),
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickSchedule,
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: Text(
                  _scheduledAt == null
                      ? 'Publish now (tap to schedule)'
                      : 'Scheduled: ${_scheduledAt!.day}/${_scheduledAt!.month}/${_scheduledAt!.year} '
                          '${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Save changes' : (_scheduledAt == null ? 'Publish' : 'Schedule')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSheet extends StatefulWidget {
  const _PhotoSheet({required this.imageData, required this.locations});

  final String imageData;
  final List<LocationOption> locations;

  @override
  State<_PhotoSheet> createState() => _PhotoSheetState();
}

class _PhotoSheetState extends State<_PhotoSheet> {
  final _caption = TextEditingController();
  late int _locationId = widget.locations.first.id;
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _upload() async {
    setState(() => _busy = true);
    try {
      final res = await ApiService.instance.post('/gbp-content/photos', body: {
        'gbp_location_id': _locationId,
        'image': widget.imageData,
        if (_caption.text.trim().isNotEmpty) 'caption': _caption.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(res['status'] == 'FAILED' ? 'failed' : 'uploaded');
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
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
            'Upload photo',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: ink),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: _locationId,
            decoration: InputDecoration(
              labelText: 'Location',
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
            items: [
              for (final l in widget.locations) DropdownMenuItem(value: l.id, child: Text(l.title)),
            ],
            onChanged: (v) => setState(() => _locationId = v ?? _locationId),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caption,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Caption (optional)',
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _upload,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Upload to Google'),
          ),
        ],
      ),
    );
  }
}
