import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/brand.dart';
import 'wa_ui.dart';

/// What a piece of a message is.
enum LinkKind { text, url, phone }

/// One piece of a message: plain text, a web link or a phone number.
class LinkPart {
  const LinkPart(this.text, this.kind);

  final String text;
  final LinkKind kind;

  /// The address to open for a link ("https://..." or "tel:+91..."). Null for
  /// plain text.
  String? get target {
    switch (kind) {
      case LinkKind.text:
        return null;
      case LinkKind.url:
        return text.toLowerCase().startsWith('http') ? text : 'https://$text';
      case LinkKind.phone:
        final plus = text.trimLeft().startsWith('+') ? '+' : '';
        return 'tel:$plus${text.replaceAll(RegExp(r'\D'), '')}';
    }
  }
}

final _linkPattern = RegExp(
  r'(https?://[^\s]+|www\.[^\s]+)|(\+?\d[\d \-()]{6,}\d)',
  caseSensitive: false,
);

/// Splits a message into plain text, web links and phone numbers (8 to 15
/// digits). Punctuation that ends a sentence ("see www.x.com.") is not part of
/// the link.
List<LinkPart> splitLinks(String text) {
  final parts = <LinkPart>[];
  var last = 0;

  void addText(String s) {
    if (s.isEmpty) return;
    if (parts.isNotEmpty && parts.last.kind == LinkKind.text) {
      final merged = parts.removeLast().text + s;
      parts.add(LinkPart(merged, LinkKind.text));
    } else {
      parts.add(LinkPart(s, LinkKind.text));
    }
  }

  for (final m in _linkPattern.allMatches(text)) {
    addText(text.substring(last, m.start));
    final found = m.group(0)!;
    if (m.group(1) != null) {
      // A web link: drop trailing punctuation that belongs to the sentence.
      var end = found.length;
      while (end > 0 && '.,;:!?)\'"'.contains(found[end - 1])) {
        end--;
      }
      final link = found.substring(0, end);
      if (link.length > 4) {
        parts.add(LinkPart(link, LinkKind.url));
        addText(found.substring(end));
      } else {
        addText(found);
      }
    } else {
      final digits = found.replaceAll(RegExp(r'\D'), '').length;
      if (digits >= 8 && digits <= 15) {
        parts.add(LinkPart(found.trim(), LinkKind.phone));
        if (found.length != found.trim().length) {
          addText(found.substring(found.trim().length));
        }
      } else {
        addText(found);
      }
    }
    last = m.end;
  }
  addText(text.substring(last));
  return parts;
}

/// Message text where web links and phone numbers can be tapped (a link opens
/// in the browser, a number opens the dialer).
class LinkifiedText extends StatefulWidget {
  const LinkifiedText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];
  List<InlineSpan> _spans = const [];

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(covariant LinkifiedText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.style != widget.style) _build();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _open(String target) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(target),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) showToast(context, 'Could not open that.');
  }

  void _build() {
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    for (final part in splitLinks(widget.text)) {
      final target = part.target;
      if (target == null) {
        spans.add(TextSpan(text: part.text));
      } else {
        final recognizer = TapGestureRecognizer()..onTap = () => _open(target);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: part.text,
            recognizer: recognizer,
            style: const TextStyle(
              color: brand,
              decoration: TextDecoration.underline,
              decorationColor: brand,
            ),
          ),
        );
      }
    }
    _spans = spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(style: widget.style, children: _spans));
  }
}
