import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/gbp_models.dart';
import '../services/api_service.dart';
import '../services/gbp_service.dart';
import '../services/platform_rules.dart';
import '../services/web_handoff.dart';
import '../theme/brand.dart';
import '../widgets/confirm_publish.dart';
import '../widgets/date_format.dart';
import '../widgets/image_upload.dart';
import '../widgets/sheet_notice.dart';

class PhotoEditResult {
  PhotoEditResult({required this.photo, this.warning});

  final GbpPhoto photo;

  /// Set when the photo was saved but Google refused the publish step.
  final String? warning;
}

const _categories = {
  'ADDITIONAL': 'Additional',
  'COVER': 'Cover',
  'PROFILE': 'Profile',
  'LOGO': 'Logo',
  'EXTERIOR': 'Exterior',
  'INTERIOR': 'Interior',
  'PRODUCT': 'Product',
  'AT_WORK': 'At work',
  'FOOD_AND_DRINK': 'Food and drink',
  'TEAMS': 'Team',
};

/// Details for a photo that was just uploaded: location, category, caption
/// (optionally written by AI) and when to publish it.
class PhotoEditorSheet extends StatefulWidget {
  const PhotoEditorSheet({
    super.key,
    required this.image,
    required this.locations,
    this.initialLocationId,
  });

  final UploadedImage image;
  final List<GbpLocation> locations;
  final String? initialLocationId;

  @override
  State<PhotoEditorSheet> createState() => _PhotoEditorSheetState();
}

class _PhotoEditorSheetState extends State<PhotoEditorSheet> {
  late String? _locationId =
      widget.initialLocationId ??
      (widget.locations.isNotEmpty ? widget.locations.first.id : null);
  String _category = 'ADDITIONAL';
  final _caption = TextEditingController();
  final _topic = TextEditingController();
  bool _schedule = false;
  DateTime? _scheduledAt;
  bool _drafting = false;
  bool _saving = false;
  String? _hint;

  // Message shown inside the sheet (a snack bar would sit behind it).
  String? _notice;
  String? _noticeActionLabel;
  VoidCallback? _noticeAction;

  bool get _busy => _drafting || _saving;

  @override
  void dispose() {
    _caption.dispose();
    _topic.dispose();
    super.dispose();
  }

  void _message(String text) {
    HapticFeedback.lightImpact();
    setState(() {
      _notice = text;
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

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _aiCaption() async {
    final topic = _topic.text.trim();
    if (topic.isEmpty) {
      _message('Tell the AI what the photo shows first.');
      return;
    }
    setState(() {
      _drafting = true;
      _hint = null;
    });
    try {
      final res = await GbpService.photoCaption(
        topic: topic,
        locationId: _locationId,
      );
      if (!mounted) return;
      _caption.text = res.text;
      setState(() {
        _hint = res.isAi
            ? 'AI caption ready. ${res.credits} credits left.'
            : 'AI is unavailable right now, so this is a basic caption.';
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

  Future<void> _submit({required bool publish}) async {
    if (_locationId == null) {
      _message('Choose a location.');
      return;
    }
    if (_schedule) {
      final at = _scheduledAt;
      if (at == null || !at.isAfter(DateTime.now())) {
        _message('Pick a future date and time to schedule.');
        return;
      }
    }
    if (publish) {
      String? place;
      for (final l in widget.locations) {
        if (l.id == _locationId) place = l.name;
      }
      if (!await confirmPublish(context, what: 'photo', where: place) ||
          !mounted) {
        return;
      }
    }
    setState(() {
      _saving = true;
      _notice = null;
    });
    try {
      var photo = await GbpService.createPhoto({
        'location': _locationId,
        'image_url': widget.image.url,
        'category': _category,
        if (_caption.text.trim().isNotEmpty) 'caption': _caption.text.trim(),
        if (_schedule && _scheduledAt != null)
          'schedule_at': _scheduledAt!.toUtc().toIso8601String(),
      });

      String? warning;
      if (publish) {
        try {
          photo = await GbpService.publishPhoto(photo.id);
        } catch (e) {
          warning = friendlyException(e).message;
        }
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(PhotoEditResult(photo: photo, warning: warning));
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
                'Add photo',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: ink,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Image.memory(widget.image.bytes, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 14),
              if (widget.locations.length > 1) ...[
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
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: _dec('Category'),
                items: [
                  for (final e in _categories.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _category = v ?? 'ADDITIONAL'),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _topic,
                      decoration: _dec(
                        'Ask AI',
                        hint: 'What does the photo show?',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton.filledTonal(
                      onPressed: _busy ? null : _aiCaption,
                      tooltip: 'Write caption with AI',
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
                controller: _caption,
                maxLength: 255,
                minLines: 2,
                maxLines: 4,
                decoration: _dec('Caption (optional)'),
              ),
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
                InkWell(
                  onTap: _busy ? null : _pickSchedule,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
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
                            _scheduledAt == null
                                ? 'Pick date and time'
                                : fmtDateTime(_scheduledAt!),
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SheetNotice(
                _notice,
                actionLabel: _noticeActionLabel,
                onAction: _noticeAction,
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _submit(publish: false),
                      child: Text(_schedule ? 'Schedule' : 'Save draft'),
                    ),
                  ),
                  if (!_schedule) ...[
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
