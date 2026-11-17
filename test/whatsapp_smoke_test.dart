import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/models/agents_models.dart';
import 'package:review_flow/models/ai_media_models.dart';
import 'package:review_flow/models/invoicing_models.dart';
import 'package:review_flow/models/seo_models.dart';
import 'package:review_flow/screens/invoice_catalog.dart';
import 'package:review_flow/screens/invoice_catalog_sheets.dart';
import 'package:review_flow/screens/invoice_create_screen.dart';
import 'package:review_flow/screens/invoice_expenses.dart';
import 'package:review_flow/screens/invoice_detail_screen.dart';
import 'package:review_flow/screens/invoice_sheets.dart';
import 'package:review_flow/screens/invoicing_screen.dart';
import 'package:review_flow/screens/ai_studio_screen.dart';
import 'package:review_flow/models/team_models.dart';
import 'package:review_flow/screens/seo_screen.dart';
import 'package:review_flow/screens/seo_sheets.dart';
import 'package:review_flow/models/whatsapp_models.dart';
import 'package:review_flow/screens/team_member_sheet.dart';
import 'package:review_flow/screens/team_screen.dart';
import 'package:review_flow/screens/agents_screen.dart';
import 'package:review_flow/screens/assign_agent_sheet.dart';
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
import 'package:review_flow/screens/whatsapp_contact_info_sheet.dart';
import 'package:review_flow/screens/whatsapp_contact_sheet.dart';
import 'package:review_flow/screens/whatsapp_contacts_screen.dart';
import 'package:review_flow/screens/whatsapp_inbox_screen.dart';
import 'package:review_flow/screens/whatsapp_more_screen.dart';
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
  'WhatsAppShell (all tabs)': () => const WhatsAppShell(),
  'WhatsAppMoreScreen': () => WhatsAppMoreScreen(onOpenHome: () {}),
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
  'WhatsAppContactInfoSheet': () =>
      WhatsAppContactInfoSheet(conversation: _conversation),
  'WhatsAppTemplatePicker': () => const WhatsAppTemplatePicker(),
  'AiStudioScreen': () => const AiStudioScreen(),
  'AiMediaViewer (picture)': () => const AiMediaViewer(
    media: AiMedia(
      id: 'm1',
      prompt: 'A festive Diwali offer banner',
      imageData: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      source: 'ai',
    ),
  ),
  'AiMediaViewer (no picture)': () => const AiMediaViewer(
    media: AiMedia(id: 'm2', prompt: 'A banner', source: 'fallback'),
  ),
  'InvoicingScreen': () => const InvoicingScreen(),
  'InvoiceCreateScreen': () => const InvoiceCreateScreen(),
  'InvoiceDetailScreen': () =>
      const InvoiceDetailScreen(invoiceId: 'i1', number: 'INV-0001'),
  'InvoiceLineSheet (new)': () => const InvoiceLineSheet(
    services: [
      InvoiceServiceItem(id: 's1', name: 'Logo design', price: 500, gstPercent: 18),
    ],
  ),
  'InvoiceLineSheet (edit)': () => const InvoiceLineSheet(
    initial: DraftLine(
      description: 'Hosting',
      quantity: 1,
      unitPrice: 1000,
      gstPercent: 5,
    ),
  ),
  'CustomerSheet (new)': () => const CustomerSheet(),
  'CustomerSheet (edit)': () => const CustomerSheet(
    customer: InvoiceCustomer(
      id: 'c1',
      name: 'Asha Rao',
      email: 'asha@example.com',
      gstin: '27ABCDE1234F1Z5',
    ),
  ),
  'InvoiceCatalogTab': () => const InvoiceCatalogTab(),
  'InvoiceExpensesTab': () => const InvoiceExpensesTab(),
  'ExpenseSheet': () => const ExpenseSheet(categories: ['Rent', 'Ads']),
  'ServiceSheet (new)': () => const ServiceSheet(
    categories: [InvoiceCategory(id: 'g1', name: 'Design')],
  ),
  'ServiceSheet (edit)': () => const ServiceSheet(
    categories: [InvoiceCategory(id: 'g1', name: 'Design')],
    service: InvoiceServiceItem(
      id: 's1',
      name: 'Logo design',
      price: 500,
      gstPercent: 18,
      categoryId: 'g1',
      category: 'Design',
    ),
  ),
  'CategorySheet': () => const CategorySheet(),
  'SeoScreen': () => const SeoScreen(),
  'SeoKeywordSheet': () => const SeoKeywordSheet(
    places: [SeoPlace(id: 'l1', name: 'Main shop'), SeoPlace(id: 'l2', name: 'Second shop')],
    initialKeyword: 'bakery in pune',
    initialCity: 'Pune',
  ),
  'SeoCompetitorSheet': () => const SeoCompetitorSheet(),
  'SeoHistorySheet': () => const SeoHistorySheet(
    keyword: SeoKeyword(id: 'k1', keyword: 'bakery in pune'),
  ),
  'SeoRankResultSheet': () => const SeoRankResultSheet(
    keyword: SeoKeyword(id: 'k1', keyword: 'bakery in pune'),
    result: SeoRankResult(
      source: 'ai',
      rank: 'Top 3',
      summary: 'You show well.',
      tips: ['Post weekly', 'Reply to reviews'],
    ),
  ),
  'SeoAnalysisSheet': () => const SeoAnalysisSheet(
    competitor: SeoCompetitor(id: 'c1', name: 'Rival Bakery'),
    analysis: SeoAnalysis(
      source: 'ai',
      summary: 'You lead on reviews.',
      strengths: ['4.6 stars'],
      gaps: ['Fewer posts'],
      actions: ['Post weekly'],
      myName: 'Main shop',
      myAverage: 4.6,
      myReviews: 120,
    ),
  ),
  'TeamScreen': () => const TeamScreen(),
  'TeamMemberSheet (new)': () =>
      const TeamMemberSheet(features: _teamFeatures),
  'TeamMemberSheet (edit)': () => const TeamMemberSheet(
    features: _teamFeatures,
    member: TeamMember(
      id: 'u1',
      name: 'Asha Rao',
      email: 'asha@example.com',
      features: ['inbox'],
    ),
  ),
  'AgentsScreen': () => const AgentsScreen(),
  'AgentDetailScreen': () => const AgentDetailScreen(
    agent: WaAgent(id: 'a1', name: 'Asha Rao', email: 'asha@example.com'),
  ),
  'AssignAgentSheet': () =>
      const AssignAgentSheet(conversationId: 'c1', currentAgent: 'Asha Rao'),
};

const _teamFeatures = [
  TeamFeature(key: 'inbox', label: 'Inbox (chats)'),
  TeamFeature(key: 'contacts', label: 'Contacts'),
];

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

    // A small phone with the text enlarged 1.5x: nothing may overflow.
    testWidgets('${entry.key} fits a small phone at 1.5x text', (tester) async {
      ignoreFontErrors();
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(body: entry.value()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(seconds: 2));
      expectNoRealErrors(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expectNoRealErrors(tester);
    });
  }
}
