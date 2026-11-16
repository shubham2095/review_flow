import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/models/whatsapp_models.dart';
import 'package:review_flow/screens/whatsapp_analytics_screen.dart';
import 'package:review_flow/screens/whatsapp_blacklist_screen.dart';
import 'package:review_flow/screens/whatsapp_bots_screen.dart';
import 'package:review_flow/screens/whatsapp_bulk_create_screen.dart';
import 'package:review_flow/screens/whatsapp_bulk_detail_screen.dart';
import 'package:review_flow/screens/whatsapp_campaign_create_screen.dart';
import 'package:review_flow/screens/whatsapp_campaign_detail_screen.dart';
import 'package:review_flow/screens/whatsapp_campaigns_screen.dart';
import 'package:review_flow/screens/whatsapp_chat_screen.dart';
import 'package:review_flow/screens/whatsapp_chatbot_screen.dart';
import 'package:review_flow/screens/whatsapp_connect_sheet.dart';
import 'package:review_flow/screens/whatsapp_contact_sheet.dart';
import 'package:review_flow/screens/whatsapp_contacts_screen.dart';
import 'package:review_flow/screens/whatsapp_inbox_screen.dart';
import 'package:review_flow/screens/whatsapp_number_sheet.dart';
import 'package:review_flow/screens/whatsapp_screen.dart';
import 'package:review_flow/screens/whatsapp_shell.dart';
import 'package:review_flow/screens/whatsapp_template_create_screen.dart';
import 'package:review_flow/screens/whatsapp_template_picker.dart';
import 'package:review_flow/screens/whatsapp_template_sheet.dart';
import 'package:review_flow/screens/whatsapp_templates_screen.dart';
import 'package:review_flow/screens/whatsapp_workflow_screen.dart';

import 'test_helpers.dart';

// Smoke test: every WhatsApp screen and sheet builds without throwing and
// leaves no timer running after it is removed. There is no server in a test,
// so the screens end up on their error or empty states; that is expected, the
// test only guards against crashes (and against timers that never stop).

final _conversation = WaConversation.fromJson({
  'id': 'conv-1',
  'status': 'open',
  'unread_count': 2,
  'window_open': true,
  'last_message_preview': 'Hello',
  'contact': {'id': 'c1', 'name': 'Priya', 'phone': '919876543210'},
});

final _number = WaNumber.fromJson({
  'id': 'num-1',
  'phone_number_id': '123',
  'display_phone_number': '+91 98765 43210',
  'verified_name': 'Eydia',
  'quality_rating': 'GREEN',
  'status': 'connected',
  'is_default': true,
  'is_registered': false,
});

final _contact = WaContactRecord.fromJson({
  'id': 'c1',
  'phone': '919876543210',
  'name': 'Priya',
  'tag_list': 'vip, delhi',
  'is_hot': true,
});

final _template = WaTemplate.fromJson({
  'id': 't1',
  'name': 'order_update',
  'language': 'en_US',
  'category': 'UTILITY',
  'status': 'APPROVED',
  'components': [
    {'type': 'BODY', 'text': 'Hi, your order is on its way.'},
    {
      'type': 'BUTTONS',
      'buttons': [
        {'type': 'QUICK_REPLY', 'text': 'Thanks'},
      ],
    },
  ],
});

final Map<String, Widget Function()> _cases = {
  'WhatsAppScreen (home)': () => const WhatsAppScreen(),
  'WhatsAppShell (Home + Inbox tabs)': () => const WhatsAppShell(),
  'WhatsAppInboxScreen': () => const WhatsAppInboxScreen(),
  'WhatsAppInboxScreen (embedded)': () =>
      const WhatsAppInboxScreen(embedded: true),
  'WhatsAppChatScreen': () => WhatsAppChatScreen(conversation: _conversation),
  'WhatsAppContactsScreen': () => const WhatsAppContactsScreen(),
  'WhatsAppContactsScreen (embedded)': () =>
      const WhatsAppContactsScreen(embedded: true),
  'WhatsAppBlacklistScreen': () => const WhatsAppBlacklistScreen(),
  'WhatsAppTemplatesScreen': () => const WhatsAppTemplatesScreen(),
  'WhatsAppTemplateCreateScreen': () => const WhatsAppTemplateCreateScreen(),
  'WhatsAppCampaignsScreen': () => const WhatsAppCampaignsScreen(),
  'WhatsAppCampaignsScreen (embedded)': () =>
      const WhatsAppCampaignsScreen(embedded: true),
  'WhatsAppCampaignDetailScreen': () =>
      const WhatsAppCampaignDetailScreen(campaignId: 'camp-1'),
  'WhatsAppCampaignCreateScreen': () => const WhatsAppCampaignCreateScreen(),
  'WhatsAppBulkCreateScreen': () => const WhatsAppBulkCreateScreen(),
  'WhatsAppBulkDetailScreen': () =>
      const WhatsAppBulkDetailScreen(bulkId: 'bulk-1'),
  'WhatsAppBotsScreen': () => const WhatsAppBotsScreen(),
  'WhatsAppChatbotScreen': () =>
      const WhatsAppChatbotScreen(chatbotId: 'bot-1'),
  'WhatsAppWorkflowScreen': () =>
      const WhatsAppWorkflowScreen(workflowId: 'flow-1'),
  'WhatsAppAnalyticsScreen': () => const WhatsAppAnalyticsScreen(),
  'WhatsAppConnectSheet': () => const WhatsAppConnectSheet(),
  'WhatsAppNumberSheet': () => WhatsAppNumberSheet(number: _number),
  'WhatsAppContactSheet (new)': () => const WhatsAppContactSheet(),
  'WhatsAppContactSheet (edit)': () => WhatsAppContactSheet(contact: _contact),
  'WhatsAppTemplateSheet': () => WhatsAppTemplateSheet(template: _template),
  'WhatsAppTemplatePicker': () => const WhatsAppTemplatePicker(),
};

void main() {
  for (final entry in _cases.entries) {
    testWidgets('${entry.key} builds and cleans up', (tester) async {
      ignoreFontErrors();
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: entry.value())));
      await tester.pump(const Duration(milliseconds: 200));
      // Let the entrance animations and failed network calls finish.
      await tester.pump(const Duration(seconds: 2));
      expectNoRealErrors(tester);

      // Remove the screen: its timers must stop, or the test fails with
      // "A Timer is still pending".
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expectNoRealErrors(tester);
    });
  }
}
