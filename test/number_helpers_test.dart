import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/screens/whatsapp_number_sheet.dart';

void main() {
  group('qualityMeaning', () {
    test('explains green, yellow and red in any case', () {
      expect(qualityMeaning('GREEN'), contains('happy'));
      expect(qualityMeaning('Yellow'), contains('blocking or reporting'));
      expect(qualityMeaning('red'), contains('may limit'));
    });

    test('is null when empty or unknown', () {
      expect(qualityMeaning(''), isNull);
      expect(qualityMeaning('UNKNOWN'), isNull);
    });
  });

  group('numberStatusMeaning', () {
    test('explains known statuses', () {
      expect(numberStatusMeaning('CONNECTED'), contains('working'));
      expect(numberStatusMeaning('pending'), contains('Refresh from Meta'));
      expect(numberStatusMeaning('Flagged'), contains('flagged'));
    });

    test('is null when empty or unknown', () {
      expect(numberStatusMeaning(''), isNull);
      expect(numberStatusMeaning('SOMETHING_NEW'), isNull);
    });
  });
}
