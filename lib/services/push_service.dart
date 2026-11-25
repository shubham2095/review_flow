// firebase_messaging 17 deprecates getToken in favour of an installation-id
// flow. getToken still returns the classic FCM token the backend sends to, so
// it stays until the backend is built for the new flow.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'api_service.dart';
import 'platform_rules.dart';

/// Where a tapped notification should take the person.
class PushTarget {
  const PushTarget({required this.type, this.conversationId, this.id});

  /// whatsapp_message, gbp_review, gbp_review_low or lead_handoff.
  final String type;
  final String? conversationId;
  final String? id;

  bool get isChat => type == 'whatsapp_message' && conversationId != null;
  bool get isReview => type == 'gbp_review' || type == 'gbp_review_low';
  bool get isLeadHandoff => type == 'lead_handoff';
}

/// Push notifications through Firebase Cloud Messaging.
///
/// Everything here is best effort and silent when Firebase is not set up (no
/// google-services.json or GoogleService-Info.plist in the build): the app then
/// simply has no push, nothing crashes. See PUSH_SETUP.md.
class PushService {
  PushService._();

  static const _kAsked = 'push_asked';
  static const _kEnabled = 'push_enabled';
  static const _kToken = 'push_token';

  /// Lets a message that arrives while the app is open show a banner from
  /// anywhere. Set on the MaterialApp.
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// A notification the person tapped, waiting for the home screen to open it.
  static final ValueNotifier<PushTarget?> target = ValueNotifier(null);

  static bool _ready = false;
  static bool _failed = false;
  static bool _listening = false;
  static String? _token;

  /// Starts Firebase if this build has it. False when push is not set up.
  static Future<bool> supported() => _init();

  /// True once Firebase started. False when it is not configured in this build.
  static bool get available => _ready;

  static String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  static Future<bool> _init() async {
    // Push is not offered on iOS yet (platform_rules.dart), so Firebase is
    // never started there. Every other method then stops at this check.
    if (!pushNotificationsAvailable) return false;
    if (_ready) return true;
    if (_failed) return false;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _ready = true;
    } catch (_) {
      // No Firebase config in this build: push stays off, quietly.
      _failed = true;
    }
    return _ready;
  }

  static PushTarget? _targetOf(RemoteMessage m) {
    final type = m.data['type']?.toString() ?? '';
    if (type.isEmpty) return null;
    return PushTarget(
      type: type,
      conversationId: m.data['conversation_id']?.toString(),
      id: m.data['id']?.toString(),
    );
  }

  static void _listen() {
    if (_listening) return;
    _listening = true;
    final fm = FirebaseMessaging.instance;

    fm.onTokenRefresh.listen((t) {
      _token = t;
      _register(t);
    });

    // A message while the app is open: a small banner with an Open action.
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      final title = n?.title ?? '';
      final body = n?.body ?? '';
      if (title.isEmpty && body.isEmpty) return;
      final t = _targetOf(m);
      messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                if (body.isNotEmpty)
                  Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
            action: t == null
                ? null
                : SnackBarAction(
                    label: 'Open',
                    textColor: Colors.white,
                    onPressed: () => target.value = t,
                  ),
          ),
        );
    });

    // Tapped while the app was in the background.
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      final t = _targetOf(m);
      if (t != null) target.value = t;
    });
  }

  /// Registers this phone with the server under the signed-in account.
  static Future<void> _register(String token) async {
    try {
      await ApiService.instance.post(
        '/devices',
        body: {'token': token, 'provider': 'fcm', 'platform': _platform},
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, token);
    } catch (_) {
      // The next launch or token refresh tries again.
    }
  }

  static Future<bool> _alreadyGranted() async {
    final s = await FirebaseMessaging.instance.getNotificationSettings();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Gets the token and registers it. Returns false when it could not.
  static Future<bool> _activate() async {
    try {
      _listen();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return false;
      _token = token;
      if (kDebugMode) debugPrint('FCM token: $token');
      await _register(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, true);
      // The notification that launched the app from a closed state.
      final first = await FirebaseMessaging.instance.getInitialMessage();
      final t = first == null ? null : _targetOf(first);
      if (t != null) target.value = t;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Called once the person is inside the app. Registers quietly when they
  /// already allowed notifications, and asks once (with a plain explanation)
  /// the first time. Never asks again after "Not now"; Profile has a switch.
  static Future<void> start(BuildContext context) async {
    if (!await _init()) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kEnabled) == false) return;

    if (await _alreadyGranted()) {
      await _activate();
      return;
    }
    if (prefs.getBool(_kAsked) == true) return;
    if (!context.mounted) return;

    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stay on top of your business'),
        content: const Text(
          'Get a notification when a customer messages you on WhatsApp or '
          'leaves a new Google review. You can turn this off any time in '
          'My Profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    await prefs.setBool(_kAsked, true);
    if (allow != true) return;
    await enable();
  }

  /// Asks the system for permission and registers. Returns a short message
  /// when it did not work (for example permission refused), else null.
  static Future<String?> enable() async {
    if (!await _init()) {
      return 'Notifications are not available in this version of the app.';
    }
    try {
      final s = await FirebaseMessaging.instance.requestPermission();
      final ok =
          s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
      if (!ok) {
        return 'Notifications are blocked. Allow them for Eydia in your phone settings.';
      }
    } catch (_) {
      return 'Could not ask for notification permission.';
    }
    final done = await _activate();
    return done ? null : 'Could not turn notifications on. Try again later.';
  }

  /// Stops notifications on this phone for good until [enable] is called.
  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, false);
    await unregister();
  }

  /// Whether this phone is set to receive notifications.
  static Future<bool> isEnabled() async {
    if (!await _init()) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kEnabled) != true) return false;
    return _alreadyGranted();
  }

  /// Tells the server to stop sending to this phone and drops the token. Runs
  /// while the person is still signed in (logout) or when they switch it off.
  static Future<void> unregister() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _token ?? prefs.getString(_kToken);
      if (token != null && token.isNotEmpty) {
        await ApiService.instance
            .delete('/devices', body: {'token': token})
            .timeout(const Duration(seconds: 5));
      }
      await prefs.remove(_kToken);
      _token = null;
      if (_ready) {
        await FirebaseMessaging.instance.deleteToken().timeout(
          const Duration(seconds: 5),
        );
      }
    } catch (_) {
      // Best effort: the server also drops tokens the next sign-in reassigns.
    }
  }
}
