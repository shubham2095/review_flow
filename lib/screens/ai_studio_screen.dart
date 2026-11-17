import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ai_media_models.dart';
import '../services/access_problem.dart';
import '../services/ai_media_service.dart';
import '../services/api_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/offline_banner.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/wa_ui.dart';

/// What is wrong with the prompt, or null.
String? aiPromptProblem(String prompt) {
  final p = prompt.trim();
  if (p.isEmpty) return 'Describe the image you want.';
  if (p.length > 1000) return 'Keep the description under 1000 characters.';
  return null;
}

/// AI Studio: describe a picture (optionally with a photo to build on) and the
/// AI makes it. A page of the home shell (no app bar of its own).
class AiStudioScreen extends StatefulWidget {
  const AiStudioScreen({super.key});

  @override
  State<AiStudioScreen> createState() => _AiStudioScreenState();
}

class _AiStudioScreenState extends State<AiStudioScreen> {
  final _prompt = TextEditingController();
  List<AiMedia> _items = [];
  bool _loading = true;
  bool _making = false;
  Object? _error;
  String? _notice;
  bool _noticeIsError = false;

  /// The photo to build on, if one was picked.
  Uint8List? _reference;
  String _referenceName = 'reference.jpg';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await AiMediaService.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _pickReference() async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) {
        showToast(
          context,
          'Could not open your photos. Check the photo permission for Eydia.',
        );
      }
      return;
    }
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _reference = bytes;
      // The server checks the ending against jpg, png and webp.
      _referenceName = 'reference.${aiMediaExtension(bytes)}';
    });
  }

  Future<void> _make() async {
    if (_making) return;
    final problem = aiPromptProblem(_prompt.text);
    if (problem != null) {
      HapticFeedback.lightImpact();
      setState(() {
        _notice = problem;
        _noticeIsError = true;
      });
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create this image?'),
        content: const Text(
          'This uses AI credits from your plan, and only when an image is '
          'really made. It can take up to a minute.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _making = true;
      _notice = null;
    });
    try {
      final result = await AiMediaService.generate(
        _prompt.text.trim(),
        reference: _reference,
        referenceName: _referenceName,
      );
      if (!mounted) return;
      setState(() {
        _items = [result.media, ..._items];
        _noticeIsError = !result.madeImage;
        _notice = result.madeImage
            ? 'Your image is ready.'
            : 'The image AI could not make an image right now. A placeholder '
                  'was saved and no credits were used. Try again in a moment.';
      });
      if (result.madeImage) _open(result.media);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _notice = errorLine(e);
        _noticeIsError = true;
      });
    } finally {
      if (mounted) setState(() => _making = false);
    }
  }

  Future<void> _open(AiMedia m) async {
    final action = await Navigator.of(context).push<AiMediaAction>(
      MaterialPageRoute(builder: (_) => AiMediaViewer(media: m)),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case AiMediaAction.reuse:
        setState(() => _prompt.text = m.prompt);
      case AiMediaAction.delete:
        await _delete(m);
    }
  }

  Future<void> _delete(AiMedia m) async {
    try {
      await AiMediaService.delete(m.id);
      if (!mounted) return;
      setState(() => _items = _items.where((x) => x.id != m.id).toList());
      showToast(context, 'Image deleted.');
    } catch (e) {
      if (mounted) showToast(context, errorLine(e));
    }
  }

  Widget _composer() {
    final bytes = _reference;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _prompt,
            enabled: !_making,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: waInputDecoration(
              'Describe the image',
              hint: 'A festive Diwali offer banner with diyas and gold text',
              onWhite: false,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (bytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    bytes,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    cacheWidth: 144,
                    semanticLabel: 'Photo to build on',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'The AI builds on this photo.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: muted,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove the photo',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _making
                      ? null
                      : () => setState(() => _reference = null),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: _making ? null : _pickReference,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                  ),
                  label: const Text('Add a photo to build on (optional)'),
                ),
            ],
          ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _notice!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: _noticeIsError ? bad : good,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _making ? null : _make,
            icon: _making
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(_making ? 'Creating…' : 'Create image'),
          ),
          if (_making)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'This can take up to a minute. You can leave this page open.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: muted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const SkeletonList(count: 3, itemHeight: 120, headerHeight: 220);
    }
    final error = _error;
    if (error != null && _items.isEmpty) {
      final access = accessProblem(error);
      return Center(
        child: SingleChildScrollView(
          child: access != null
              ? StateView(
                  icon: access.icon,
                  title: access.title,
                  text: access.text,
                )
              : StateView.error(
                  title: 'Could not load AI Studio',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    }
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: ContentWidth(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(child: _composer()),
            ),
            SliverToBoxAdapter(
              child: SectionTitle(
                'Your images',
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                trailing: _items.isEmpty ? null : InfoChip('${_items.length}'),
              ),
            ),
            if (_items.isEmpty)
              const SliverToBoxAdapter(
                child: StateView(
                  icon: Icons.image_outlined,
                  title: 'No images yet',
                  text: 'Describe a picture above and the AI will make it.',
                ),
              )
            else
              // Built lazily: each tile decodes its own picture only while it
              // is on screen.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (_, i) =>
                      _MediaTile(media: _items[i], onTap: _open),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}

/// One picture in the grid. It decodes its picture once, when it appears.
class _MediaTile extends StatefulWidget {
  const _MediaTile({required this.media, required this.onTap});

  final AiMedia media;
  final ValueChanged<AiMedia> onTap;

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> {
  late final Uint8List? _bytes = aiMediaBytes(widget.media.imageData);

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    final when = m.createdAt == null ? '' : ', ${fmtDate(m.createdAt!)}';
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${_bytes == null ? 'No image made' : 'Image'}: ${m.prompt}$when',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onTap(m),
          child: _bytes != null
              ? Image.memory(
                  _bytes,
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => _placeholder(m),
                )
              : _placeholder(m),
        ),
      ),
    );
  }

  Widget _placeholder(AiMedia m) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.hide_image_outlined, color: muted),
        const SizedBox(height: 6),
        Text(
          m.prompt,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
        ),
      ],
    ),
  );
}

/// What the viewer asks the page to do after it closes.
enum AiMediaAction { reuse, delete }

/// One image full screen, with its description and what you can do with it.
class AiMediaViewer extends StatefulWidget {
  const AiMediaViewer({super.key, required this.media});

  final AiMedia media;

  @override
  State<AiMediaViewer> createState() => _AiMediaViewerState();
}

class _AiMediaViewerState extends State<AiMediaViewer> {
  late final Uint8List? _bytes = aiMediaBytes(widget.media.imageData);
  bool _sharing = false;

  Future<void> _share() async {
    final bytes = _bytes;
    if (bytes == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final dir = await getTemporaryDirectory();
      final ext = aiMediaExtension(bytes);
      final file = File('${dir.path}/eydia_ai_${widget.media.id}.$ext');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: ext == 'jpg' ? 'image/jpeg' : 'image/$ext',
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) showToast(context, 'Could not share this image. Try again.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this image?'),
        content: const Text(
          'It is removed from AI Studio. Credits already '
          'used are not given back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop(AiMediaAction.delete);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    final bytes = _bytes;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'AI image',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (bytes != null)
            IconButton(
              tooltip: 'Share image',
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_rounded),
            ),
          IconButton(
            tooltip: 'Delete image',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: bytes == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No image was made for this description.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  )
                : InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        semanticLabel: m.prompt,
                      ),
                    ),
                  ),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              14 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  m.prompt,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: ink,
                    height: 1.4,
                  ),
                ),
                if (m.createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      fmtDateTime(m.createdAt!),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: muted,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: m.prompt),
                          );
                          if (context.mounted) {
                            showToast(context, 'Description copied.');
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy text'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pop(AiMediaAction.reuse),
                        icon: const Icon(Icons.replay_rounded, size: 18),
                        label: const Text('Make another'),
                      ),
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
