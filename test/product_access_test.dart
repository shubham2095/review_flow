import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/services/products.dart';
import 'package:review_flow/services/session.dart';

AppUser _user({
  List<String>? features,
  String status = 'active',
  bool superAdmin = false,
}) => AppUser.fromJson({
  'id': '1',
  'name': 'Shubham',
  'email': 's@example.com',
  'is_super_admin': superAdmin,
  'subscription': superAdmin ? null : {'status': status, 'plan_name': 'Plan'},
  'plan_features': features,
});

void main() {
  group('Product.unlockedFor follows the web and the server', () {
    test('a GBP-only plan opens GBP and keeps WhatsApp locked', () {
      final u = _user(features: ['dash_gbp', 'reports']);
      expect(Product.gbp.unlockedFor(u), isTrue);
      expect(Product.whatsapp.unlockedFor(u), isFalse);
    });

    test('a WhatsApp-only plan is the other way round', () {
      final u = _user(features: ['dash_whatsapp', 'chatbot']);
      expect(Product.whatsapp.unlockedFor(u), isTrue);
      expect(Product.gbp.unlockedFor(u), isFalse);
    });

    test('a plan with both dashboards opens both', () {
      final u = _user(features: ['dash_gbp', 'dash_whatsapp']);
      expect(Product.gbp.unlockedFor(u), isTrue);
      expect(Product.whatsapp.unlockedFor(u), isTrue);
    });

    test('a plan that lists features but no dashboard opens neither', () {
      // The server says no (feature:dash_gbp) and so does the web. The app
      // used to open both here, which is how WhatsApp showed as open.
      final u = _user(features: ['reports', 'social', 'chatbot']);
      expect(Product.gbp.unlockedFor(u), isFalse);
      expect(Product.whatsapp.unlockedFor(u), isFalse);
    });

    test('an empty feature list opens nothing', () {
      final u = _user(features: []);
      expect(Product.gbp.unlockedFor(u), isFalse);
      expect(Product.whatsapp.unlockedFor(u), isFalse);
    });

    test('a plan with no feature list at all opens everything', () {
      final u = _user();
      expect(Product.gbp.unlockedFor(u), isTrue);
      expect(Product.whatsapp.unlockedFor(u), isTrue);
    });

    test('no active plan locks both, whatever the features say', () {
      final u = _user(
        features: ['dash_gbp', 'dash_whatsapp'],
        status: 'expired',
      );
      expect(Product.gbp.unlockedFor(u), isFalse);
      expect(Product.whatsapp.unlockedFor(u), isFalse);
    });

    test('a super admin and nobody-signed-in', () {
      final admin = _user(superAdmin: true);
      expect(Product.gbp.unlockedFor(admin), isTrue);
      expect(Product.whatsapp.unlockedFor(admin), isTrue);
      expect(Product.gbp.unlockedFor(null), isFalse);
    });
  });
}
