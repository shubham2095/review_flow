import 'package:flutter/foundation.dart';

/// Differences between Google Play and the Apple App Store that change what the
/// app shows. Everything else is shared code. Android behaves exactly as before.
///
/// * Google sign-in is not offered on iOS. Apple (guideline 4.8) asks an app
///   that offers a third-party login like Google to also offer Sign in with
///   Apple. Until that exists, iOS uses email and password only.
///
/// Buying is not a platform rule: on every platform the app only shows plan and
/// credit details and never sells or links out to buy anything.
bool get isIos => defaultTargetPlatform == TargetPlatform.iOS;

/// Google sign-in (chooser, ID token, delete-account confirm with Google).
bool get googleSignInAvailable => !isIos;
