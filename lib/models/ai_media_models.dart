import 'dart:convert';
import 'dart:typed_data';

import 'gbp_models.dart' show asDate, asMap, asMaps, asStr;

/// One image made in AI Studio: GET /ai-media.
class AiMedia {
  const AiMedia({
    required this.id,
    required this.prompt,
    this.imageData = '',
    this.source = '',
    this.createdAt,
  });

  factory AiMedia.fromJson(Map<String, dynamic> j) => AiMedia(
    id: asStr(j['id']),
    prompt: asStr(j['prompt']),
    imageData: asStr(j['image_data']),
    source: asStr(j['source']),
    createdAt: asDate(j['created_at']),
  );

  final String id;
  final String prompt;

  /// The picture as a `data:image/...;base64,` address.
  final String imageData;

  /// `ai` for a real image, `fallback` for the grey placeholder the server
  /// saves when the image AI could not make one.
  final String source;
  final DateTime? createdAt;

  /// True when this is a real picture the phone can show and share.
  bool get hasImage => aiMediaBytes(imageData) != null;
}

/// What POST /ai-media returns.
class AiMediaResult {
  const AiMediaResult({required this.media, required this.madeImage});

  factory AiMediaResult.fromJson(Map<String, dynamic> j) => AiMediaResult(
    media: AiMedia.fromJson(asMap(j['media'])),
    madeImage: asStr(j['source']) == 'ai',
  );

  final AiMedia media;

  /// False when only a placeholder was saved (and no credits were used).
  final bool madeImage;
}

List<AiMedia> aiMediaList(Map<String, dynamic> res) =>
    asMaps(res['media']).map(AiMedia.fromJson).toList();

/// The picture bytes of a base64 `data:` address. Null when it is not an
/// image the phone can draw (empty, not base64, or SVG: the server's
/// placeholder is an SVG).
Uint8List? aiMediaBytes(String dataUri) {
  if (!dataUri.startsWith('data:image/')) return null;
  final comma = dataUri.indexOf(',');
  if (comma < 0) return null;
  final head = dataUri.substring(0, comma).toLowerCase();
  if (!head.contains(';base64') || head.contains('svg')) return null;
  try {
    final bytes = base64Decode(dataUri.substring(comma + 1));
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}

/// `png`, `jpg` or `webp`, judged from the first bytes; `png` when unsure.
String aiMediaExtension(List<int> bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'webp';
  }
  return 'png';
}
