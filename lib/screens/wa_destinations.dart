import 'package:flutter/material.dart';

/// Every place inside the WhatsApp product. The side drawer lists them, the
/// WhatsApp shell opens them, and the top bar names the one that is showing.
enum WaDestination {
  home(
    title: 'WhatsApp',
    label: 'Home',
    subtitle: 'Numbers, health and quick actions',
    icon: Icons.home_rounded,
  ),
  inbox(
    title: 'Inbox',
    label: 'Inbox',
    subtitle: 'Customer chats and replies',
    icon: Icons.forum_rounded,
  ),
  contacts(
    title: 'Contacts',
    label: 'Contacts',
    subtitle: 'People, tags and notes',
    icon: Icons.contacts_rounded,
  ),
  campaigns(
    title: 'Campaigns',
    label: 'Campaigns',
    subtitle: 'Campaigns and bulk messages',
    icon: Icons.campaign_rounded,
  ),
  templates(
    title: 'Templates',
    label: 'Templates',
    subtitle: 'Message templates and approval',
    icon: Icons.description_rounded,
  ),
  bots(
    title: 'Chatbots and automations',
    label: 'Chatbots & automations',
    subtitle: 'Auto replies and follow-ups',
    icon: Icons.smart_toy_rounded,
  ),
  analytics(
    title: 'Analytics',
    label: 'Analytics',
    subtitle: 'Message funnel and campaign results',
    icon: Icons.insights_rounded,
  ),
  numbers(
    title: 'Numbers',
    label: 'Numbers',
    subtitle: 'Connect and manage your numbers',
    icon: Icons.phone_android_rounded,
  ),
  blocked(
    title: 'Blocked numbers',
    label: 'Blocked numbers',
    subtitle: 'Numbers that never get your messages',
    icon: Icons.block_rounded,
  ),
  // The bottom bar's "More" tab. It is not listed in the drawer, which lists
  // the pages behind it directly.
  more(
    title: 'More',
    label: 'More',
    subtitle: 'Templates, chatbots, analytics and setup',
    icon: Icons.more_horiz_rounded,
  );

  const WaDestination({
    required this.title,
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  /// The name shown in the top bar while it is open.
  final String title;

  /// The name in the side drawer.
  final String label;
  final String subtitle;
  final IconData icon;

  /// True for the four main tabs that live in the shell's bottom bar. The
  /// others open as their own full-screen page (Numbers shows the Home tab,
  /// where numbers are managed).
  bool get isTab =>
      this == home || this == inbox || this == contacts || this == campaigns;
}

/// The drawer's groups, in order.
const waDrawerGroups = <(String, List<WaDestination>)>[
  (
    'WHATSAPP',
    [
      WaDestination.home,
      WaDestination.inbox,
      WaDestination.contacts,
      WaDestination.campaigns,
    ],
  ),
  ('MESSAGING', [WaDestination.templates, WaDestination.bots]),
  ('RESULTS', [WaDestination.analytics]),
  ('SETUP', [WaDestination.numbers, WaDestination.blocked]),
];
