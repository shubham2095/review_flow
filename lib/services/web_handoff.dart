import 'package:url_launcher/url_launcher.dart';

import 'auth_service.dart';

/// Opens the Eydia web app in the browser, already signed in: for hand-offs such
/// as connecting WhatsApp, and (Android only, see platform_rules.dart) the plan
/// page's "get a plan on the website" button. The server only accepts
/// whitelisted [next] paths (/billing, /plans, /buy-credits). Throws
/// ApiException on failure.
Future<void> openInWeb({String? next}) async {
  final url = await AuthService.webSessionUrl(next: next);
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Opens a public page (policies, account deletion) in the browser.
Future<void> openPublicPage(String path) => launchUrl(
  Uri.parse('https://eydia.in$path'),
  mode: LaunchMode.externalApplication,
);
