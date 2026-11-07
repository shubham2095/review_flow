# Eydia

Flutter app (Android and iOS) for managing a Google Business Profile: reviews with AI
replies, posts and photos, insights, business profile editor, automation,
billing view, support, and a super-admin panel. It talks to the Eydia Laravel
backend at `https://eydia.in/api/v1`.

- Package: `com.heltog.review_flow` (never change it, it is the Play Store identity)
- Platforms: Android and iOS (do not run a bare `flutter create .`, it adds web, desktop and test folders)

## Run

```bash
flutter pub get
flutter run
```

Point the app at another server for testing:

```bash
flutter run --dart-define=API_BASE=https://staging.example.com/api/v1
```

## Check

```bash
flutter analyze
```

## Release to Google Play

1. Raise `version` in `pubspec.yaml`. The part after `+` is the Play version
   code and must only ever go up. The part before it (for example `2.0.0`) is
   what the forced-update check compares.
2. Build the signed bundle:
   ```bash
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`
3. Upload it to Internal testing first, check Google sign-in from the Play
   install, then promote to Production.

Signing uses `android/key.properties` and the upload keystore in
`android/app/`. Both are gitignored: never commit them or share their
passwords.

## iOS (App Store)

The project also has an `ios/` folder. Building needs a Mac with Xcode. The
steps, listing text and the differences from Android (no Google sign-in, no
buy buttons on iOS) are in [IOS_RELEASE.md](IOS_RELEASE.md).

## Forced update and maintenance

The app asks the server for `GET /app/config` on start and whenever it comes
back to the foreground. The server controls it with these settings
(backend `.env`):

- `APP_MIN_SUPPORTED_VERSION`: versions below this see "Update required"
- `APP_LATEST_VERSION`, `APP_UPDATE_URL`
- `APP_MAINTENANCE`, `APP_MAINTENANCE_MESSAGE`

Raise `APP_MIN_SUPPORTED_VERSION` only after the new version has reached 100%
of users on Google Play.

## Google sign-in

The app sends a Google ID token to the server. The server must have
`GOOGLE_MOBILE_CLIENT_ID` set to the same Web client ID the app uses as
`serverClientId` (`lib/main.dart`). Without it sign-in returns `503 not_configured`.

## Code layout

- `lib/screens/`: one file per page or sheet
- `lib/widgets/`: shared pieces (state views, skeletons, avatars, notices)
- `lib/services/`: API client, auth, session, offline cache, local drafts
- `lib/models/`: data classes parsed from the API
- `lib/theme/brand.dart`: colours and the shared card style

Payments never happen inside the app: plan and credit purchases open the web
app, already signed in.
