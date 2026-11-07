import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/gbp_models.dart';
import '../services/api_service.dart';
import '../services/gbp_service.dart';
import '../services/platform_rules.dart';
import '../services/location_store.dart';
import '../services/web_handoff.dart';
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
  bool _reloading = false;
  bool _saving = false;
  bool _drafting = false;
  String? _error;
  List<HoursRow> _hours = [];

  /// The location the form currently shows (null = the top location).
  String? _loadedLocationId;
  bool _revertingLocation = false;

  /// Problems found on the last save attempt, by field key.
  Map<String, String> _errors = {};
  final Map<String, GlobalKey> _keys = {};

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
    _name,
    _category,
    _description,
    _phone,
    _website,
    _chatUrl,
    _address,
    _serviceArea,
    _labels,
    _openingDate,
  ];

  late final Map<String, TextEditingController> _errorFields = {
    'name': _name,
    'phone': _phone,
    'website': _website,
    'chat_url': _chatUrl,
  };

  GlobalKey _keyFor(String name) => _keys.putIfAbsent(name, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    LocationStore.selectedId.addListener(_onLocationChanged);
    // A field's red message goes away as soon as the person edits it.
    _errorFields.forEach((key, c) {
      c.addListener(() {
        if (_errors.containsKey(key)) setState(() => _errors.remove(key));
      });
    });
    _load();
  }

  @override
  void dispose() {
    LocationStore.selectedId.removeListener(_onLocationChanged);
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _message(String text, {String? actionLabel, VoidCallback? onAction}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: actionLabel == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  onPressed: onAction ?? () {},
                ),
        ),
      );
  }

  List<String> _split(String raw) =>
      raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  void _fill(BusinessProfile p) {
    // First, so the fields' own "clear my error" listeners find nothing to do.
    _errors = {};
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
    final id = LocationStore.selectedId.value;
    _loadedLocationId = id;
    if (mounted) {
      setState(() {
        if (_profile == null) {
          _loading = true;
        } else {
          _reloading = true;
        }
      });
    }
    try {
      final p = await GbpService.profile(locationId: id);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _fill(p);
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        if (_profile == null) {
          setState(() => _error = friendlyException(e).message);
        } else {
          _message(friendlyException(e).message);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _reloading = false;
        });
      }
    }
  }

  bool get _dirty => _changes().isNotEmpty;

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

  // ------------------------------------------------------------ unsaved edits

  Future<bool> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard your changes?'),
        content: const Text('What you edited has not been saved yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: bad),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Pull to refresh reloads the form, so ask before throwing edits away.
  Future<void> _refresh() async {
    if (_dirty && !await _confirmDiscard()) return;
    await _load();
  }

  /// Switching location replaces the whole form. With unsaved edits, let the
  /// person save them for the location they were editing, discard them, or
  /// stay where they were.
  Future<void> _onLocationChanged() async {
    if (!mounted) return;
    if (_revertingLocation) {
      _revertingLocation = false;
      return;
    }
    if (!_dirty) {
      await _load();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'You edited this location but have not saved yet. '
          'What should happen to those changes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'stay'),
            child: const Text('Stay here'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            style: TextButton.styleFrom(foregroundColor: bad),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save, then switch'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'discard') {
      await _load();
      return;
    }
    if (choice == 'save' && await _save()) {
      await _load();
      return;
    }
    // Stay (or the save failed): put the switcher back on the location whose
    // edits are still on screen.
    _revertingLocation = true;
    await LocationStore.select(_loadedLocationId);
  }

  void _discardEdits() {
    final p = _profile;
    if (p == null) return;
    HapticFeedback.selectionClick();
    setState(() => _fill(p));
  }

  // --------------------------------------------------------------- validation

  /// Adds https:// when missing. Returns null when the text cannot be a link.
  String? _normalizedUrl(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    final withScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(v)
        ? v
        : 'https://$v';
    final uri = Uri.tryParse(withScheme);
    final ok =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.') &&
        !withScheme.contains(' ');
    return ok ? withScheme : null;
  }

  /// Checks only what was changed, so an old odd value that was never touched
  /// does not block saving something else.
  Map<String, String> _validate(Map<String, dynamic> changes) {
    final e = <String, String>{};
    if (changes.containsKey('name') && _name.text.trim().isEmpty) {
      e['name'] = 'The business name cannot be empty.';
    }
    if (changes.containsKey('phone')) {
      final phone = _phone.text.trim();
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      final charsOk = RegExp(r'^[+\d\s\-()]+$').hasMatch(phone);
      if (phone.isNotEmpty &&
          (!charsOk || digits.length < 7 || digits.length > 15)) {
        e['phone'] = 'Enter a valid phone number, like +91 98765 43210.';
      }
    }
    for (final entry in {'website': _website, 'chat_url': _chatUrl}.entries) {
      if (changes.containsKey(entry.key) &&
          _normalizedUrl(entry.value.text) == null) {
        e[entry.key] = 'Enter a valid link, like https://example.com';
      }
    }
    if (changes.containsKey('hours')) {
      for (final h in _hours) {
        if (!h.closed && h.open == h.close) {
          e['hours'] =
              '${_dayLabels[h.day] ?? h.day} opens and closes at the same time.';
          break;
        }
      }
    }
    return e;
  }

  void _scrollToFirstError() {
    for (final key in const ['name', 'phone', 'website', 'chat_url', 'hours']) {
      if (!_errors.containsKey(key)) continue;
      final ctx = _keyFor(key).currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.15,
          curve: Curves.easeOut,
        );
      }
      return;
    }
  }

  // --------------------------------------------------------------------- save

  /// Returns true when the changes were saved (or there was nothing to save).
  Future<bool> _save() async {
    if (_saving) return false;
    var changes = _changes();
    if (changes.isEmpty) return true;

    final problems = _validate(changes);
    if (problems.isNotEmpty) {
      HapticFeedback.mediumImpact();
      setState(() => _errors = problems);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToFirstError(),
      );
      _message(
        problems.length == 1
            ? 'Fix the field marked in red to save.'
            : 'Fix the ${problems.length} fields marked in red to save.',
      );
      return false;
    }

    // Tidy links the person typed without https://, then send the tidy form.
    for (final entry in {'website': _website, 'chat_url': _chatUrl}.entries) {
      if (changes.containsKey(entry.key)) {
        entry.value.text = _normalizedUrl(entry.value.text) ?? entry.value.text;
      }
    }
    changes = _changes();

    setState(() {
      _saving = true;
      _errors = {};
    });
    try {
      final res = await GbpService.updateProfile(_loadedLocationId, changes);
      if (!mounted) return false;
      setState(() {
        _profile = res.profile;
        _fill(res.profile);
      });
      HapticFeedback.lightImpact();
      _message(
        res.message.isNotEmpty
            ? res.message
            : (res.syncedToGoogle ? 'Saved and updated on Google.' : 'Saved.'),
      );
      return true;
    } catch (e) {
      _message(friendlyException(e).message);
      return false;
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

    final before = _description.text;
    setState(() => _drafting = true);
    try {
      final res = await GbpService.aiRewriteDescription(
        locationId: _loadedLocationId,
        keywords: _split(keywords),
      );
      if (!mounted) return;
      setState(() => _description.text = res.text);
      // The old text is gone from the box: keep a way back.
      _message(
        'New description ready. Review it, then save. ${res.credits} credits left.',
        actionLabel: before.trim().isEmpty ? null : 'Undo',
        onAction: () => setState(() => _description.text = before),
      );
    } catch (e) {
      final err = friendlyException(e);
      // No buying from iOS (platform_rules.dart): the message alone, no button.
      if (err.isCreditsInsufficient && purchaseLinksAllowed) {
        _message(
          err.message,
          actionLabel: 'Buy credits',
          onAction: () async {
            try {
              await openInWeb(next: '/buy-credits');
            } catch (e) {
              _message(friendlyException(e).message);
            }
          },
        );
      } else {
        _message(err.message);
      }
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
      _errors.remove('hours');
    });
  }

  /// Most businesses keep the same hours every day: one tap instead of seven.
  void _copyMondayToAll() {
    final monday =
        _hours.where((h) => h.day == 'MONDAY').firstOrNull ??
        (_hours.isEmpty ? null : _hours.first);
    if (monday == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      for (final h in _hours) {
        h.open = monday.open;
        h.close = monday.close;
        h.closed = monday.closed;
      }
      _errors.remove('hours');
    });
    _message(
      "Copied ${_dayLabels[monday.day] ?? monday.day}'s hours to every day.",
    );
  }

  Future<void> _pickOpeningDate() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_openingDate.text.trim());
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    setState(
      () => _openingDate.text =
          '${picked.year}-${two(picked.month)}-${two(picked.day)}',
    );
  }

  InputDecoration _dec(String label, {String? hint, String? errorText}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
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
    int? maxLength,
    String? errorKey,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return KeyedSubtree(
      key: errorKey == null ? null : _keyFor(errorKey),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: type,
          textCapitalization: capitalization,
          minLines: 1,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: _dec(
            label,
            hint: hint,
            errorText: errorKey == null ? null : _errors[errorKey],
          ).copyWith(fillColor: surface),
        ),
      ),
    );
  }

  Widget _openingDateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _openingDate,
        readOnly: true,
        onTap: _pickOpeningDate,
        decoration: _dec('Opening date', hint: 'Tap to pick a date').copyWith(
          fillColor: surface,
          prefixIcon: const Icon(Icons.event_rounded, size: 20),
          suffixIcon: ListenableBuilder(
            listenable: _openingDate,
            builder: (context, _) => _openingDate.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear date',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => _openingDate.clear(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _saveBar(BusinessProfile? p) {
    final count = _changes().length;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: count == 0
          ? const SizedBox(width: double.infinity)
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFEEF1F7))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count == 1
                          ? '1 change not saved yet'
                          : '$count changes not saved yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _saving ? null : _discardEdits,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          child: const Text('Discard'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
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
                      ],
                    ),
                  ],
                ),
              ),
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
                // A different location is loading: show it, and keep the
                // old form from being edited meanwhile.
                if (_reloading) const LinearProgressIndicator(minHeight: 3),
                Expanded(
                  child: IgnorePointer(
                    ignoring: _reloading,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _reloading ? 0.5 : 1,
                      child: RefreshIndicator(
                        color: brand,
                        onRefresh: _refresh,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          physics: const AlwaysScrollableScrollPhysics(),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
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
                              _field(
                                _name,
                                'Business name',
                                errorKey: 'name',
                                capitalization: TextCapitalization.words,
                              ),
                              _field(
                                _category,
                                'Category',
                                capitalization: TextCapitalization.words,
                              ),
                              _field(
                                _description,
                                'Description',
                                maxLines: 6,
                                maxLength: 750,
                                type: TextInputType.multiline,
                                capitalization: TextCapitalization.sentences,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _drafting ? null : _aiRewrite,
                                  icon: _drafting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 18,
                                        ),
                                  label: const Text('Improve with AI'),
                                ),
                              ),
                            ]),
                            _section('Contact', [
                              _field(
                                _phone,
                                'Phone',
                                type: TextInputType.phone,
                                errorKey: 'phone',
                              ),
                              _field(
                                _website,
                                'Website',
                                type: TextInputType.url,
                                errorKey: 'website',
                              ),
                              _field(
                                _chatUrl,
                                'Chat link (optional)',
                                type: TextInputType.url,
                                errorKey: 'chat_url',
                              ),
                            ]),
                            _section('Location', [
                              _field(
                                _address,
                                'Address',
                                maxLines: 3,
                                capitalization: TextCapitalization.words,
                              ),
                              _field(
                                _serviceArea,
                                'Service areas',
                                hint: 'Noida, Ghaziabad, Delhi',
                                capitalization: TextCapitalization.words,
                              ),
                            ]),
                            _section('Opening hours', [
                              KeyedSubtree(
                                key: _keyFor('hours'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final h in _hours)
                                      _HoursRowTile(
                                        row: h,
                                        onToggle: (closed) => setState(() {
                                          h.closed = closed;
                                          _errors.remove('hours');
                                        }),
                                        onPickOpen: () => _pickTime(h, true),
                                        onPickClose: () => _pickTime(h, false),
                                      ),
                                    if (_errors['hours'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 2,
                                          bottom: 6,
                                        ),
                                        child: Text(
                                          _errors['hours']!,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: bad,
                                          ),
                                        ),
                                      ),
                                    if (_hours.length > 1)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: _copyMondayToAll,
                                          icon: const Icon(
                                            Icons.copy_all_rounded,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            "Copy Monday's hours to all days",
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ]),
                            _section('More', [
                              _field(
                                _labels,
                                'Labels',
                                hint: 'Separate with commas',
                              ),
                              _openingDateField(),
                            ]),
                            if (p != null && p.reviewUrl.isNotEmpty)
                              _ReviewLinkCard(profile: p, onMessage: _message),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: Listenable.merge(_controllers),
                  builder: (context, _) => _saveBar(p),
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
              _Chip(
                Icons.star_rounded,
                '${profile.rating.toStringAsFixed(1)} (${profile.reviewCount})',
              ),
              _Chip(
                profile.isVerified
                    ? Icons.verified_rounded
                    : Icons.error_outline_rounded,
                profile.isVerified ? 'Verified' : 'Not verified',
              ),
              _Chip(
                profile.linkedToGoogle
                    ? Icons.link_rounded
                    : Icons.link_off_rounded,
                profile.linkedToGoogle
                    ? 'Linked to Google'
                    : 'Not linked to Google',
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
          Switch(value: !row.closed, onChanged: (open) => onToggle(!open)),
          const SizedBox(width: 4),
          Expanded(
            child: row.closed
                ? Text(
                    'Closed',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 13,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: OutlinedButton(
                              onPressed: onPickOpen,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                minimumSize: const Size(0, 38),
                              ),
                              child: FittedBox(child: Text(row.close)),
                            ),
                          ),
                        ],
                      ),
                      // "HH:mm" text compares in clock order.
                      if (row.close.compareTo(row.open) < 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Closes the next day',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: muted,
                            ),
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
                    await Clipboard.setData(
                      ClipboardData(text: profile.reviewUrl),
                    );
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
