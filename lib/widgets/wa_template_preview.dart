import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../theme/brand.dart';

/// A piece of a template body: plain text, or the number of a `{{n}}` field.
class BodyPart {
  const BodyPart.text(this.text) : field = null;
  const BodyPart.field(int this.field, this.text);

  /// What to show: the text itself, or the example for a field (or "{{n}}"
  /// when no example was given yet).
  final String text;

  /// The field number for `{{n}}`, null for plain text.
  final int? field;
}

final _fieldPattern = RegExp(r'\{\{\s*(\d+)\s*\}\}');

/// Splits a template body around its `{{1}}`, `{{2}}` fields. A field is shown
/// as its example when one is given, otherwise as `{{n}}`.
List<BodyPart> splitFields(String body, Map<int, String> examples) {
  final parts = <BodyPart>[];
  var last = 0;
  for (final m in _fieldPattern.allMatches(body)) {
    if (m.start > last) parts.add(BodyPart.text(body.substring(last, m.start)));
    final n = int.parse(m.group(1)!);
    final example = (examples[n] ?? '').trim();
    parts.add(BodyPart.field(n, example.isEmpty ? '{{$n}}' : example));
    last = m.end;
  }
  if (last < body.length) parts.add(BodyPart.text(body.substring(last)));
  return parts;
}

/// How a template looks on the customer's phone: the message bubble on a chat
/// background, with its buttons underneath. Used while writing a template and
/// when reading one.
class WaTemplatePreview extends StatelessWidget {
  const WaTemplatePreview({
    super.key,
    required this.body,
    this.headerFormat = '',
    this.headerText = '',
    this.footer = '',
    this.buttons = const [],
    this.examples = const {},
  });

  final String body;

  /// TEXT, IMAGE, VIDEO or DOCUMENT; empty or NONE for no header.
  final String headerFormat;
  final String headerText;
  final String footer;
  final List<WaTemplateButton> buttons;

  /// Example values for `{{n}}` fields, by number.
  final Map<int, String> examples;

  bool get _mediaHeader =>
      headerFormat == 'IMAGE' ||
      headerFormat == 'VIDEO' ||
      headerFormat == 'DOCUMENT';

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.plusJakartaSans(
      fontSize: 13.5,
      height: 1.4,
      color: ink,
    );
    final text = body.trim();
    return Semantics(
      container: true,
      label: 'Preview of the message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: waChatBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: waBubbleIn,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_mediaHeader)
                    Container(
                      height: 90,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: muted.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            switch (headerFormat) {
                              'VIDEO' => Icons.play_circle_outline_rounded,
                              'DOCUMENT' => Icons.insert_drive_file_outlined,
                              _ => Icons.photo_outlined,
                            },
                            color: muted,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${headerFormat[0]}${headerFormat.substring(1).toLowerCase()} header',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (headerFormat == 'TEXT' && headerText.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        headerText.trim(),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                    ),
                  if (text.isEmpty)
                    Text(
                      'Your message appears here as you type.',
                      style: style.copyWith(
                        color: muted,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Text.rich(
                      TextSpan(
                        style: style,
                        children: [
                          for (final p in splitFields(text, examples))
                            TextSpan(
                              text: p.text,
                              style: p.field == null
                                  ? null
                                  : TextStyle(
                                      color: brand,
                                      fontWeight: FontWeight.w700,
                                      backgroundColor: brand.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    ),
                  if (footer.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        footer.trim(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (final b in buttons)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: waBubbleIn,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          b.type == 'URL'
                              ? Icons.open_in_new_rounded
                              : b.type == 'PHONE_NUMBER'
                              ? Icons.call_rounded
                              : b.type == 'COPY_CODE'
                              ? Icons.copy_rounded
                              : Icons.reply_rounded,
                          size: 16,
                          color: brand,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          b.text.isEmpty ? 'Button' : b.text,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
