import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/gbp_models.dart';
import '../services/api_service.dart';
import '../services/gbp_service.dart';
import '../services/location_store.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';
import '../widgets/image_upload.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import 'auto_plan_sheet.dart';
import 'pages.dart';
import 'photo_editor_sheet.dart';
import 'post_editor_sheet.dart';

enum _PostFilter { all, published, scheduled, drafts }

/// Google posts and photos for the selected location (or all locations).
class PostsPhotosScreen extends StatefulWidget {
  const PostsPhotosScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<PostsPhotosScreen> createState() => _PostsPhotosScreenState();
}

class _PostsPhotosScreenState extends State<PostsPhotosScreen> {
  final _scroll = ScrollController();
  int _section = 0;
  List<GbpPost> _posts = [];
  List<GbpPhoto> _photos = [];
  PageMeta? _postsMeta;
  PageMeta? _photosMeta;
  bool _loading = true;
  bool _loadingMore = false;
  bool _uploading = false;
  String? _error;
  _PostFilter _filter = _PostFilter.all;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    LocationStore.selectedId.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    LocationStore.selectedId.removeListener(_load);
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    if (mounted && _posts.isEmpty && _photos.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final id = LocationStore.selectedId.value;
      final posts = GbpService.postsPage(page: 1, locationId: id);
      final photos = GbpService.photosPage(page: 1, locationId: id);
      final p = await posts;
      final ph = await photos;
      if (!mounted) return;
      setState(() {
        _posts = p.items;
        _postsMeta = p.meta;
        _photos = ph.items;
        _photosMeta = ph.meta;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Infinite scroll: next page of whichever tab is open.
  Future<void> _loadMore() async {
    final id = LocationStore.selectedId.value;
    final meta = _section == 0 ? _postsMeta : _photosMeta;
    if (_loadingMore || _loading || meta == null || !meta.hasMore) return;
    setState(() => _loadingMore = true);
    try {
      if (_section == 0) {
        final r = await GbpService.postsPage(page: meta.currentPage + 1, locationId: id);
        if (!mounted) return;
        setState(() {
          _posts = [..._posts, ...r.items];
          _postsMeta = r.meta;
        });
      } else {
        final r = await GbpService.photosPage(page: meta.currentPage + 1, locationId: id);
        if (!mounted) return;
        setState(() {
          _photos = [..._photos, ...r.items];
          _photosMeta = r.meta;
        });
      }
    } catch (e) {
      _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  List<GbpLocation> get _locations => LocationStore.locations.value;

  bool _needLocations() {
    if (_locations.isNotEmpty) return false;
    _snack('Connect Google and import your locations first.');
    widget.onNavigate(kPageOverview);
    return true;
  }

  Future<void> _newPost([GbpPost? post]) async {
    if (post == null && _needLocations()) return;
    final result = await showModalBottomSheet<PostEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => PostEditorSheet(
        post: post,
        locations: _locations,
        initialLocationId: LocationStore.selectedId.value,
      ),
    );
    if (result == null) return;
    _snack(
      result.warning != null
          ? 'Saved as a draft, but Google said: ${result.warning}'
          : (result.post.isPublished ? 'Post published to Google' : 'Post saved'),
    );
    await _load();
  }

  Future<void> _publishPost(GbpPost post) async {
    setState(() => _busyIds.add(post.id));
    try {
      final updated = await GbpService.publishPost(post.id);
      if (!mounted) return;
      setState(() {
        _posts = [for (final p in _posts) p.id == updated.id ? updated : p];
      });
      _snack('Post published to Google');
    } catch (e) {
      _snack(friendlyException(e).message);
      await _load();
    } finally {
      if (mounted) setState(() => _busyIds.remove(post.id));
    }
  }

  Future<bool> _confirmDelete(String what) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete this $what?'),
        content: const Text(
          'If it is already on Google it will be removed there too where possible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: bad),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deletePost(GbpPost post) async {
    if (!await _confirmDelete('post')) return;
    setState(() => _busyIds.add(post.id));
    try {
      await GbpService.deletePost(post.id);
      if (!mounted) return;
      setState(() => _posts = _posts.where((p) => p.id != post.id).toList());
    } catch (e) {
      _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _busyIds.remove(post.id));
    }
  }

  Future<void> _autoPlan() async {
    if (_needLocations()) return;
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AutoPlanSheet(locationId: LocationStore.selectedId.value),
    );
    if (message == null) return;
    _snack(message);
    await _load();
  }

  Future<void> _newPhoto() async {
    if (_needLocations() || _uploading) return;
    setState(() => _uploading = true);
    UploadedImage? image;
    try {
      image = await pickAndUploadImage(context);
    } catch (e) {
      _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
    if (image == null || !mounted) return;

    final result = await showModalBottomSheet<PhotoEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => PhotoEditorSheet(
        image: image!,
        locations: _locations,
        initialLocationId: LocationStore.selectedId.value,
      ),
    );
    if (result == null) return;
    _snack(
      result.warning != null
          ? 'Saved as a draft, but Google said: ${result.warning}'
          : (result.photo.isPublished ? 'Photo published to Google' : 'Photo saved'),
    );
    await _load();
  }

  Future<void> _photoActions(GbpPhoto photo) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!photo.isPublished)
              ListTile(
                leading: const Icon(Icons.cloud_upload_rounded),
                title: const Text('Publish to Google now'),
                onTap: () => Navigator.pop(ctx, 'publish'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: bad),
              title: const Text('Delete', style: TextStyle(color: bad)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    if (action == 'delete') {
      if (!await _confirmDelete('photo')) return;
      setState(() => _busyIds.add(photo.id));
      try {
        await GbpService.deletePhoto(photo.id);
        if (!mounted) return;
        setState(() => _photos = _photos.where((p) => p.id != photo.id).toList());
      } catch (e) {
        _snack(friendlyException(e).message);
      } finally {
        if (mounted) setState(() => _busyIds.remove(photo.id));
      }
    } else {
      setState(() => _busyIds.add(photo.id));
      try {
        final updated = await GbpService.publishPhoto(photo.id);
        if (!mounted) return;
        setState(() {
          _photos = [for (final p in _photos) p.id == updated.id ? updated : p];
        });
        _snack('Photo published to Google');
      } catch (e) {
        _snack(friendlyException(e).message);
        await _load();
      } finally {
        if (mounted) setState(() => _busyIds.remove(photo.id));
      }
    }
  }

  List<GbpPost> get _visiblePosts {
    switch (_filter) {
      case _PostFilter.all:
        return _posts;
      case _PostFilter.published:
        return _posts.where((p) => p.status == 'PUBLISHED').toList();
      case _PostFilter.scheduled:
        return _posts.where((p) => p.status == 'SCHEDULED').toList();
      case _PostFilter.drafts:
        return _posts
            .where((p) => p.status == 'DRAFT' || p.status == 'FAILED')
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _section == 0 ? () => _newPost() : _newPhoto,
        backgroundColor: brand,
        foregroundColor: Colors.white,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(_section == 0 ? Icons.edit_rounded : Icons.add_a_photo_rounded),
        label: Text(_section == 0 ? 'New post' : 'Add photo'),
      ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: _loading
            ? const SkeletonList(count: 4, itemHeight: 140, headerHeight: 48)
            : ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 0,
                        icon: const Icon(Icons.article_rounded),
                        label: Text('Posts (${_postsMeta?.total ?? _posts.length})'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: const Icon(Icons.photo_library_rounded),
                        label: Text('Photos (${_photosMeta?.total ?? _photos.length})'),
                      ),
                    ],
                    selected: {_section},
                    onSelectionChanged: (s) => setState(() => _section = s.first),
                    style: SegmentedButton.styleFrom(
                      backgroundColor: Colors.white,
                      selectedBackgroundColor: brand.withValues(alpha: 0.14),
                      selectedForegroundColor: brand,
                      foregroundColor: muted,
                      side: const BorderSide(color: Color(0xFFE3E8F2)),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_error != null)
                    _ErrorBox(message: _error!, onRetry: _load)
                  else if (_section == 0)
                    ..._postsSection()
                  else
                    ..._photosSection(),
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
      ),
    );
  }

  List<Widget> _postsSection() {
    final visible = _visiblePosts;
    String label(_PostFilter f) {
      switch (f) {
        case _PostFilter.all:
          return 'All';
        case _PostFilter.published:
          return 'Published';
        case _PostFilter.scheduled:
          return 'Scheduled';
        case _PostFilter.drafts:
          return 'Drafts';
      }
    }

    return [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in _PostFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label(f)),
                  selected: _filter == f,
                  showCheckmark: false,
                  backgroundColor: Colors.white,
                  selectedColor: brand.withValues(alpha: 0.14),
                  side: BorderSide(
                    color: _filter == f
                        ? brand.withValues(alpha: 0.4)
                        : const Color(0xFFE3E8F2),
                  ),
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _filter == f ? brand : ink,
                  ),
                  onSelected: (_) => setState(() => _filter = f),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _autoPlan,
        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
        label: const Text('AI content plan'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      const SizedBox(height: 14),
      if (visible.isEmpty)
        _EmptyBox(
          icon: Icons.article_outlined,
          title: _posts.isEmpty ? 'No posts yet' : 'No posts in this view',
          text: _posts.isEmpty
              ? 'Share offers, events and updates on your Google profile.'
              : 'Try another filter.',
        )
      else
        for (var i = 0; i < visible.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FadeIn(
              delay: i < 6 ? i * 60 : 0,
              child: _PostCard(
                post: visible[i],
                busy: _busyIds.contains(visible[i].id),
                showLocation:
                    LocationStore.selectedId.value == null && _locations.length > 1,
                onPublish: () => _publishPost(visible[i]),
                onEdit: () => _newPost(visible[i]),
                onDelete: () => _deletePost(visible[i]),
              ),
            ),
          ),
    ];
  }

  List<Widget> _photosSection() {
    if (_photos.isEmpty) {
      return const [
        _EmptyBox(
          icon: Icons.photo_library_outlined,
          title: 'No photos yet',
          text: 'Businesses with 10 or more photos get more clicks on Google.',
        ),
      ];
    }
    return [
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _photos.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 200,
        ),
        itemBuilder: (_, i) => FadeIn(
          delay: i < 8 ? i * 50 : 0,
          child: _PhotoTile(
            photo: _photos[i],
            busy: _busyIds.contains(_photos[i].id),
            onTap: () => _photoActions(_photos[i]),
          ),
        ),
      ),
    ];
  }
}

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

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.busy,
    required this.showLocation,
    required this.onPublish,
    required this.onEdit,
    required this.onDelete,
  });

  final GbpPost post;
  final bool busy;
  final bool showLocation;
  final VoidCallback onPublish;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String get _dateText {
    if (post.isPublished && post.publishedAt != null) {
      return 'Published ${fmtDate(post.publishedAt!)}';
    }
    if (post.status == 'SCHEDULED' && post.scheduledAt != null) {
      return 'Goes live ${fmtDateTime(post.scheduledAt!)}';
    }
    if (post.createdAt != null) return 'Created ${fmtDate(post.createdAt!)}';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.hasImage)
            Image.network(
              post.imageUrl!,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 150,
                color: surface,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, color: muted),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Badge(text: post.type, color: brand),
                    const SizedBox(width: 6),
                    _Badge(
                      text: _statusLabel(post.status).toUpperCase(),
                      color: _statusColor(post.status),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        _dateText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                      ),
                    ),
                  ],
                ),
                if ((post.title ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    post.title!,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: ink,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  post.summary,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.4,
                    color: ink,
                  ),
                ),
                if (showLocation && (post.locationName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place_rounded, size: 13, color: brand),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.locationName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: brand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                if (busy)
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Row(
                    children: [
                      if (!post.isPublished)
                        FilledButton.tonalIcon(
                          onPressed: onPublish,
                          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                          label: const Text('Publish'),
                        ),
                      const Spacer(),
                      if (!post.isPublished)
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_rounded, color: muted),
                        ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline_rounded, color: bad),
                      ),
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

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.busy, required this.onTap});

  final GbpPhoto photo;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        decoration: cardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              photo.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: surface,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, color: muted),
              ),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: _Badge(
                text: _statusLabel(photo.status).toUpperCase(),
                color: _statusColor(photo.status),
              ),
            ),
            if ((photo.caption ?? '').isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Text(
                    photo.caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            if (busy)
              Container(
                color: Colors.white.withValues(alpha: 0.6),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return StateView(icon: icon, title: title, text: text);
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StateView.error(
      title: 'Could not load this',
      text: message,
      onRetry: onRetry,
    );
  }
}
