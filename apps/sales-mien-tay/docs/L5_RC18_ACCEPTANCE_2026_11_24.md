# Lô 5 — RC18 release candidate acceptance (24/11/2026)

Baseline production Web: b8f40f95e0259a9b0de352d217bd2233e9fb1d14; CI 45421013959, 13/13. Vercel dpl_G5mQ36Jw5yDtLSHvT7wowerxkBLx. Worker e8f69b85-83be-4623-a4d4-9fc5af7d5412 at 100%, existing 11 bindings unchanged.

## Read-only production checks
- 62 customers, 796 schools, 1449 prospects, 41 customer photos, 1 order. All four active staff identities resolve. DB sales_customer_allowed evaluated on every customer per role: admin 62 view/edit/media; managers each 62 view, 0 and 34 edit/media respectively; sales 14 view, 6 edit/media. No edit without view. This is DB authorization evaluation, not an authenticated app session test.
- One Android device, five Web subscriptions. Runtime OAuth and provider validation recorded OK on RC16, but delivery and event outbox are empty. Zero inbound mail events. No duplicate recipient/event inbox rows. These facts do NOT prove current Android physical receipt, inbound mail, or notification load.
- R2 latest remains signed RC17, code 17, existing package com.example.sales_mien_tay. Preserve same signer, immutable version and private bucket. Do not publish RC18 until physical upgrade acceptance and owner gate.

## RC18 implementation/verification
- Increment Android code 18. Lock order Save before first await. Add same bulk fixture for memory adapter and real Chrome IndexedDB: 20 customer PATCH operations, 60 photos, five durable order drafts; lost reply/replay, restart, account isolation, revoked revision, no implicit order submission. This uses fake network and does not establish production mutation or device SQLite behavior.
- Candidate-only owner command /field-work-candidate on Issue #3 uses existing OIDC signing workflow and 13/13 exact-main gate, generates signed artifact only. No manifest promotion for this command. Existing release command is unchanged in authority. The workflow must still validate package, version code, signer and artifact before acceptance.

## Outstanding physical UAT / do not tick as accepted
- [ ] Real Sales/Manager/Admin authentication, cross-region/team/chain grants, revoke mid-session, GPS/camera.
- [ ] Physical Android RC17 -> RC18 same signer, local SQLite/drafts/photos retained; no uninstall. Interrupted download, SHA mismatch, installer denial/resume.
- [ ] Android FCM receipt (foreground/background/lock screen), OS permission, audible alert, quiet hours and retry; PWA installed actual Web Push.
- [ ] Real authenticated field workload 20 customers / 60 photos / 5 explicit orders with exact server counts and no spam; test data must not pollute live business records. Order drafts are deliberately local until explicitly submitted; do not silently submit them.
- [ ] Actual Resend inbound, attachment/reply and recipient isolation. No send to unintended third parties.
- [ ] Only after evidence and exact green CI: immutable signed APK R2 upload, SHA/signer read-back, latest pointer last, first install URL smoke. No claim of v1.0 acceptance until UAT evidence.
