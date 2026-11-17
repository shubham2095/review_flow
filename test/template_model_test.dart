import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/models/whatsapp_models.dart';

WaTemplate _template(String body) => WaTemplate.fromJson({
  'id': 't1',
  'name': 'eydia_service_update',
  'language': 'en_US',
  'category': 'MARKETING',
  'status': 'APPROVED',
  'components': [
    {'type': 'BODY', 'text': body},
  ],
});

void main() {
  group('WaTemplate.bodyVariables', () {
    test('finds {{1}} so a bulk send asks for its value', () {
      expect(_template('Hello {{1}},\n\nThank you.').bodyVariables, [1]);
    });

    test('lists each field once, in order', () {
      expect(
        _template('Hi {{2}}, order {{1}} for {{2}} and {{3}}').bodyVariables,
        [1, 2, 3],
      );
    });

    test('allows spaces inside the braces', () {
      expect(_template('Hi {{ 1 }} and {{2  }}').bodyVariables, [1, 2]);
    });

    test('a template without fields has none', () {
      expect(_template('Your request was received.').bodyVariables, isEmpty);
    });

    test('plain text that only looks similar is not a field', () {
      expect(_template('{{name}} and {{}} and { {1} }').bodyVariables, isEmpty);
    });
  });
}
