import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/services/platform_rules.dart';
import 'package:review_flow/services/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('push is off on iOS: Firebase is never started', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(pushNotificationsAvailable, isFalse);
    expect(await PushService.supported(), isFalse);
    expect(PushService.available, isFalse);
    expect(await PushService.isEnabled(), isFalse);
    expect(
      await PushService.enable(),
      'Notifications are not available in this version of the app.',
    );
  });

  test('push stays available on Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(pushNotificationsAvailable, isTrue);
  });
}
