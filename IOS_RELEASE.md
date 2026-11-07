# Eydia on the Apple App Store

How to build and publish the iOS app. The Dart code in `lib/` is shared with
Android; only the `ios/` folder and a few platform checks are iOS-specific.

## What is different on iOS (first release)

Controlled in one file, `lib/services/platform_rules.dart`:

- **No Google sign-in.** Email and password only. Apple (guideline 4.8) asks for
  Sign in with Apple when a third-party login like Google is offered. To bring
  Google back, first add Sign in with Apple (app and backend) and an iOS Google
  client, then flip `googleSignInAvailable`.
- **No buying from the app.** No "choose a plan", "buy credits", plan list or
  credit packs. Apple (guideline 3.1.1) restricts links that send people to buy
  outside In-App Purchase. Plan and credit information is shown read-only.
- iPhone only, portrait only. No iPad screenshots are needed.

Android behaves exactly as before.

## Identity

- Bundle ID: `com.heltog.eydia` (Apple does not allow `_`, so it cannot match the
  Android id `com.heltog.review_flow`). Set it in `ios/Runner.xcodeproj` before
  you create the app in App Store Connect. It cannot change afterwards.
- Name on the home screen: `Eydia`.
- Version comes from `pubspec.yaml` (`2.0.0+4`): `2.0.0` is the version, `4` the
  build number. Every upload of the same version needs a build number App Store
  Connect has not seen yet.

## One-time Mac setup

1. Install **Xcode** from the Mac App Store, open it once and accept the license.
2. Install the Flutter SDK (flutter.dev) and CocoaPods (`brew install cocoapods`).
3. `flutter doctor` must show Xcode and CocoaPods as fine.
4. Clone the repo, branch `master`.
5. Sign in to Xcode with the Apple Developer account
   (Xcode, Settings, Accounts).

Do not copy `android/key.properties` or the Android keystore to the Mac. Android
releases are built where those files already are.

## Build

```bash
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

In Xcode: Runner target, Signing & Capabilities, tick "Automatically manage
signing", choose the Team. Run on a real iPhone first and check: sign in with
email, Overview, Reviews, a photo pick (permission text), Forgot password.

If `pod install` complains about the iOS version, the minimum is `13.0` for all
current plugins (`IPHONEOS_DEPLOYMENT_TARGET` in the Xcode project).

Then either:

```bash
flutter build ipa --release
```

and upload `build/ios/ipa/*.ipa` with the Transporter app, or in Xcode
choose Product, Archive, Distribute App, App Store Connect.

## App Store Connect

1. My Apps, New App: platform iOS, name `Eydia`, primary language English,
   bundle ID `com.heltog.eydia`, SKU `eydia-ios`.
2. After the build finishes processing (a few minutes), add it to the version.
3. Test first with **TestFlight** (internal testers) before submitting.

### Listing text (suggestion)

- **Subtitle (30 chars):** `Google reviews, posts and AI`
- **Promotional text:** `Reply to Google reviews faster, publish posts and photos, and see how customers find you.`
- **Description:**
  ```
  Eydia helps local businesses manage their Google Business Profile from one app.

  - Read new Google reviews and reply faster with AI-written drafts
  - Publish posts, offers and photos to your profile
  - See calls, website clicks and direction requests at a glance
  - Get a health score and a short list of what to fix first
  - Keep your business hours, contact details and description up to date
  - Set up automatic review replies and scheduled posts
  - Works with your last saved data when you are offline

  Eydia is a service for businesses. You need an Eydia account with an active plan.
  ```
- **Keywords (100 chars max):** `google business,reviews,reply,local seo,posts,insights,gmb,reputation,photos`
- **Support URL:** `https://eydia.in`
- **Privacy Policy URL:** `https://eydia.in/privacy-policy`
- **Category:** Business. **Age rating:** answer the questionnaire honestly, no
  restricted content.

### Screenshots

iPhone only. App Store Connect asks for the largest sizes (6.9-inch and 6.5-inch
iPhone) and scales them for smaller ones. Take them from the simulator or a
real phone: Overview, Reviews, Reply sheet, Posts, Insights, AI Tools.

### App Privacy ("nutrition label")

Answer from what the app and server really handle. The app sends and the
server stores: name, email, phone (profile), the business details the user
types, photos the user uploads, review replies and posts the user writes, and
Google Business Profile data the user connects. None is used for tracking and
none is sold. Check your server's own logging and analytics before you answer.

### App Review information

- **Sign-in required:** yes. Give the demo account (email and password) that has
  an active plan, the same one used for Google Play.
- **Notes (suggestion):**
  ```
  Eydia is a service for businesses. Plans are managed by the business on our
  website, so the app has no purchase options. Sign in with the demo account
  above (use the email and password fields). It already has an active plan.
  Connecting a Google Business Profile needs a verified business listing, so
  some screens may show empty states; every section can be opened from the menu.
  Account deletion is in the app: My Profile, Delete my account.
  ```

## Checks Apple makes that are already covered

- Account deletion inside the app (My Profile, Delete my account).
- Privacy policy link inside the app (My Profile) and in the listing.
- Camera and photo permission texts (`Info.plist`).
- No Google sign-in, so no Sign in with Apple requirement for this release.

## Known risks

- Apple may still ask about plans being sold on the website (guidelines 3.1.1 and
  3.1.3). If the reviewer rejects on this, read the message and tell the team;
  the screens that matter are Plan gate and Billing.
- If an account was created with Google on Android and never had a password, it
  cannot sign in on iOS until a password is set with "Forgot password".
- Upload warnings about a privacy manifest (`PrivacyInfo.xcprivacy`) can appear;
  plugins ship their own, so these are usually informational. Read each one.
