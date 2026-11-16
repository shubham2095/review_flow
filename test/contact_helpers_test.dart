import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/screens/whatsapp_contact_sheet.dart';

void main() {
  group('parseTags', () {
    test('splits on commas, semicolons and bars and trims', () {
      expect(parseTags('vip, delhi;lead | hot'), [
        'vip',
        'delhi',
        'lead',
        'hot',
      ]);
    });

    test('drops empty pieces and duplicates, ignoring capitals', () {
      expect(parseTags(' vip ,, VIP, delhi,'), ['vip', 'delhi']);
    });

    test('adds to the tags already there without repeating them', () {
      expect(parseTags('Delhi, new', existing: ['vip', 'delhi']), [
        'vip',
        'delhi',
        'new',
      ]);
    });

    test('empty text adds nothing', () {
      expect(parseTags('   '), isEmpty);
      expect(parseTags('', existing: ['a']), ['a']);
    });
  });
}
