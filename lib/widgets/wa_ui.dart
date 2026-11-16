import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/brand.dart';
import 'count_up.dart';
import 'pressable.dart';

// Shared building blocks for the WhatsApp screens. Every widget here already
// carries its Semantics label and meets the 48 dp touch target, so a screen
// that uses it is accessible by default.

/// Small coloured pill for a status ("Approved", "Sending", "Draft").
/// Read aloud as "Status: Approved" (the text), so colour is never the only signal.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.text, this.color, {super.key, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: $text',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Neutral tag for a fact ("Quality Green", "Default", "Utility").
class InfoChip extends StatelessWidget {
  const InfoChip(this.label, {super.key, this.icon, this.color = muted});

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(child: Icon(icon, size: 13, color: color)),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A heading for a group of rows. Announced as a heading to screen readers.
class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.text, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 24, 4, 12),
  });

  final String text;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The frame every bottom sheet shares: drag handle, title, optional line of
/// help, scrolling content, room for the keyboard, and a safe area.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
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
              ExcludeSemantics(
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: ink,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: muted,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens an [AppSheet] with the shared look. Returns what the sheet pops with.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  String? subtitle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => AppSheet(title: title, subtitle: subtitle, child: child),
  );
}

/// The text-field look shared by every WhatsApp form. [onWhite] is true inside
/// white sheets (grey fill) and false on the grey page background (white fill).
InputDecoration waInputDecoration(
  String label, {
  String? hint,
  String? helper,
  bool onWhite = true,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    filled: true,
    fillColor: onWhite ? surface : Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  );
}

/// One snack bar style for the whole area: replaces the one on screen, and an
/// optional action ("Undo", "Open").
void showToast(
  BuildContext context,
  String text, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
}

/// A round avatar with the person's first initial on a soft colour that stays
/// the same for the same name. Decorative: the name next to it is what screen
/// readers read.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.name, this.radius = 22});

  final String name;
  final double radius;

  static const _palette = [
    Color(0xFF3B5BDB),
    Color(0xFF7048E8),
    Color(0xFF0C8599),
    Color(0xFF2B8A3E),
    Color(0xFFD9480F),
    Color(0xFFC2255C),
    Color(0xFF5F3DC4),
    Color(0xFF1864AB),
  ];

  /// Same name, same colour, every launch (String.hashCode is not stable).
  static Color colorFor(String name) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return muted;
    var sum = 0;
    for (final unit in key.codeUnits) {
      sum = (sum * 31 + unit) & 0x7fffffff;
    }
    return _palette[sum % _palette.length];
  }

  /// The first letter in capitals, or "?" when there is no name.
  static String initialOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(name);
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: color.withValues(alpha: 0.14),
        child: Text(
          initialOf(name),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: radius * 0.8,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Keeps content readable on wide screens (tablets, landscape): centred, at
/// most [maxWidth] wide. On a phone it changes nothing.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A number with a label ("Unread 5"). With [onTap] it is a button, announced
/// as "Unread: 5" (label, then value) and activated by a double tap.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = highlight ? brand : muted;
    final tile = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tone),
          const SizedBox(height: 10),
          CountUp(
            value: value,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
    return Semantics(
      label: '$label: $value',
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: onTap == null ? tile : Pressable(onTap: onTap, child: tile),
    );
  }
}

/// A thin progress bar that reads out as text ("120 of 300 handled") instead of
/// a bare percentage.
class AppProgress extends StatelessWidget {
  const AppProgress({
    super.key,
    required this.value,
    required this.label,
    this.color = brand,
    this.height = 6,
  });

  /// 0 to 1.
  final double value;

  /// What a screen reader says, for example "120 of 300 handled".
  final String label;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: height,
          color: color,
          backgroundColor: track,
        ),
      ),
    );
  }
}

/// One slice of a [StackedBar].
class BarSegment {
  const BarSegment(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

/// A single bar made of coloured slices (for example read, delivered, sent,
/// failed) out of [total], with whatever is left shown as "waiting". A legend
/// under it names every slice with its number, so colour is never the only cue.
class StackedBar extends StatelessWidget {
  const StackedBar({
    super.key,
    required this.total,
    required this.segments,
    this.height = 12,
    this.restLabel = 'Waiting',
  });

  final int total;
  final List<BarSegment> segments;
  final double height;

  /// Name of the unfilled part (total minus the slices).
  final String restLabel;

  @override
  Widget build(BuildContext context) {
    final shown = segments.where((s) => s.value > 0).toList();
    final sum = shown.fold<int>(0, (a, s) => a + s.value);
    // The unfilled part. If the slices add up to more than the total (counts
    // that overlap), the bar simply shows their proportions.
    final rest = total > sum ? total - sum : 0;
    final spoken = [
      for (final s in shown) '${s.label} ${s.value}',
      if (rest > 0) '$restLabel $rest',
    ].join(', ');

    return Semantics(
      label: spoken.isEmpty ? 'Nothing yet' : '$spoken, out of $total',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(height),
            child: SizedBox(
              height: height,
              child: shown.isEmpty && rest == 0
                  ? const ColoredBox(color: track)
                  : Row(
                      children: [
                        for (final s in shown)
                          Expanded(
                            flex: s.value,
                            child: ColoredBox(color: s.color),
                          ),
                        if (rest > 0)
                          Expanded(flex: rest, child: const ColoredBox(color: track)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final s in shown) _LegendItem(s.color, '${s.label} ${s.value}'),
              if (rest > 0) _LegendItem(muted, '$restLabel $rest'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.color, this.text);

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: inkSoft),
        ),
      ],
    );
  }
}
