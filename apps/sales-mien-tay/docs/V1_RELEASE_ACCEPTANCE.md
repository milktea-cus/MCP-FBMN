# Field Work — v1.0 release acceptance

**Candidate:** `1.0.0-rc.1+1` · **Date:** 2026-11-11 · **Scope:** current `main` of MCP-FBMN.

## Feature acceptance and evidence

| Area | Automated coverage | Hands-on sign-off |
|---|---|---|
| Inbox and red bell badge | Flutter unread count, mobile header remains single right action | Two signed-in users must check correct badge and read state |
| Notification business event | Authenticated server, target assignment emits deduplicated event | Manager assigns Target to Sales, recipient receives inbox event |
| Background lock-screen Web Push | VAPID auth, server-scoped subscription, service-worker push/click tests | Install PWA, permit notifications by user gesture, lock screen, send test, verify OS display |
| Push privacy | Generic no-PII notification content; server limits endpoint origins | Confirm phone lock screen does not show customer details |
| iPhone/iPad | Home Screen PWA iOS/iPadOS 16.4+ | Physical iPhone test required; regular Safari browser tab is not sufficient |
| Android native APK | CI Android debug build; existing SQLite offline persistence | **FCM not connected:** native killed-app/lock-screen push unavailable |
| Offline drafts and queue | IndexedDB Chrome, SQLite adapter, account+scope namespace, dependency and conflict tests | Disable network, save data, close/reopen, resume online, verify exactly one server record |
| Security | Auth 401/403; push subscription owned by session; active recipient gating | Two identities/regions test on physical devices |
| DB & API | Migration 020 adds two tables and indexes without modifying existing customers | Production status and authorized CRUD smoke |
| UI responsive | Widget tests at 320/360/390/780/1280/1440 and theme | Physical phone visual QA pending |
| Backup/rollback | Prior deployment IDs kept in Vercel/Cloudflare | Operational restore drill pending |

## Production rollout order

1. CI green including Worker typecheck, Flutter web/Android, Chrome IndexedDB and service-worker checks.
2. Neon migration `020_notifications_push.sql` on isolated branch, validate and apply without modifying customer records.
3. Cloudflare VAPID keypair configured via secrets; private key **must never** be committed or printed. Deploy latest CI bundle, recheck existing `DATABASE_URL`, `ALLOWED_ORIGINS` and R2 bindings.
4. Worker health+fail-closed smoke. Deploy Vercel production from exact green `main` SHA. Verify production alias points to that SHA.
5. Verify two real accounts, target assignment, unread badge and read-offline-then-sync. Test lock-screen push on an installed PWA device.

## Operational behavior

- The notification bell is visible without granting push permission. The inbox can be read in the app; granting OS push is optional.
- On mobile, open the notification page and tap **Bật Push khóa màn hình**. iOS 16.4+ must first add the PWA to the Home Screen.
- When offline, only previously downloaded notification entries can be viewed. Read receipts are durable queued operations until server acknowledgement. Items blocked by a conflict remain in the queue and can be retried explicitly.
- The push service sends no sensitive customer details: lock screen shows only generic Field Work text. In-app details require authenticated access.
- Data belongs to the logged-in identity and scope revision. Changing account or role must not reveal another account's offline inbox.
- Web Push depends on the browser, OS notification permissions and push provider delivery; CI alone cannot prove device lock-screen delivery.
- Android native's true background push requires a separate FCM provider configuration and device tests. Debug APK does not constitute a signed release.

## Release decision

Until physical PWA lock-screen delivery, authenticated two-user UAT, Android distribution strategy and backup/rollback drill are evidenced, this build remains a **v1.0 release candidate**, not a fully accepted v1.0. No test record may be represented as a production business record without authorization.
