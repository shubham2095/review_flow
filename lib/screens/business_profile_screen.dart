import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/gbp_models.dart';
import '../services/api_service.dart';
import '../services/gbp_service.dart';
import '../services/location_store.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';

const _dayLabels = {
  'MONDAY': 'Monday',
  'TUESDAY': 'Tuesday',
  'WEDNESDAY': 'Wednesday',
  'THURSDAY': 'Thursday',
  'FRIDAY': 'Friday',
  'SATURDAY': 'Saturday',
  'SUNDAY': 'Sunday',
};

/// Edit the business information shown on Google: name, description, contact,
/// address, opening hours. Saves in Eydia and pushes to Google when connected.
class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  BusinessProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _drafting = false;
  String? _error;
  List<HoursRow> _hours = [];

  final _name = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _chatUrl = TextEditingController();
  final _address = TextEditingController();
  final _serviceArea = TextEditingController();
  final _labels = TextEditingController();
  final _openingDate = TextEditingController();

  List<TextEditingController> get _controllers => [
        _name, _category, _description, _phone, _website, _chatUrl,
        _address, _serviceArea, _labels, _openingDate,
      ];

  @override
  void initState() {
    super.initState();
    LocationStore.selectedId.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    LocationStore.selectedId.removeListener(_load);
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  List<String> _split(String raw) => raw
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void _fill(BusinessProfile p) {
    _name.text = p.name;
    _category.text = p.category;
    _description.text = p.description;
    _phone.text = p.phone;
    _website.text = p.website;
    _chatUrl.text = p.chatUrl;
    _address.text = p.address;
    _serviceArea.text = p.serviceArea.join(', ');
    _labels.text = p.labels.join(', ');
    _openingDate.text = p.openingDate;
    _hours = [for (final h in p.hours) h.copy()];
  }

  Future<void> _load() async {
    if (mounted && _profile == null) setState(() => _loading = true);
    try {
      final p = await GbpService.profile(
        locationId: LocationStore.selectedId.value,
      );
      if (!mounted) return;
      setState(() {
        _profile = p;
        _fill(p);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Only the fields the user actually changed, so unchanged values are not
  /// re-sent to Google.
  Map<String, dynamic> _changes() {
    final p = _profile;
    if (p == null) return {};
    final out = <String, dynamic>{};
    void text(String key, TextEditingController c, String original) {
      if (c.text.trim() != original) out[key] = c.text.trim();
    }

    text('name', _name, p.name);
    text('category', _category, p.category);
    text('description', _description, p.description);
    text('phone', _phone, p.phone);
    text('website', _website, p.website);
    text('chat_url', _chatUrl, p.chatUrl);
    text('address', _address, p.address);
    text('opening_date', _openingDate, p.openingDate);

    if (_split(_serviceArea.text).join('|') != p.serviceArea.join('|')) {
      out['service_area'] = _split(_serviceArea.text);
    }
    if (_split(_labels.text).join('|') != p.labels.join('|')) {
      out['labels'] = _split(_labels.text);
    }

    var hoursChanged = _hours.length != p.hours.length;
    for (var i = 0; !hoursChanged && i < _hours.length; i++) {
      final a = _hours[i];
      final b = p.hours[i];
      hoursChanged =
          a.open != b.open || a.close != b.close || a.closed != b.closed;
    }
    if (hoursChanged) out['hours'] = [for (final h in _hours) h.toJson()];
    return out;
  }

  Future<void> _save() async {
    final changes = _changes();
    if (changes.isEmpty || _saving) return;
    if (changes.containsKey('name') && _name.text.trim().isEmpty) {
      _message('The business name cannot be empty.');
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await GbpService.updateProfile(
        LocationStore.selectedId.value,
        changes,
      );
      if (!mounted) return;
      setState(() {
        _profile = res.profile;
        _fill(res.profile);
      });
      _message(
        res.message.isNotEmpty
            ? res.message
            : (res.syncedToGoogle ? 'Saved and updated on Google.' : 'Saved.'),
      );
    } catch (e) {
      _message(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _aiRewrite() async {
    final keywords = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Improve with AI'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: 'Target keywords (optional)',
              hintText: 'dentist, teeth whitening, Noida',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Write it'),
            ),
          ],
        );
      },
    );
    if (keywords == null || !mounted) return;

    setState(() => _drafting = true);
    try {
      final res = await GbpService.aiRewriteDescription(
        locationId: LocationStore.selectedId.value,
        keywords: _split(keywords),
      );
      if (!mounted) return;
      setState(() => _description.text = res.text);
      _message('New description ready. Review it, then save. ${res.credits} credits left.');
    } catch (e) {
      _message(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _drafting = false);
    }
  }

  Future<void> _pickTime(HoursRow row, bool opening) async {
    final current = opening ? row.open : row.close;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (opening) {
        row.open = value;
      } else {
        row.close = value;
      }
    });
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: ink,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    TextInputType? type,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: type,
        minLines: 1,
        maxLines: maxLines,
        decoration: _dec(label, hint: hint).copyWith(fillColor: surface),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final multi = LocationStore.locations.value.length > 1;

    return Scaffold(
      backgroundColor: surface,
      body: _loading && p == null
          ? const SkeletonList(count: 3, itemHeight: 150, headerHeight: 150)
          : _error != null && p == null
              ? Center(
                  child: StateView.error(
                    title: 'Could not load your profile',
                    text: _error!,
                    onRetry: _load,
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        color: brand,
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            if (p != null) FadeIn(child: _Summary(profile: p)),
                            if (multi && LocationStore.selectedId.value == null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Text(
                                  'Showing your top location. Pick another one from the top bar to edit it.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: muted,
                                  ),
                                ),
                              ),
                            _section('About', [
                              _field(_name, 'Business name'),
                              _field(_category, 'Category'),
                              _field(
                                _description,
                                'Description',
                                maxLines: 6,
                                type: TextInputType.multiline,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _drafting ? null : _aiRewrite,
                                  icon: _drafting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                                  label: const Text('Improve with AI'),
                                ),
                              ),
                            ]),
                            _section('Contact', [
                              _field(_phone, 'Phone', type: TextInputType.phone),
                              _field(_website, 'Website', type: TextInputType.url),
                              _field(_chatUrl, 'Chat link (optional)', type: TextInputType.url),
                            ]),
                            _section('Location', [
                              _field(_address, 'Address', maxLines: 3),
                              _field(
                                _serviceArea,
                                'Service areas',
                                hint: 'Noida, Ghaziabad, Delhi',
                              ),
                            ]),
                            _section('Opening hours', [
                              for (final h in _hours)
                                _HoursRowTile(
                                  row: h,
                                  onToggle: (closed) => setState(() => h.closed = closed),
                                  onPickOpen: () => _pickTime(h, true),
                                  onPickClose: () => _pickTime(h, false),
                                ),
                            ]),
                            _section('More', [
                              _field(_labels, 'Labels', hint: 'Separate with commas'),
                              _field(
                                _openingDate,
                                'Opening date',
                                hint: 'YYYY-MM-DD',
                              ),
                            ]),
                            if (p != null && p.reviewUrl.isNotEmpty)
                              _ReviewLinkCard(profile: p, onMessage: _message),
                          ],
                        ),
                      ),
                    ),
                    ListenableBuilder(
                      listenable: Listenable.merge(_controllers),
                      builder: (context, _) {
                        final dirty = _changes().isNotEmpty;
                        return AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: dirty
                              ? SafeArea(
                                  top: false,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      border: Border(
                                        top: BorderSide(color: Color(0xFFEEF1F7)),
                                      ),
                                    ),
                                    child: FilledButton.icon(
                                      onPressed: _saving ? null : _save,
                                      icon: _saving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.save_rounded, size: 18),
                                      label: Text(
                                        (p?.linkedToGoogle ?? false)
                                            ? 'Save and update Google'
                                            : 'Save changes',
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        );
                      },
                    ),
                  ],
                ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.profile});

  final BusinessProfile profile;

  /// Which key details are filled in, so owners see what is still missing.
  ({int done, int total, List<String> missing}) get _completeness {
    final checks = <String, bool>{
      'name': profile.name.trim().isNotEmpty,
      'category': profile.category.trim().isNotEmpty,
      'description': profile.description.trim().length >= 60,
      'phone': profile.phone.trim().isNotEmpty,
      'website': profile.website.trim().isNotEmpty,
      'address': profile.address.trim().isNotEmpty,
      'opening hours': profile.hours.isNotEmpty,
      'labels': profile.labels.isNotEmpty,
    };
    final missing = [
      for (final e in checks.entries)
        if (!e.value) e.key,
    ];
    return (
      done: checks.length - missing.length,
      total: checks.length,
      missing: missing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _completeness;
    final pct = c.total == 0 ? 0.0 : c.done / c.total;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [royalIndigo, royalViolet]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.name.isEmpty ? 'Your business' : profile.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(Icons.star_rounded, '${profile.rating.toStringAsFixed(1)} (${profile.reviewCount})'),
              _Chip(
                profile.isVerified ? Icons.verified_rounded : Icons.error_outline_rounded,
                profile.isVerified ? 'Verified' : 'Not verified',
              ),
              _Chip(
                profile.linkedToGoogle ? Icons.link_rounded : Icons.link_off_rounded,
                profile.linkedToGoogle ? 'Linked to Google' : 'Not linked to Google',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  c.missing.isEmpty
                      ? 'Profile complete'
                      : 'Profile ${(pct * 100).round()}% complete',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${c.done}/${c.total}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 7,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(royalGold),
              ),
            ),
          ),
          if (c.missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Add: ${c.missing.join(', ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: royalGold),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoursRowTile extends StatelessWidget {
  const _HoursRowTile({
    required this.row,
    required this.onToggle,
    required this.onPickOpen,
    required this.onPickClose,
  });

  final HoursRow row;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickOpen;
  final VoidCallback onPickClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              _dayLabels[row.day] ?? row.day,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: ink,
              ),
            ),
          ),
          Switch(
            value: !row.closed,
            onChanged: (open) => onToggle(!open),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: row.closed
                ? Text(
                    'Closed',
                    style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 13),
                  )
                : Row(
                    children: [
                      Flexible(
                        child: OutlinedButton(
                          onPressed: onPickOpen,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 38),
                          ),
                          child: FittedBox(child: Text(row.open)),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('to'),
                      ),
                      Flexible(
                        child: OutlinedButton(
                          onPressed: onPickClose,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 38),
                          ),
                          child: FittedBox(child: Text(row.close)),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReviewLinkCard extends StatelessWidget {
  const _ReviewLinkCard({required this.profile, required this.onMessage});

  final BusinessProfile profile;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ask customers for a review',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            profile.reviewUrl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: profile.reviewUrl));
                    onMessage('Review link copied');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                ),
              ),
              if (profile.shareWhatsapp.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(profile.shareWhatsapp),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
