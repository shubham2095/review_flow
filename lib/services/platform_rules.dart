import 'package:flutter/foundation.dart';

/// Differences between Google Play and the Apple App Store that change what the
/// app shows. Everything else is shared code. Android behaves exactly as before.
///
/// These are the first iOS release's choices, kept in one place so they are
/// easy to revisit:
///
/// * Google sign-in is not offered on iOS. Apple (guideline 4.8) asks an app
///   that offers a third-party login like Google to also offer Sign in with
///   Apple. Until that exists, iOS uses email and password only. That also
///   means no iOS Google client is needed yet.
/// * Buying a plan or credits is never started from the iOS app. Apple (3.1.1)
///   restricts buttons and links that send people to buy outside In-App
///   Purchase. On iOS the app shows plan and credit information but does not
///   link out to buy.
bool get isIos => defaultTargetPlatform == TargetPlatform.iOS;

/// Google sign-in (chooser, ID token, delete-account confirm with Google).
bool get googleSignInAvailable => !isIos;

/// "Choose a plan", "Buy credits", "Manage plan on web" and similar.
bool get purchaseLinksAllowed => !isIos;
