import 'package:flutter/material.dart';

import 'session.dart';

/// The products a plan can unlock. The backend decides per plan with the
/// features `dash_gbp` and `dash_whatsapp` (and `dash_leads`, not in the app
/// yet: add it here when the Leads screens exist).
enum Product {
  gbp(
    key: 'dash_gbp',
    title: 'Google Business Profile',
    short: 'Google Business',
    subtitle: 'Reviews, posts, photos and insights',
    icon: Icons.storefront_rounded,
    benefits: [
      (
        Icons.reviews_rounded,
        'Read and reply to Google reviews, with AI drafts',
      ),
      (Icons.edit_note_rounded, 'Publish posts and photos to your profile'),
      (Icons.insights_rounded, 'See calls, clicks and directions from Google'),
      (Icons.auto_awesome_rounded, 'Profile audit, optimizer and AI assistant'),
    ],
  ),
  whatsapp(
    key: 'dash_whatsapp',
    title: 'WhatsApp',
    short: 'WhatsApp',
    subtitle: 'Chats, contacts, campaigns and chatbots',
    icon: Icons.chat_rounded,
    benefits: [
      (Icons.forum_rounded, 'Read and reply to customer chats'),
      (Icons.contacts_rounded, 'Keep contacts, tags and blocked numbers'),
      (Icons.campaign_rounded, 'Send templates, campaigns and bulk messages'),
      (Icons.smart_toy_rounded, 'Chatbots, automations and analytics'),
    ],
  );

  const Product({
    required this.key,
    required this.title,
    required this.short,
    required this.subtitle,
    required this.icon,
    required this.benefits,
  });

  final String key;
  final String title;
  final String short;
  final String subtitle;
  final IconData icon;
  final List<(IconData, String)> benefits;

  /// Whether this person's plan opens the product. The same rule as the web
  /// app (`hasFeature`) and the server (`feature:dash_...`), so the three never
  /// disagree:
  /// - a super admin is not gated;
  /// - no active plan: locked;
  /// - a plan with no feature list at all: everything is open;
  /// - otherwise the plan's feature list must contain this product's key.
  ///   A plan that lists some features but not `dash_whatsapp` does NOT open
  ///   WhatsApp, even if it lists no dashboard at all.
  bool unlockedFor(AppUser? user) {
    if (user == null) return false;
    if (user.isSuperAdmin) return true;
    if (!user.hasPlan) return false;
    final features = user.planFeatures;
    if (features == null) return true;
    return features.contains(key);
  }
}
