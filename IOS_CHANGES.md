# iOS changes made after the first iOS build (Eydia 2.0.0+4)

Rule followed for every change: it only affects iOS. Each one in `lib/` is behind
`isIos` / `purchaseLinksAllowed` from `lib/services/platform_rules.dart`.
On Android the same code runs and shows exactly what it showed before.
Nothing under `android/`, `pubspec.yaml` (version stays 2.0.0+4) or the API URLs
was changed.

## Changed files

### 1. `lib/screens/billing_screen.dart` (risk 3: wording that invites buying)
- Before: with no plan, every platform showed "Choose a plan to unlock your workspace."
- Now: `purchaseLinksAllowed ? 'Choose a plan to unlock your workspace.' : 'This account does not have an active plan yet.'`
- Android: same text as before. iOS: no wording that points to buying.

### 2. `lib/services/app_config_service.dart` and `lib/screens/app_gate.dart` (risk 4: Play Store link on iPhone)
- Added `AppConfigService.updateUrlFor(serverUrl)`.
  - Android (`!isIos`): returns the server link, or the Play Store default when
    empty. Same result as the old code.
  - iOS: a Google Play link is never used. Only an `apps.apple.com` or
    `itms-apps://` link from the server is accepted. Otherwise `iosUpdateUrl` is used.
- Added `AppConfigService.iosUpdateUrl`, currently empty (`''`).
  **To do after the app is approved:** put the App Store link there, for example
  `https://apps.apple.com/app/id1234567890`. The ID is in App Store Connect,
  App Information, Apple ID.
- `_openStore` in `app_gate.dart`: with no link on iOS it shows "Please update Eydia
  from the App Store." and does not open anything. Android text and behaviour are unchanged.
- Still true: the server's `min_supported_version` is one number for both
  platforms. Raise it for Android only when the iOS build with that version is
  also live, or ask the backend developer for per-platform values.

### 3. `lib/screens/login_screen.dart` and `lib/screens/plan_gate_screen.dart` (risk 2: new account dead end)
- Create account tab, iOS only: a short note under the form, "Eydia is a service
  for businesses. A new account opens the workspace once a plan is active on it."
- Plan gate, iOS only: the text now says Eydia is a service for businesses, the
  account has no active plan yet, and a user whose business already uses Eydia
  should sign out and sign in with that account. No buy link, no web link.
- Android: both screens unchanged.

## Not changed, and why

- **Risk 1 (plans sold on the website):** cannot be fixed in code. Use the review
  notes below. If Apple rejects, read the message and reply in App Store Connect.
- **Risk 5 (launch screen):** I checked, and my earlier note was wrong. The launch
  image is already a blank 1x1 image, not the Flutter logo. The launch screen is
  plain white, then the app's own splash. Nothing to fix.
- **Risk 6 (seller name):** an Apple account matter. An individual account shows
  your personal name. A company name needs an Apple Developer organization account.

## Review notes to paste in App Store Connect (App Review Information)

Add your demo credentials yourself. Do not put them in the repo.

```
Eydia is a service for businesses. Accounts and plans are managed by the
business outside the app, so the app has no purchase options, links to buy, or
payment screens. Sign in with the demo account above (email and password fields);
it already has an active plan.
A new account created inside the app has no active plan, so it shows a
"workspace is not active" screen. That is expected for this business service.
Connecting a Google Business Profile needs a verified business listing, so some
screens may show empty states; every section can be opened from the menu.
Account deletion is in the app: My Profile, Delete my account.
Privacy policy: My Profile, Privacy policy.
```

## Git (you run these)

Commit only these files:

```bash
git add lib/screens/billing_screen.dart lib/screens/app_gate.dart lib/screens/login_screen.dart lib/screens/plan_gate_screen.dart lib/services/app_config_service.dart IOS_CHANGES.md
git add ios/Runner.xcodeproj/project.pbxproj ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved
git commit -m "iOS: neutral billing text, iOS-aware update link, clearer no-plan messaging"
git push
```

Leave `pubspec.lock` and `analysis_options.yaml` out of the commit.
