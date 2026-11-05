import 'package:flutter/material.dart';
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
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openSheet(context),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 130),
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

class _LocationSheet extends StatelessWidget {
  const _LocationSheet();

  @override
  Widget build(BuildContext context) {
    final locations = LocationStore.locations.value;
    final selected = LocationStore.selectedId.value;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
            _Tile(
              title: 'All locations',
              subtitle: '${locations.length} locations combined',
              selected: selected == null,
              onTap: () => _pick(context, null),
            ),
            for (final l in locations)
              _Tile(
                title: l.name,
                subtitle: _subtitle(l),
                selected: selected == l.id,
                onTap: () => _pick(context, l.id),
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
