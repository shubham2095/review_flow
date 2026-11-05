import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/gbp_models.dart';
import '../services/api_service.dart';
import '../services/gbp_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/image_upload.dart';

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

  bool get _editing => widget.post != null;
  bool get _busy => _uploading || _drafting || _saving;
  bool get _needsUrl => const {
        'LEARN_MORE', 'ORDER', 'BOOK', 'SIGN_UP', 'SHOP',
      }.contains(_ctaType);

  @override
  void dispose() {
    _summary.dispose();
    _ctaUrl.dispose();
    _topic.dispose();
    _title.dispose();
    _coupon.dispose();
    _terms.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
      initialTime: TimeOfDay.fromDateTime(initial ?? now.add(const Duration(hours: 1))),
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
      if (mounted) _message(friendlyException(e).message);
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
    setState(() => _saving = true);
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
                  onChanged: _busy ? null : (v) => setState(() => _locationId = v),
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
                      onSelected: _busy ? null : (_) => setState(() => _type = e.key),
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
                      decoration: _dec('Ask AI', hint: 'What is the post about?'),
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
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
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
                onChanged: _busy ? null : (v) => setState(() => _ctaType = v ?? 'NONE'),
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
                TextField(controller: _coupon, decoration: _dec('Coupon code (optional)')),
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
                          final d = await _pickDateTime(_eventEnd ?? _eventStart);
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
                              child: Icon(Icons.broken_image_outlined, color: muted),
                            ),
                          ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton.filled(
                        onPressed: onRemove,
                        tooltip: 'Remove image',
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
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
  const _DateRow({required this.label, required this.value, required this.onPick});

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
