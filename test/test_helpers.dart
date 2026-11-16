import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// google_fonts tries to download its fonts and cannot inside a test. That is
/// not a bug in the screen, so it is the only error these tests ignore.
bool isFontError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('google_fonts') ||
      text.contains('googlefonts') ||
      text.contains('failed to load font') ||
      text.contains('allowruntimefetching');
}

/// Call at the start of a test: swallows font download complaints only.
void ignoreFontErrors() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (isFontError(details.exception)) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

/// Fails the test if a real (non-font) exception was thrown while building or
/// updating widgets.
void expectNoRealErrors(WidgetTester tester) {
  Object? error;
  while ((error = tester.takeException()) != null) {
    if (!isFontError(error!)) {
      fail('A widget threw while building: $error');
    }
  }
}
