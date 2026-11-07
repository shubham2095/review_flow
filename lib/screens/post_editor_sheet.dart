import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/gbp_models.dart';
import '../services/api_service.dart';
import '../services/gbp_service.dart';
import '../services/platform_rules.dart';
import '../services/post_drafts.dart';
import '../services/web_handoff.dart';
import '../theme/brand.dart';
import '../widgets/confirm_publish.dart';
import '../widgets/date_format.dart';
import '../widgets/image_upload.dart';
import '../widgets/sheet_notice.dart';

class PostEditResult {
  PostEditResult({required this.post, this.warning});

  final GbpPost post;

  /// Set when the post was saved but Google refused the publish step.
  final String? warning;
}

const _types = {
  'STANDARD': 'Update',
  'OFFER': 'Offer',
  'EVENT': 'Event',
  'ALERT': 'Alert',
};

const _ctas = {
  'NONE': 'No button',
  'LEARN_MORE': 'Learn more',
  'CALL': 'Call now',
  'ORDER': 'Order online',
  'BOOK': 'Book',
  'SIGN_UP': 'Sign up',
  'SHOP': 'Shop',
};

/// Create or edit a Google post. Editing only changes what the API allows
/// (text, type, image, button); the rest is fixed when the post is created.
class PostEditorSheet extends StatefulWidget {
  const PostEditorSheet({
    super.key,
    required this.locations,
    this.post,
    this.initialLocationId,
  });

  final List<GbpLocation> locations;
  final GbpPost? post;
  final String? initialLocationId;

  @override
  State<PostEditorSheet> createState() => _PostEditorSheetState();
}

class _PostEditorSheetState extends State<PostEditorSheet> {
  late String? _locationId =
      widget.initialLocationId ??
      (widget.locations.isNotEmpty ? widget.locations.first.id : null);
  late String _type = widget.post?.type ?? 'STANDARD';
  late String _ctaType = widget.post?.ctaType ?? 'NONE';
  late String? _imageUrl = widget.post?.imageUrl;
  Uint8List? _imageBytes;

  late final _summary = TextEditingController(text: widget.post?.summary ?? '');
  late final _ctaUrl = TextEditingController(text: widget.post?.ctaUrl ?? '');
  final _topic = TextEditingController();
  final _title = TextEditingController();
  final _coupon = TextEditingController();
  final _terms = TextEditingController();

  bool _schedule = false;
  DateTime? _scheduledAt;
  DateTime? _eventStart;
  DateTime? _eventEnd;

  bool _uploading = false;
  bool _drafting = false;
  bool _saving = false;
  String? _hint;

  // Message shown inside the sheet (a snack bar would sit behind it).
  String? _notice;
  bool _noticeError = true;
  String? _noticeActionLabel;
  VoidCallback? _noticeAction;

  // Local draft of a NEW post, so closing the sheet never loses the text.
  Timer? _saveTimer;
  bool _done = false;

  bool get _editing => widget.post != null;
  bool get _busy => _uploading || _drafting || _saving;
  bool get _needsUrl => const {
    'LEARN_MORE',
    'ORDER',
    'BOOK',
    'SIGN_UP',
    'SHOP',
  }.contains(_ctaType);

  List<TextEditingController> get _fields => [
    _summary,
    _ctaUrl,
    _topic,
    _title,
    _coupon,
    _terms,
  ];

  @override
  void initState() {
    super.initState();
    if (!_editing) {
      _restoreDraft();
      for (final c in _fields) {
        c.addListener(_scheduleSave);
      }
    }
  }

  bool get _hasContent => [
    _summary,
    _topic,
    _title,
    _coupon,
    _terms,
  ].any((c) => c.text.trim().isNotEmpty);

  Map<String, dynamic> _draftMap() => {
    'summary': _summary.text,
    'topic': _topic.text,
    'title': _title.text,
    'coupon': _coupon.text,
    'terms': _terms.text,
    'cta_url': _ctaUrl.text,
    'type': _type,
    'cta_type': _ctaType,
    'image_url': _imageUrl,
    'location': _locationId,
  };

  void _scheduleSave() {
    if (_editing || _done) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  void _saveNow() {
    if (_editing || _done) return;
    if (_hasContent) {
      PostDrafts.save(_draftMap());
    } else {
      PostDrafts.clear();
    }
  }

  Future<void> _restoreDraft() async {
    final d = await PostDrafts.read();
    if (d == null || !mounted) return;
    String s(String k) => (d[k] as String?) ?? '';
    final hasText = [
      s('summary'),
      s('topic'),
      s('title'),
    ].any((t) => t.trim().isNotEmpty);
    if (!hasText) return;
    _summary.text = s('summary');
    _topic.text = s('topic');
    _title.text = s('title');
    _coupon.text = s('coupon');
    _terms.text = s('terms');
    _ctaUrl.text = s('cta_url');
    setState(() {
      if (_types.containsKey(s('type'))) _type = s('type');
      if (_ctas.containsKey(s('cta_type'))) _ctaType = s('cta_type');
      final img = d['image_url'] as String?;
      if (img != null && img.isNotEmpty) _imageUrl = img;
      final loc = d['location'] as String?;
      if (loc != null && widget.locations.any((l) => l.id == loc)) {
        _locationId = loc;
      }
      _notice = 'Your unsaved post was restored.';
      _noticeError = false;
      _noticeActionLabel = 'Start over';
      _noticeAction = _startOver;
    });
  }

  void _startOver() {
    for (final c in _fields) {
      c.clear();
    }
    PostDrafts.clear();
    setState(() {
      _type = 'STANDARD';
      _ctaType = 'NONE';
      _imageUrl = null;
      _imageBytes = null;
      _hint = null;
      _notice = null;
      _noticeAction = null;
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Keep whatever is typed right now, so closing straight after typing is safe.
    _saveNow();
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  void _message(String text) {
    HapticFeedback.lightImpact();
    setState(() {
      _notice = text;
      _noticeError = true;
      _noticeActionLabel = null;
      _noticeAction = null;
    });
  }

  /// Credits are bought on the web: offer the shortcut right where it is needed.
  void _outOfCredits(String text) {
    // No buying from iOS (platform_rules.dart): the message alone, no button.
    if (!purchaseLinksAllowed) return _message(text);
    setState(() {
      _notice = text;
      _noticeError = true;
      _noticeActionLabel = 'Buy credits';
      _noticeAction = () async {
        try {
          await openInWeb(next: '/buy-credits');
        } catch (e) {
          _message(friendlyException(e).message);
        }
      };
    });
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  );

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        initial ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _addImage() async {
    setState(() => _uploading = true);
    try {
      final img = await pickAndUploadImage(context);
      if (img == null || !mounted) return;
      setState(() {
        _imageUrl = img.url;
        _imageBytes = img.bytes;
      });
    } catch (e) {
      if (mounted) _message(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _aiWrite() async {
    final topic = _topic.text.trim();
    if (topic.isEmpty) {
      _message('Tell the AI what the post is about first.');
      return;
    }
    setState(() {
      _drafting = true;
      _hint = null;
    });
    try {
      final res = await GbpService.generatePostText(
        topic: topic,
        type: _type,
        locationId: _locationId,
        imageUrl: _imageUrl,
      );
      if (!mounted) return;
      _summary.text = res.text;
      setState(() {
        _hint = res.isAi
            ? 'AI post ready. ${res.credits} credits left.'
            : 'AI is unavailable right now, so this is a basic template.';
      });
    } catch (e) {
      if (mounted) {
        final err = friendlyException(e);
        err.isCreditsInsufficient
            ? _outOfCredits(err.message)
            : _message(err.message);
      }
    } finally {
      if (mounted) setState(() => _drafting = false);
    }
  }

  String? _validate() {
    if (_summary.text.trim().isEmpty) return 'Write the post text first.';
    if (_needsUrl) {
      final url = _ctaUrl.text.trim();
      if (!(url.startsWith('http://') || url.startsWith('https://'))) {
        return 'Add a full link (starting with https://) for the button.';
      }
    }
    if (!_editing && _schedule) {
      final at = _scheduledAt;
      if (at == null || !at.isAfter(DateTime.now())) {
        return 'Pick a future date and time to schedule.';
      }
    }
    if (!_editing && _locationId == null) return 'Choose a location.';
    return null;
  }

  Future<void> _submit({required bool publish}) async {
    final problem = _validate();
    if (problem != null) {
      _message(problem);
      return;
    }
    if (publish) {
      String? place;
      for (final l in widget.locations) {
        if (l.id == _locationId) place = l.name;
      }
      if (!await confirmPublish(context, what: 'post', where: place) ||
          !mounted) {
        return;
      }
    }
    setState(() {
      _saving = true;
      _notice = null;
    });
    try {
      final cta = _ctaType;
      final base = <String, dynamic>{
        'summary': _summary.text.trim(),
        'type': _type,
        'image_url': _imageUrl,
        'cta_type': cta,
        'cta_url': _needsUrl ? _ctaUrl.text.trim() : null,
      };

      GbpPost post;
      if (_editing) {
        post = await GbpService.updatePost(widget.post!.id, base);
      } else {
        final body = <String, dynamic>{
          ...base,
          'location': _locationId,
          if (_schedule && _scheduledAt != null)
            'schedule_at': _scheduledAt!.toUtc().toIso8601String(),
          if (_title.text.trim().isNotEmpty) 'title': _title.text.trim(),
          if (_type == 'OFFER' && _coupon.text.trim().isNotEmpty)
            'coupon_code': _coupon.text.trim(),
          if (_type == 'OFFER' && _terms.text.trim().isNotEmpty)
            'terms': _terms.text.trim(),
          if (_type == 'EVENT' && _eventStart != null)
            'event_start': _eventStart!.toUtc().toIso8601String(),
          if (_type == 'EVENT' && _eventEnd != null)
            'event_end': _eventEnd!.toUtc().toIso8601String(),
        };
        post = await GbpService.createPost(body);
      }

      String? warning;
      if (publish) {
        try {
          post = await GbpService.publishPost(post.id);
        } catch (e) {
          warning = friendlyException(e).message;
        }
      }
      // The post now exists on the server: the local copy has done its job.
      _done = true;
      _saveTimer?.cancel();
      await PostDrafts.clear();
      if (!mounted) return;
      Navigator.of(context).pop(PostEditResult(post: post, warning: warning));
    } catch (e) {
      if (mounted) _message(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 14),
              Text(
                _editing ? 'Edit post' : 'New Google post',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: ink,
                ),
              ),
              const SizedBox(height: 14),
              if (!_editing && widget.locations.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: _locationId,
                  isExpanded: true,
                  decoration: _dec('Location'),
                  items: [
                    for (final l in widget.locations)
                      DropdownMenuItem(
                        value: l.id,
                        child: Text(l.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _locationId = v),
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                children: [
                  for (final e in _types.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _type == e.key,
                      showCheckmark: false,
                      onSelected: _busy
                          ? null
                          : (_) {
                              setState(() => _type = e.key);
                              _scheduleSave();
                            },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_editing && (_type == 'OFFER' || _type == 'EVENT')) ...[
                TextField(controller: _title, decoration: _dec('Title')),
                const SizedBox(height: 12),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _topic,
                      decoration: _dec(
                        'Ask AI',
                        hint: 'What is the post about?',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton.filledTonal(
                      onPressed: _busy ? null : _aiWrite,
                      tooltip: 'Write with AI',
                      icon: _drafting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                    ),
                  ),
                ],
              ),
              if (_hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _hint!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: muted,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _summary,
                minLines: 4,
                maxLines: 8,
                maxLength: 1500,
                decoration: _dec('Post text'),
              ),
              _ImageBox(
                url: _imageUrl,
                bytes: _imageBytes,
                uploading: _uploading,
                onAdd: _busy ? null : _addImage,
                onRemove: _busy
                    ? null
                    : () => setState(() {
                        _imageUrl = null;
                        _imageBytes = null;
                      }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _ctaType,
                isExpanded: true,
                decoration: _dec('Button'),
                items: [
                  for (final e in _ctas.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: _busy
                    ? null
                    : (v) {
                        setState(() => _ctaType = v ?? 'NONE');
                        _scheduleSave();
                      },
              ),
              if (_needsUrl) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _ctaUrl,
                  keyboardType: TextInputType.url,
                  decoration: _dec('Button link', hint: 'https://'),
                ),
              ],
              if (!_editing && _type == 'OFFER') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _coupon,
                  decoration: _dec('Coupon code (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _terms,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _dec('Terms and conditions (optional)'),
                ),
              ],
              if (!_editing && _type == 'EVENT') ...[
                const SizedBox(height: 12),
                _DateRow(
                  label: 'Event starts',
                  value: _eventStart,
                  onPick: _busy
                      ? null
                      : () async {
                          final d = await _pickDateTime(_eventStart);
                          if (d != null) setState(() => _eventStart = d);
                        },
                ),
                const SizedBox(height: 8),
                _DateRow(
                  label: 'Event ends',
                  value: _eventEnd,
                  onPick: _busy
                      ? null
                      : () async {
                          final d = await _pickDateTime(
                            _eventEnd ?? _eventStart,
                          );
                          if (d != null) setState(() => _eventEnd = d);
                        },
                ),
              ],
              if (!_editing) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Schedule for later'),
                  value: _schedule,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _schedule = v;
                          if (!v) _scheduledAt = null;
                        }),
                ),
                if (_schedule)
                  _DateRow(
                    label: 'Publish on',
                    value: _scheduledAt,
                    onPick: _busy
                        ? null
                        : () async {
                            final d = await _pickDateTime(_scheduledAt);
                            if (d != null) setState(() => _scheduledAt = d);
                          },
                  ),
              ],
              const SizedBox(height: 16),
              SheetNotice(
                _notice,
                error: _noticeError,
                actionLabel: _noticeActionLabel,
                onAction: _noticeAction,
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _submit(publish: false),
                      child: Text(
                        _editing
                            ? 'Save changes'
                            : (_schedule ? 'Schedule' : 'Save draft'),
                      ),
                    ),
                  ),
                  if (!_schedule || _editing) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : () => _submit(publish: true),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Publish now'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageBox extends StatelessWidget {
  const _ImageBox({
    required this.url,
    required this.bytes,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final String? url;
  final Uint8List? bytes;
  final bool uploading;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final has = (url ?? '').isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      height: has ? 170 : 76,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: uploading
          ? const Center(child: CircularProgressIndicator())
          : has
          ? Stack(
              fit: StackFit.expand,
              children: [
                bytes != null
                    ? Image.memory(bytes!, fit: BoxFit.cover)
                    : Image.network(
                        url!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: muted,
                          ),
                        ),
                      ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton.filled(
                    onPressed: onRemove,
                    tooltip: 'Remove image',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ),
              ],
            )
          : InkWell(
              onTap: onAdd,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_photo_alternate_rounded, color: brand),
                    const SizedBox(width: 8),
                    Text(
                      'Add a photo (optional)',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_rounded, size: 18, color: brand),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 13),
              ),
            ),
            Text(
              value == null ? 'Select' : fmtDateTime(value!),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: ink,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
