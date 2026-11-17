import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The server mounts bulk send under /whatsapp, unlike templates and
/// campaigns. A call without that prefix answers "Not found" and the Bulk
/// sends list shows "Could not load bulk sends". These tests read the service
/// source so that mistake cannot come back unnoticed.
void main() {
  final source = File('lib/services/whatsapp_service.dart').readAsStringSync();

  test('bulk send calls all go through /whatsapp', () {
    expect(source, isNot(contains("'/bulk-send")));
    expect(source, contains("'/whatsapp/bulk-sends?page="));
    expect(source, contains("'/whatsapp/bulk-sends/\$id'"));
    expect(source, contains("'/whatsapp/bulk-sends/\$id/retry'"));
    expect(source, contains("'/whatsapp/bulk-send/upload-header'"));
    expect(source, contains("'/whatsapp/bulk-send',"));
  });

  test('templates and campaigns stay at the top level', () {
    expect(source, contains("'/templates"));
    expect(source, contains("'/campaigns"));
    expect(source, isNot(contains("'/whatsapp/templates")));
    expect(source, isNot(contains("'/whatsapp/campaigns")));
  });
}
