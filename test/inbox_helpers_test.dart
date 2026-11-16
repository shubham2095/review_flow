import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/screens/whatsapp_inbox_screen.dart';

void main() {
  group('mediaPreview', () {
    test('turns media markers into an icon and a word', () {
      expect(mediaPreview('[Image]')?.label, 'Photo');
      expect(mediaPreview('[image]')?.label, 'Photo');
      expect(mediaPreview('[Video]')?.label, 'Video');
      expect(mediaPreview('[Audio]')?.label, 'Voice message');
      expect(mediaPreview('[Document]')?.label, 'Document');
      expect(mediaPreview('[Sticker]')?.label, 'Sticker');
      expect(mediaPreview('[Location]')?.label, 'Location');
      expect(mediaPreview('[Image]')?.icon, Icons.photo_outlined);
    });

    test('leaves ordinary text and captions alone', () {
      expect(mediaPreview('Hello there'), isNull);
      expect(mediaPreview(''), isNull);
      expect(mediaPreview('Here is the [Image] you asked for'), isNull);
      expect(mediaPreview('[Something else]'), isNull);
    });
  });

  group('shortWhen', () {
    test('is empty for no time, a clock time for today', () {
      expect(shortWhen(null), '');
      final now = DateTime.now();
      final text = shortWhen(DateTime(now.year, now.month, now.day, 15, 5));
      expect(text, '3:05 PM');
    });

    test('says Yesterday for the day before', () {
      final y = DateTime.now().subtract(const Duration(days: 1));
      expect(shortWhen(y), 'Yesterday');
    });
  });
}
