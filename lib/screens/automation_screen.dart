import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/account_models.dart';
import '../services/account_service.dart';
import '../services/api_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';

const _tones = [
  'Friendly',
  'Professional',
  'Warm and personal',
  'Short and polite',
];

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
  bool _saving = false;
  String? _error;
  double _frequency = 3;
  double _queue = 4;

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save(Map<String, dynamic> body) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final data = await AccountService.updateAutomation(body);
      if (!mounted) return;
      setState(() => _apply(data));
    } catch (e) {
      _message(friendlyException(e).message);
      // Put the controls back to what the server has.
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      backgroundColor: surface,
      body: _loading && data == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && data == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 44, color: muted),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        FilledButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: brand,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (_saving) const LinearProgressIndicator(minHeight: 3),
                      if (data != null) ..._content(data),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _content(AutomationData data) {
    final s = data.settings;
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
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'Connect Google and import a location first. Automation works on your main location.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: muted),
          ),
        ),
      const SizedBox(height: 14),
      _SwitchCard(
        icon: Icons.reply_rounded,
        title: 'Auto-reply to reviews',
        text: 'The AI writes and posts a reply to new Google reviews.',
        value: s.autoReviewReplies,
        busy: _saving,
        onChanged: (v) => _save({'auto_review_replies': v}),
      ),
      _SwitchCard(
        icon: Icons.article_rounded,
        title: 'Auto Google posts',
        text: 'Keeps a queue of AI posts and publishes them on schedule.',
        value: s.autoPosts,
        busy: _saving,
        onChanged: (v) => _save({'auto_posts': v}),
      ),
      _SwitchCard(
        icon: Icons.photo_library_rounded,
        title: 'Auto photos',
        text: 'Publishes your saved photos on schedule.',
        value: s.autoPhotos,
        busy: _saving,
        onChanged: (v) => _save({'auto_photos': v}),
      ),
      _SwitchCard(
        icon: Icons.qr_code_2_rounded,
        title: 'QR review assist',
        text: 'Customers scan a QR code and AI helps them write a Google review.',
        value: s.qrReviewAssist,
        busy: _saving,
        onChanged: (v) => _save({'qr_review_assist': v}),
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
                    selected: s.replyTone == t,
                    showCheckmark: false,
                    onSelected: _saving ? null : (_) => _save({'reply_tone': t}),
                  ),
              ],
            ),
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
              onChanged: _saving ? null : (v) => setState(() => _frequency = v),
              onChangeEnd: (v) => _save({'post_frequency_days': v.round()}),
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
              onChanged: _saving ? null : (v) => setState(() => _queue = v),
              onChangeEnd: (v) => _save({'post_queue_target': v.round()}),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _QrCard(data: data),
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
            color: brand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: brand, size: 20),
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

class _QrCard extends StatelessWidget {
  const _QrCard({required this.data});

  final AutomationData data;

  @override
  Widget build(BuildContext context) {
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
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(text: 'Leave us a Google review: $url'),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
