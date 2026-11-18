import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/services/api_service.dart';
import 'package:review_flow/widgets/offline_banner.dart';

void main() {
  group('savedWhy', () {
    test('no connection is offline', () {
      expect(savedWhy(ApiException('x', code: 'offline')), SavedWhy.offline);
    });

    test('a timeout is a slow server, not the person\'s Wi-Fi', () {
      expect(savedWhy(ApiException('x', code: 'timeout')), SavedWhy.slow);
    });

    test('a server error is the server', () {
      expect(savedWhy(ApiException('x', statusCode: 500)), SavedWhy.server);
      expect(savedWhy(ApiException('x', statusCode: 503)), SavedWhy.server);
    });
  });

  group('savedBarMessage', () {
    test('says "offline" only for a real lack of connection', () {
      expect(
        savedBarMessage(SavedWhy.offline, '4 min ago'),
        "You're offline. Showing data saved 4 min ago.",
      );
      expect(
        savedBarMessage(SavedWhy.slow, 'just now'),
        isNot(contains('offline')),
      );
      expect(
        savedBarMessage(SavedWhy.server, '4 min ago'),
        'Eydia is not responding right now. Showing data saved 4 min ago.',
      );
    });
  });

  test('only unreachable errors count as "show the saved copy"', () {
    expect(ApiException('x', statusCode: 500).isUnreachable, isTrue);
    expect(ApiException('x', code: 'offline').isUnreachable, isTrue);
    expect(ApiException('x', code: 'timeout').isUnreachable, isTrue);
    // A 4xx is an answer, not a missing connection.
    expect(ApiException('x', statusCode: 404).isUnreachable, isFalse);
    expect(ApiException('x', statusCode: 403).isUnreachable, isFalse);
  });
}
