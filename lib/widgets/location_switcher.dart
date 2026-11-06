import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/gbp_models.dart';
import '../services/location_store.dart';
import '../theme/brand.dart';

/// Compact chip for the top bar: shows the selected location and opens a sheet
/// to change it. Hidden when the account has fewer than two locations.
class LocationSwitcher extends StatelessWidget {
  const LocationSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LocationStore.locations,
        LocationStore.selectedId,
      ]),
      builder: (context, _) {
        final locations = LocationStore.locations.value;
        if (locations.length < 2) return const SizedBox.shrink();
        final label = LocationStore.selected?.name ?? 'All locations';
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Semantics(
            button: true,
            label: 'Location: $label. Tap to change.',
            excludeSemantics: true,
            child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openSheet(context),
            child: Container(
              // At least 44dp tall so it is easy to hit.
              constraints: const BoxConstraints(maxWidth: 130, minHeight: 44),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.place_rounded, size: 15, color: brand),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: brand,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 16, color: brand),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  static Future<void> _openSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => const _LocationSheet(),
    );
  }
}

class _LocationSheet extends StatefulWidget {
  const _LocationSheet();

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  /// With many locations, scrolling to find one is slow: offer a search.
  static const _searchFrom = 6;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = LocationStore.locations.value;
    final selected = LocationStore.selectedId.value;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? all
        : all
            .where(
              (l) =>
                  l.name.toLowerCase().contains(q) ||
                  l.address.toLowerCase().contains(q),
            )
            .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
        ),
        child: ListView(
          shrinkWrap: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                'Choose location',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ),
            if (all.length > _searchFrom)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search ${all.length} locations',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    filled: true,
                    fillColor: surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            if (q.isEmpty)
              _Tile(
                title: 'All locations',
                subtitle: '${all.length} locations combined',
                selected: selected == null,
                onTap: () => _pick(context, null),
              ),
            for (final l in shown)
              _Tile(
                title: l.name,
                subtitle: _subtitle(l),
                selected: selected == l.id,
                onTap: () => _pick(context, l.id),
              ),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No location matches "$_query".',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: muted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _subtitle(GbpLocation l) {
    final parts = <String>[
      if (l.address.isNotEmpty) l.address,
      '${l.rating.toStringAsFixed(1)} stars, ${l.reviewCount} reviews',
    ];
    return parts.join(' · ');
  }

  static void _pick(BuildContext context, String? id) {
    HapticFeedback.selectionClick();
    LocationStore.select(id);
    Navigator.of(context).pop();
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? brand.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? brand : const Color(0xFFE6EAF2),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: brand)
            : null,
      ),
    );
  }
}
