import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/account_models.dart';
import '../services/account_service.dart';
import '../services/api_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';

const _tones = [
  'Friendly',
  'Professional',
  'Warm and personal',
  'Short and polite',
];

/// What a reply sounds like in each tone, so the choice is not a guess.
const _toneExamples = {
  'Friendly':
      'Thanks so much for the kind words! We loved having you and hope to see you again soon.',
  'Professional':
      'Thank you for your feedback. We appreciate your time and look forward to serving you again.',
  'Warm and personal':
      'Your review truly made our day. It means the world to our whole team, thank you!',
  'Short and polite': 'Thank you for your review. We hope to see you again.',
};

/// ON/OFF switches for the AI features, the posting rhythm and the QR page that
/// helps customers write a review.
class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  AutomationData? _data;
  bool _loading = true;
  String? _error;
  double _frequency = 3;
  double _queue = 4;

  /// Settings being saved, by key. Each switch locks only itself while it saves.
  final Set<String> _busyKeys = {};

  /// What the person just chose, shown at once while the server confirms.
  final Map<String, dynamic> _local = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _apply(AutomationData data) {
    _data = data;
    _frequency = data.settings.postFrequencyDays.toDouble();
    _queue = data.settings.postQueueTarget.toDouble();
  }

  Future<void> _load() async {
    try {
      final data = await AccountService.automation();
      if (!mounted) return;
      setState(() {
        _apply(data);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(milliseconds: 2200)),
      );
  }

  bool _flag(String key, bool server) => (_local[key] as bool?) ?? server;

  /// Saves one setting. The control moves at once; if the server says no it
  /// goes back and the reason is shown.
  Future<void> _save(String key, dynamic value, {String? done}) async {
    if (_busyKeys.contains(key)) return;
    setState(() {
      _local[key] = value;
      _busyKeys.add(key);
    });
    try {
      final data = await AccountService.updateAutomation({key: value});
      if (!mounted) return;
      setState(() {
        _local.remove(key);
        _apply(data);
      });
      HapticFeedback.selectionClick();
      if (done != null) _message(done);
    } catch (e) {
      if (!mounted) return;
      setState(() => _local.remove(key));
      _message(friendlyException(e).message);
      // The sliders hold their own value: put them back to what the server has.
      final d = _data;
      if (d != null) {
        setState(() {
          _frequency = d.settings.postFrequencyDays.toDouble();
          _queue = d.settings.postQueueTarget.toDouble();
        });
      }
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  /// Turning on anything that publishes to Google by itself deserves a second look.
  Future<void> _toggle({
    required String key,
    required bool on,
    required String onMessage,
    required String offMessage,
    String? confirmTitle,
    String? confirmText,
  }) async {
    if (on && confirmTitle != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(confirmTitle),
          content: Text(confirmText ?? ''),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Turn on'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _save(key, on, done: on ? onMessage : offMessage);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      backgroundColor: surface,
      body: _loading && data == null
          ? const SkeletonList(count: 4, itemHeight: 110, headerHeight: 130)
          : _error != null && data == null
              ? Center(
                  child: StateView.error(
                    title: 'Could not load automation',
                    text: _error!,
                    onRetry: _load,
                  ),
                )
              : RefreshIndicator(
                  color: brand,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [if (data != null) ..._content(data)],
                  ),
                ),
    );
  }

  List<Widget> _content(AutomationData data) {
    final s = data.settings;
    final tone = (_local['reply_tone'] as String?) ?? s.replyTone;
    final example = _toneExamples[tone];

    return [
      FadeIn(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [royalIndigo, royalViolet]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: royalGold, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.business.isEmpty ? 'Your business' : data.business,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.lastRunAt == null
                          ? 'Automation has not run yet'
                          : 'Last run ${fmtDateTime(s.lastRunAt!)}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      if (!data.hasLocation)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: warn.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: warn.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: warn),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Connect Google and import a location first. Automation works on your main location.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    height: 1.35,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 14),
      _SwitchCard(
        icon: Icons.reply_rounded,
        title: 'Auto-reply to reviews',
        text: 'The AI writes and posts a reply to new Google reviews.',
        value: _flag('auto_review_replies', s.autoReviewReplies),
        busy: _busyKeys.contains('auto_review_replies'),
        onChanged: (v) => _toggle(
          key: 'auto_review_replies',
          on: v,
          onMessage: 'Auto-reply is on',
          offMessage: 'Auto-reply is off',
          confirmTitle: 'Reply to reviews automatically?',
          confirmText:
              'The AI will write and post replies to new reviews on your Google profile by itself, in the "${tone.isEmpty ? 'Friendly' : tone}" tone. Replies are public. You can turn this off any time.',
        ),
      ),
      _SwitchCard(
        icon: Icons.article_rounded,
        title: 'Auto Google posts',
        text: 'Keeps a queue of AI posts and publishes them on schedule.',
        value: _flag('auto_posts', s.autoPosts),
        busy: _busyKeys.contains('auto_posts'),
        onChanged: (v) => _toggle(
          key: 'auto_posts',
          on: v,
          onMessage: 'Auto posts are on',
          offMessage: 'Auto posts are off',
          confirmTitle: 'Publish posts automatically?',
          confirmText:
              'The AI will create posts and publish them on your Google profile on the schedule below. You can turn this off any time.',
        ),
      ),
      _SwitchCard(
        icon: Icons.photo_library_rounded,
        title: 'Auto photos',
        text: 'Publishes your saved photos on schedule.',
        value: _flag('auto_photos', s.autoPhotos),
        busy: _busyKeys.contains('auto_photos'),
        onChanged: (v) => _toggle(
          key: 'auto_photos',
          on: v,
          onMessage: 'Auto photos are on',
          offMessage: 'Auto photos are off',
          confirmTitle: 'Publish photos automatically?',
          confirmText:
              'Your saved photos will be published to your Google profile on schedule. You can turn this off any time.',
        ),
      ),
      _SwitchCard(
        icon: Icons.qr_code_2_rounded,
        title: 'QR review assist',
        text: 'Customers scan a QR code and AI helps them write a Google review.',
        value: _flag('qr_review_assist', s.qrReviewAssist),
        busy: _busyKeys.contains('qr_review_assist'),
        onChanged: (v) => _toggle(
          key: 'qr_review_assist',
          on: v,
          onMessage: 'QR review assist is on',
          offMessage: 'QR review assist is off',
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reply tone',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in {..._tones, if (s.replyTone.isNotEmpty) s.replyTone})
                  ChoiceChip(
                    label: Text(t),
                    selected: tone == t,
                    showCheckmark: false,
                    onSelected: _busyKeys.contains('reply_tone')
                        ? null
                        : (_) => _save('reply_tone', t, done: 'Reply tone: $t'),
                  ),
              ],
            ),
            if (example != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Example reply',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      example,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Post one every ${_frequency.round()} ${_frequency.round() == 1 ? 'day' : 'days'}',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            Slider(
              value: _frequency,
              min: 1,
              max: 30,
              divisions: 29,
              label: '${_frequency.round()}',
              onChanged: _busyKeys.contains('post_frequency_days')
                  ? null
                  : (v) => setState(() => _frequency = v),
              onChangeEnd: (v) => _save('post_frequency_days', v.round()),
            ),
            Text(
              'Keep ${_queue.round()} ${_queue.round() == 1 ? 'post' : 'posts'} ready in the queue',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            Slider(
              value: _queue,
              min: 1,
              max: 12,
              divisions: 11,
              label: '${_queue.round()}',
              onChanged: _busyKeys.contains('post_queue_target')
                  ? null
                  : (v) => setState(() => _queue = v),
              onChangeEnd: (v) => _save('post_queue_target', v.round()),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _QrCard(data: data, onMessage: _message),
    ];
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: cardDecoration(),
      child: SwitchListTile(
        value: value,
        onChanged: busy ? null : onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (value ? brand : muted).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: value ? brand : muted, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: ink,
          ),
        ),
        subtitle: Text(
          text,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
        ),
      ),
    );
  }
}

class _QrCard extends StatefulWidget {
  const _QrCard({required this.data, required this.onMessage});

  final AutomationData data;
  final ValueChanged<String> onMessage;

  @override
  State<_QrCard> createState() => _QrCardState();
}

class _QrCardState extends State<_QrCard> {
  bool _preparing = false;

  /// A print-ready picture: black code on white with a quiet margin, big enough
  /// to print on a counter card.
  Future<void> _shareImage(String url) async {
    if (_preparing) return;
    setState(() => _preparing = true);
    try {
      const size = 1024.0;
      const margin = 96.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, size, size),
        Paint()..color = Colors.white,
      );
      canvas.translate(margin, margin);
      QrPainter(
        data: url,
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ).paint(canvas, const Size(size - 2 * margin, size - 2 * margin));
      final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('no image');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/eydia_review_qr.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: 'Scan to leave us a Google review',
        ),
      );
    } catch (_) {
      widget.onMessage('Could not prepare the QR image. Please try again.');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final url = data.assistUrlPreview;
    final active = data.assistUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review QR code',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          if (url.isEmpty)
            Text(
              'Add your Google review link first (Business profile), then your QR code appears here.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: muted),
            )
          else ...[
            Text(
              active
                  ? 'Print this on your counter or bill. Customers scan it to leave a review.'
                  : 'Preview only. Turn on QR review assist above to activate this page.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: muted),
            ),
            const SizedBox(height: 14),
            Center(
              child: Semantics(
                label: 'QR code that opens your review page',
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6EAF2)),
                  ),
                  child: QrImageView(data: url, size: 180),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      HapticFeedback.selectionClick();
                      widget.onMessage('Link copied');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy link'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(text: 'Leave us a Google review: $url'),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share link'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _preparing ? null : () => _shareImage(url),
              icon: _preparing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_rounded, size: 18),
              label: Text(_preparing ? 'Preparing...' : 'Share QR as image to print'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ],
      ),
    );
  }
}
