import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/models/ai_media_models.dart';
import 'package:review_flow/screens/ai_studio_screen.dart';

/// A 1x1 transparent PNG.
const tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  group('aiMediaBytes', () {
    test('decodes a base64 picture address', () {
      final bytes = aiMediaBytes('data:image/png;base64,$tinyPng');
      expect(bytes, isNotNull);
      expect(bytes!.first, 0x89); // PNG signature
    });

    test('the server placeholder is an SVG and is not drawn', () {
      final svg = base64Encode(
        utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"/>'),
      );
      expect(aiMediaBytes('data:image/svg+xml;base64,$svg'), isNull);
    });

    test('empty, plain or broken addresses give nothing', () {
      expect(aiMediaBytes(''), isNull);
      expect(aiMediaBytes('https://example.com/a.png'), isNull);
      expect(aiMediaBytes('data:image/png,not-base64'), isNull);
      expect(aiMediaBytes('data:image/png;base64,%%%'), isNull);
      expect(aiMediaBytes('data:image/png;base64,'), isNull);
    });
  });

  group('aiMediaExtension', () {
    test('recognises png, jpeg and webp', () {
      expect(aiMediaExtension([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]), 'png');
      expect(aiMediaExtension([0xFF, 0xD8, 0xFF, 0xE0]), 'jpg');
      expect(
        aiMediaExtension([
          0x52,
          0x49,
          0x46,
          0x46,
          0,
          0,
          0,
          0,
          0x57,
          0x45,
          0x42,
          0x50,
        ]),
        'webp',
      );
    });

    test('falls back to png', () {
      expect(aiMediaExtension(const []), 'png');
      expect(aiMediaExtension([1, 2, 3]), 'png');
    });
  });

  group('models', () {
    test('AiMedia reads a list entry and knows if it has a picture', () {
      final list = aiMediaList({
        'media': [
          {
            'id': 'm1',
            'prompt': 'Diwali banner',
            'image_data': 'data:image/png;base64,$tinyPng',
            'source': 'ai',
            'created_at': '2026-11-16T10:00:00Z',
          },
          {
            'id': 'm2',
            'prompt': 'Placeholder',
            'image_data': 'data:image/svg+xml;base64,PHN2Zy8+',
            'source': 'fallback',
          },
        ],
      });
      expect(list, hasLength(2));
      expect(list.first.hasImage, isTrue);
      expect(list.first.createdAt, isNotNull);
      expect(list.last.hasImage, isFalse);
    });

    test('AiMediaResult says whether an image was really made', () {
      expect(
        AiMediaResult.fromJson({
          'media': {'id': 'm1', 'prompt': 'x'},
          'source': 'ai',
        }).madeImage,
        isTrue,
      );
      expect(
        AiMediaResult.fromJson({
          'media': {'id': 'm1', 'prompt': 'x'},
          'source': 'fallback',
        }).madeImage,
        isFalse,
      );
    });
  });

  test('aiPromptProblem', () {
    expect(aiPromptProblem('  '), isNotNull);
    expect(aiPromptProblem('a' * 1001), isNotNull);
    expect(aiPromptProblem('A Diwali offer banner'), isNull);
  });
}
