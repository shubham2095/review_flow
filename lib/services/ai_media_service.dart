import '../models/ai_media_models.dart';
import 'api_service.dart';

/// AI Studio (/api/v1/ai-media). Making an image uses AI credits, but only
/// when the image AI really produced one.
class AiMediaService {
  AiMediaService._();

  static final _api = ApiService.instance;

  /// The latest images (up to 100).
  static Future<List<AiMedia>> list() async =>
      aiMediaList(await _api.get('/ai-media'));

  /// Makes an image from [prompt]. With [reference] (a photo as bytes) the AI
  /// builds on that photo. The file name's ending (jpg, png or webp) must match
  /// the picture, because the server checks it.
  static Future<AiMediaResult> generate(
    String prompt, {
    List<int>? reference,
    String referenceName = 'reference.jpg',
  }) async {
    final res = reference == null
        ? await _api.post(
            '/ai-media',
            body: {'prompt': prompt},
            timeout: kAiTimeout,
          )
        : await _api.upload(
            '/ai-media',
            field: 'image',
            bytes: reference,
            filename: referenceName,
            fields: {'prompt': prompt},
          );
    return AiMediaResult.fromJson(res);
  }

  static Future<void> delete(String id) async => _api.delete('/ai-media/$id');
}
