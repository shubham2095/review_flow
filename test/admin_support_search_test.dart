import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/services/admin_service.dart';

void main() {
  group('supportTicketsPath', () {
    test('no filter is the plain list', () {
      expect(supportTicketsPath(), '/support/admin/all');
      expect(
        supportTicketsPath(status: '', search: '  '),
        '/support/admin/all',
      );
    });

    test('status only', () {
      expect(
        supportTicketsPath(status: 'open'),
        '/support/admin/all?status=open',
      );
    });

    test('search only, trimmed', () {
      expect(
        supportTicketsPath(search: '  TKT-12 '),
        '/support/admin/all?search=TKT-12',
      );
    });

    test('both, with special characters encoded', () {
      final path = supportTicketsPath(
        status: 'in_progress',
        search: 'login & otp',
      );
      final uri = Uri.parse(path);
      expect(uri.path, '/support/admin/all');
      expect(uri.queryParameters, {
        'status': 'in_progress',
        'search': 'login & otp',
      });
    });
  });
}
