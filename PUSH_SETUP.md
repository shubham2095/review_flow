# Push notifications: setup

The app side is built (`lib/services/push_service.dart`). It stays **off and
silent** until Firebase is configured, so nothing here blocks a normal build.

## What the app does

- After sign-in it asks once, with a plain explanation, whether to allow
  notifications. "Not now" is respected; **My Profile → Notifications** switches
  them on or off later (the switch only appears when Firebase is configured).
- It registers the phone with `POST /devices` (`provider: fcm`,
  `platform: android|ios`) and removes it on log out, on switching off, and
  before account deletion (`DELETE /devices`).
- A notification that arrives while the app is open shows a banner with an
  **Open** action. Tapping a notification (app closed or in the background)
  opens the page it is about:

  | `data.type` | Opens |
  |---|---|
  | `whatsapp_message` (`conversation_id`) | that chat (inbox if it cannot be found) |
  | `lead_handoff` | WhatsApp inbox |
  | `gbp_review`, `gbp_review_low` | Reviews |

## One-time setup (you)

1. **Firebase project.** Create one at https://console.firebase.google.com and
   add an Android app `com.heltog.review_flow` and an iOS app
   `com.heltog.eydia`.
2. **Generate the options file** (needs the Firebase CLI and FlutterFire CLI):

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<your-firebase-project-id> --platforms=android,ios
   ```

   This **replaces** `lib/firebase_options.dart` (currently a placeholder that
   makes push stay off). The file holds client keys that are meant to ship in
   the app, so it is fine to commit.
3. **FCM v1 service account** (for the backend only, never in the app or this
   repo): Firebase console → Project settings → Service accounts → Generate new
   private key. Give it to the backend developer through a private channel.
4. **iOS only (on the Mac):**
   - Apple Developer → Keys → create an **APNs** key, then upload it in Firebase
     console → Project settings → Cloud Messaging → Apple app configuration.
   - Xcode → Runner target → Signing & Capabilities → add **Push Notifications**
     and **Background Modes → Remote notifications**.
   - Make sure the provisioning profile includes Push Notifications.
5. Build and test on a **real phone** (push does not work on most emulators or
   the iOS simulator).

## Notes

- The notification itself must carry `notification.title` and `notification.body`
  (not data-only) so the system shows it when the app is closed.
- `firebase_messaging` 17 marks `getToken` as deprecated in favour of an
  installation-id flow. The app still uses `getToken`, which returns the classic
  FCM registration token the backend sends to. Revisit when the backend moves.
- Play Data safety and the App Store privacy label must list **device or other
  IDs** (the push token) before release (Phase 11).
