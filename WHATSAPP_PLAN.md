# WhatsApp dashboard in the app: findings and phases

Source: `Eydia.ai-main.zip` (backend and web) and `Eydia_WhatsApp_Mobile_API.pdf`,
both read on 2026-11-14. Everything below was checked against the backend code,
not only the PDF. Work happens on the git branch `whatsapp`.

## What the backend already has (`/api/v1`, JWT)

| Area | Reads | Writes |
|---|---|---|
| Home and numbers | config, overview, numbers, accounts | connect-manual, embedded-signup, refresh, sync, register (PIN), subscribe-app, token, send-test, disconnect |
| Inbox | conversations (status, search, page), messages (cursor), media | mark-read, send text or template, send media, delete message |
| Contacts | list (search, tag, hot), detail, blacklist, tags | create, import, update, delete |
| Templates | list, detail | create, upload sample, sync from Meta, delete |
| Campaigns | list, detail | create, start, pause, cancel, delete |
| Bulk send | list, detail (paid) | send, upload header, retry (paid) |
| Chatbots | list, detail, lead-flow status | create, update, rules, toggle, install lead flow |
| Automations | list, detail, executions | create, canvas, activate, pause, delete |
| Analytics | dashboard, messages, campaigns (all paid) | none |
| Devices | list | register token, unregister |

## What differs between the PDF and the code (the code is the truth)

1. **Send media:** the PDF says the field is `type`. The code requires
   **`media_type`** (`image`, `video`, `audio`, `document`) plus `file`
   (max 16 MB) and optional `caption`.
2. **Conversation list `meta`:** the code returns `current_page`, `last_page`,
   `total`. There is no `per_page`. Messages also return `has_more`.
3. **Web to app hand-off:** the PDF says `/auth/mobile-login/{code}` redirects to
   `eydia://...`. The code redirects to the **web app**
   (`/auth/callback?token=...&next=...`). There is no deep link back to the app.
4. **`/auth/web-session` `next`:** only `/billing`, `/plans`, `/buy-credits` are
   allowed (`NEXT_WHITELIST`). Anything else becomes `/billing`. So the app
   **cannot** open the web WhatsApp page today.
5. **Push notifications:** the PDF says they already fire. The code sends
   through **Expo** (React Native only) or the **legacy FCM endpoint**
   (`fcm.googleapis.com/fcm/send` with a server key), which Google has shut
   down. A Flutter app gets nothing until the backend moves to FCM v1.
   Device registration also defaults to `provider: expo`; the app must send `fcm`.
6. **Numbers sync:** the PDF marks `/numbers/{n}/sync` as paid. In the code it
   only needs the `whatsapp.manage` permission, not a plan.
7. The PDF lists in-app Razorpay purchase endpoints (`/billing/order`,
   `/credits/packs/*/order`). **The app must not use them**: Google Play and the
   App Store do not allow selling plans or credits this way. Buying stays on the web.

## Things the app must handle

- **Freemium.** WhatsApp, contacts, templates, campaigns, chatbots, automations
  and also GBP **reads** work without a plan. Paid actions return
  `403 plan_required` or `feature_not_included`. Today the app shows a Plan
  gate and blocks everything for an account without a plan. That has to change
  (Phase 1).
- **Permissions are separate from plans.** Team members can lack
  `conversations.reply`, `whatsapp.manage`, `contacts.create` and so on. That
  is a plain 403 with no `plan_required` code. Show "you do not have
  permission", never "buy a plan". Agents only see chats assigned to them.
- **24-hour window.** Plain text can be sent only while `window_open` is true.
  After that the server answers 422 and only a template can be sent.
- **Inbox templates have no variables.** `send` accepts a template name and
  language only, so templates with `{{1}}` placeholders cannot be sent from a
  chat. Bulk send does take `variables`.
- **Ordering.** Conversations come hot leads first, then newest.
- **Media.** `GET /whatsapp/media/{uuid}` needs no login, so it works as an image URL.
- **Realtime.** The web inbox is live (Reverb). The app will poll while the
  inbox is open until push works.
- **No buying anywhere.** The app shows plan and credit details only, on Android and iOS, for GBP and WhatsApp alike. Accounts without a plan stay on the plan page.
  Bulk messaging and contact data also need the Apple privacy label and the
  Play Data safety form updated before release.

## Phases (each one is built, committed and tested before the next)

**Phase 0: backend and decisions (before code)**
- Backend: add `/whatsapp` to `NEXT_WHITELIST` so the app can open the web
  connect page. (Optional: a `?mobile=1` return deep link.)
- Backend: correct the PDF (`media_type`, `meta`, hand-off redirect).
- Backend, for later: FCM v1 push (service account) and `provider: fcm`.
- Decide: Android first, which plans include WhatsApp (the Plan gate stays).

**Phase 1: WhatsApp entry (plan gate stays)**
- Accounts without a plan stay on the plan page; no purchase UI anywhere.
- Handle `plan_required`, `feature_not_included` and permission 403s the same
  way everywhere (a clear message, never "buy").
- Add a WhatsApp area to the app navigation. Models and service skeleton.
- Test: a locked or forbidden action explains itself; navigation opens WhatsApp.

**Phase 2: WhatsApp home and numbers**
- Overview (counts), numbers with quality and status, connect (web hand-off or
  manual form), refresh, enable sending, register PIN, update token, send test, disconnect.

**Phase 3: Inbox (read)**
- Conversation list (search, status, unread, hot badge, window state), message
  thread with cursor paging, media display, mark read, polling.

**Phase 4: Inbox (reply)**
- Text reply inside the window, template reply outside it, send image or
  document, delete message, clear Meta error messages.

**Phase 5: Contacts**
- List, search, tags, Hot list, blacklist (free to view). Create, edit, delete,
  import from the phone contacts (paid).

**Phase 6: Templates**
- List, detail, status, sync (free to view). Create with a header sample (paid).

**Phase 7: Campaigns and bulk send**
- List and detail with real delivery counts. Create, start, pause, cancel.
  Bulk send from numbers, retry failed.

**Phase 8: Chatbots and automations**
- Chatbots: list, rules, on/off, lead-flow install. Automations: list, detail,
  run history, pause and activate. Canvas editing stays on the web.

**Phase 9: Analytics (paid)**
- Message funnel chart and campaign stats.

**Phase 10: Push notifications**
- Needs the backend FCM v1 work, a Firebase project, `firebase_messaging`, and
  for iOS an APNs key. Deep link `{type: whatsapp_message, conversation_id}` to the chat.

**Phase 11: release**
- Update Play Data safety and the App Store privacy label, bump the version
  (2.1.0), Android first, then iOS.
