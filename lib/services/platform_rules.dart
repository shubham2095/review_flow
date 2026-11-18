import 'package:flutter/foundation.dart';

/// Differences between Google Play and the Apple App Store that change what the
/// app shows. Everything else is shared code. Android behaves exactly as before.
///
/// * Google sign-in is not offered on iOS. Apple (guideline 4.8) asks an app
///   that offers a third-party login like Google to also offer Sign in with
///   Apple. Until that exists, iOS uses email and password only.
///
/// The app never sells anything itself. On Android the plan page also has a
/// button that opens the Eydia website, where the plan is bought. Apple does
/// not allow an app to point people to buy elsewhere (guideline 3.1.1), so iOS
/// shows plain wording only.
bool get isIos => defaultTargetPlatform == TargetPlatform.iOS;

/// Whether the plan page may offer a button that opens the website to buy a
/// plan.
bool get planPurchaseLinkAllowed => !isIos;

/// Google sign-in (chooser, ID token, delete-account confirm with Google).
bool get googleSignInAvailable => !isIos;
