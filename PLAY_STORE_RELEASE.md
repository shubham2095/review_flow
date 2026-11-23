# Eydia: Play Store release (2.1.0 versionCode 5, update 2.2.0 versionCode 6)

---------------------------------------------------------------------------

## 0. Update 2.2.0 (6): Mobile OTP login

`pubspec.yaml`: `version: 2.2.0+6`. Neeche ke baaki sections 2.1.0 ke hain; update ke liye wahi steps, bas version naya.

**Naya kya hai:** Mobile OTP se sign in aur sign up (WhatsApp par 6 ank ka code), profile mein naam/business/email bharna, password set karna, aur account delete WhatsApp code se.

**Release notes (2.2.0):**
```
New: sign in or sign up with your mobile number. We send a 6-digit code on WhatsApp.
New: finish your profile (name, business name, email) and set a password any time.
You can now delete your account with a WhatsApp code.
Fixes and smoother sign-in on small phones.
```

**Data safety:** koi badlav nahi. Phone number, name, email pehle se declare hain. Privacy policy mein ye line ho: "Your mobile number is used to sign you in; we send a one-time code to it on WhatsApp."

**Build:**
```
flutter build apk --release
```
```
flutter build appbundle --release
```
AAB: `build\app\outputs\bundle\release\app-release.aab`. APK: `build\app\outputs\flutter-apk\app-release.apk`.

**Upload se pehle (server):**
1. Backend deploy ho chuka ho (commit `41c222d` ya usse naya): OTP request/verify, delete with `{code}`, `company_name` profile mein.
2. Server `.env`: `OTP_WHATSAPP_TEMPLATE`, `OTP_WHATSAPP_LANG=en_US`, `OTP_WHATSAPP_TYPE=authentication`, `OTP_WHATSAPP_PHONE_NUMBER_ID` set ho. Meta par template `heltog_login_code` Approved ho.
3. Ek asli number par code aata ho (web login se bhi check ho sakta hai).
4. App access (Play Console): reviewer ko email + password wala account hi do. Reviewer ko WhatsApp code nahi mil sakta.

**Phone par regression (release se pehle):**
- Email + password login, logout, dobara login.
- Google login (Android).
- Mobile OTP login: sahi code, galat code, resend 30 sec, change number, number jo registered nahi.
- Naya account mobile se: workspace banta hai, hub khulta hai, plan na ho to plan page.
- Profile: banner, naam, business name, email, "Set a password". Phir email + usi password se login.
- Account delete: password se, Google se, WhatsApp code se (sirf test account par).
- Notifications: login ke baad push aata hai, delete fail ho to push chalu rehta hai.
- Chhota phone, bada font, offline mode, app restart ke baad login bana rahe.
- Purane 2.1.0 se update karne par user logged in rahe.

**Live hone ke baad:**
1. Git tag `v2.2.0-live`.
2. `APP_MIN_SUPPORTED_VERSION` / `APP_LATEST_VERSION` tabhi badhao jab 2.2.0 100% rollout ho jaye.
3. Pehle 1 se 2 din staged rollout (20%), OTP login ke crash aur support tickets dekho.
4. Agar WhatsApp code nahi pahunch raha (support complaints), server par MSG91 keys set karo (SMS fallback).

Is file mein: (1) Data safety form ke jawab, (2) baaki Play Console forms, (3) live karne ke steps.
Jo baat code se pakki hai wo "Pakka" likhi hai. Jo server ya web policy par nirbhar hai wo "Confirm karo" likhi hai.

---------------------------------------------------------------------------

## 1. Data safety form

App ka code: sirf `INTERNET` aur `POST_NOTIFICATIONS` permission. Koi location, contacts (phone ki), camera/mic ki permission nahi.
SDKs: Firebase (sirf push, `firebase_messaging`), Google sign-in, image/file picker. Koi ads, analytics ya crash-report SDK nahi.

### 1.1 Shuru ke sawaal
| Sawaal | Jawab |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (API `https://eydia.in/api/v1`) |
| Do you provide a way for users to request that their data is deleted? | **Yes** |
| Account creation methods | Email + password, Google sign-in (OTP bhi, agar web/server par chalu hai) |
| Data deletion URL | `https://eydia.in/delete-account` |
| In-app deletion | My Profile, "Delete my account" |

### 1.2 Data types (har ek par: Collected = Yes, Shared = No)
Sab ka purpose: **App functionality**. Jahan likha hai wahan **Account management** bhi.
"Required/Optional": Optional wahan jahan user na de to bhi app chalti hai.

| Category | Data type | Kyun | Required? |
|---|---|---|---|
| Personal info | **Name** | Account, team members, contacts | Required |
| Personal info | **Email address** | Login (Account management), team members | Required |
| Personal info | **User IDs** | Account id | Required |
| Personal info | **Address** | Profile aur invoice customers ka address | Optional |
| Personal info | **Phone number** | Profile, aur WhatsApp customers/contacts ke numbers | Optional (customers ke liye zaroori) |
| Financial info | **Other financial info** | Invoices, expenses, GSTIN, bank details jo user invoicing mein bhare | Optional |
| Messages | **Other in-app messages** | WhatsApp chats, templates, Google reviews ke jawab | Optional |
| Photos and videos | **Photos** and **Videos** | GBP posts/photos, AI Studio ka photo, WhatsApp media | Optional |
| Files and docs | **Files and docs** | Chat/bulk send mein bheje documents | Optional |
| App info and performance | (kuch nahi) | Koi crash/diagnostics SDK nahi | n/a |
| Device or other IDs | **Device or other IDs** | Push ke liye Firebase/FCM token | Required (push ke liye) |

**Declare mat karo (app mein nahi hai):** Location, Contacts (phone ki), Calendar, Health & fitness, Audio files/Voice (app record nahi karti), Web browsing, Search history, Credit score, Payment info (kharidari website par hoti hai, app mein nahi).

### 1.3 Sharing (third party ko dena)
Recommended jawab: **"No data shared"**, kyunki Google ke niyam ke hisaab se ye cheezein "sharing" nahi gini jaati:
- **Service provider** jo aapke behalf par process karta hai (Firebase push, AI providers jaise Gemini/Anthropic/OpenAI).
- **User ki khud ki kriya**: user "send" dabata hai to message Meta ke WhatsApp Cloud API se jaata hai; user "publish" dabata hai to post Google Business Profile par jaati hai.

Confirm karo: agar backend developer ya aapke vakeel koi third party (jaise analytics, marketing tool) ko data dete hain to "Shared" mein daalo. Shak ho to conservative raho: **Phone number, Messages, Photos** ko "Shared, App functionality" declare karna reject ka karan nahi banta; galat "No" ban sakta hai.

### 1.4 Security practices
- Data in transit encrypted: **Yes**
- Users can request deletion: **Yes**
- Committed to Play Families Policy: **No**
- Independent security review: **No**

### 1.5 Privacy policy mein ye zaroor ho (web page `https://eydia.in/privacy-policy`)
Form aur policy ek jaise honi chahiye. Policy mein likha ho:
- Kaun sa data lete ho (upar ki table).
- Kin ko process ke liye bhejte ho: **Google (Business Profile, Sign-in, Firebase push), Meta (WhatsApp Cloud API), AI providers**.
- Data kitne din rakhte ho aur delete kaise hota hai (`/delete-account`).
- Contact email.

Ek chhoti baat: app ke fonts `google_fonts` se runtime mein download hote hain (Google ke server se). Isse user ka IP Google ko dikhta hai. Ye alag declare nahi hota, par policy mein "font hosting by Google" jaisa line ho to behtar. Chaho to baad mein fonts app mein hi bundle kar sakte hain.

### 1.6 Confirm karo (mere paas jawab nahi)
- Server par data kitne din rakha jaata hai.
- Koi aur third party SDK web/backend side par jo user data leta ho.
- OTP login chalu hai ya nahi (form mein "account creation" wale hisse ke liye).

---------------------------------------------------------------------------

## 2. App content ke baaki forms (Play Console, Policy and programs, App content)

| Form | Jawab |
|---|---|
| **Privacy policy** | `https://eydia.in/privacy-policy` |
| **App access** | "All or some functionality is restricted". Reviewer ka email + password do. **Us account ka plan GBP aur WhatsApp dono kholne wala ho** (`dash_gbp` + `dash_whatsapp`), warna reviewer WhatsApp nahi dekh paayega. Note likho: "Sign in with email and password. Google sign-in is not needed." |
| **Ads** | No, app mein ads nahi hain |
| **Content rating** | Questionnaire bharo: category "Utility / Productivity / Communication", hinsa/jua/adult kuch nahi. "Users interact" par sach likho: app se customers ko WhatsApp message jaate hain |
| **Target audience** | **18 and over** (business tool) |
| **News app** | No |
| **Government app** | No |
| **Financial features** | "My app doesn't provide any financial features" (invoicing sirf record rakhta hai, paisa nahi chalata) |
| **Health** | No |
| **Advertising ID** | Declare: **App does not use advertising ID** (koi ads SDK nahi). Upload ke baad "App bundle explorer" mein permissions dekho: `AD_ID` nahi aani chahiye |
| **Data safety** | Upar ka section 1 |
| **Permissions** | Koi sensitive permission nahi, isliye koi alag form nahi |

Store listing (Main store listing):
- **App name:** Eydia
- **Short description (80 akshar):** `Reviews, WhatsApp chats, campaigns and invoices for your business in one app.`
- **Category:** Business
- **App icon:** 512x512 PNG, **Feature graphic:** 1024x500, **Phone screenshots:** kam se kam 2 (hub, WhatsApp inbox, plan page, invoicing wagairah).
- **Full description (draft):**
```
Eydia helps you run your customer communication from one app.

Google Business Profile
- Read and reply to Google reviews, with AI drafts
- Publish posts and photos, see calls, clicks and directions
- Profile audit, optimizer and an AI assistant, SEO tracking, AI Studio

WhatsApp
- Shared inbox with assign-to-agent
- Contacts, tags and blocked numbers
- Templates, campaigns and bulk send
- Chatbots, automations and analytics

Invoicing and team
- Create invoices, customers, services and expenses
- Add agents and choose what each can use

You need an active Eydia plan. Plans are managed on the Eydia website.
```
- **Release notes (2.1.0):**
```
New: WhatsApp area (inbox, contacts, templates, campaigns, chatbots, analytics, agents).
New: Team, SEO, AI Studio and Invoicing.
Easier menu and profile, and fixes for bulk sending.
```

---------------------------------------------------------------------------

## 3. Live karne ke steps

### Step A: build banao
1. Saare commits ho chuke hon (jo code upload hoga wahi git mein ho). `pubspec.yaml`: `version: 2.1.0+5`.
2. AAB banao:
```
flutter build appbundle --release
```
File: `build\app\outputs\bundle\release\app-release.aab`
(Gradle atke to: `flutter clean`, `flutter pub get`, phir build.)

### Step B: Internal testing mein daalo (pehle yahan, seedha Production nahi)
1. Play Console, app **Eydia**, left menu **Testing, Internal testing**.
2. **Testers** tab: apne email add karo, ek list banao.
3. **Create new release**: AAB upload karo. Release name `2.1.0 (5)`. Release notes (upar wale) paste karo.
4. **Next, Save, Go to overview, Start rollout to internal testing**.
5. Tester ka **opt-in link** kholo aur Play Store se install karo. Ek baar ye dekho: login, hub, plan page, WhatsApp, push notification.

### Step C: App content poora karo
Dashboard ke "Set up your app" ke saare kaam hare hon: Privacy policy, App access, Ads, Content rating, Target audience, Data safety, Financial features, Advertising ID, Main store listing (icon, graphic, screenshots, descriptions).

### Step D: Production par bhejo
1. **Production, Countries/regions**: **countries add karo** (pehle sirf 1 desh tha, isi wajah se naye users ko purana version dikh raha tha).
2. **Production, Create new release**: **Add from library** se wahi Internal wala bundle chuno. Release notes paste karo.
3. **Rollout:** pehle staged rollout (jaise 20%) rakhna safe hai. Sab theek ho to 100%.
4. **Send for review.** Review mein kuch ghante se kuch din lag sakte hain. **Publishing overview** mein dekho.

### Step E: Live hone ke baad
1. Git tag lagao: `v2.1.0-live`.
2. Jab 2.1.0 100% rollout ho jaaye tabhi server par `APP_MIN_SUPPORTED_VERSION` (aur `APP_LATEST_VERSION`) badhao, phir `php artisan config:cache`. Pehle mat badhao, warna jin users ko abhi update nahi mila wo band ho jaayenge.
3. Pre-launch report (Testing, Pre-launch report) mein crash dekho.

---------------------------------------------------------------------------

## 4. Khatre aur ulta rasta

- **Plan kharidne ka button (Android):** Plan page par "Get a plan on the website" button hai. Google Play kabhi payments policy ka warning ya reject de sakta hai, kyunki app bahar kharidne ki taraf bhejti hai. Aisa ho to `lib/services/platform_rules.dart` mein `planPurchaseLinkAllowed` ko `false` karo, `pubspec.yaml` mein version `2.1.1+6` karo, aur naya AAB upload karo.
- **Galat release nikal gaya:** Production mein staged rollout ko **Halt** kar sakte ho. Purana version delete nahi hota; sudhaar ke saath naya, bade versionCode wala build hi jaata hai.
- **Keystore ka backup:** `android/app/eydia-release.keystore` aur `android/key.properties` ki ek surakshit copy rakho (repo mein nahi hai). Play App Signing chalu hai, par upload key kho gayi to naya key reset karwana padta hai.
- **2.0.0 (code 4):** Console mein dekho wo live hua ya review mein hai. Code 5 upload karne se pehle uski sthiti pata honi chahiye.
