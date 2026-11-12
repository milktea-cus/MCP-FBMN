# P0-I — Field Work Android APK & private R2 release

**As of 2026-11-12:** native Android, update UI, private R2 download API,
signed-release CI, immutable publisher and test guards have been added.
**No APK release may be published until the installed package/certificate is
verified and two consecutive native versions are UAT-tested.**

## Locked identity and business data

- Android package ID remains `com.example.sales_mien_tay`, inherited from the
  app produced by CI/Flutter. Do not silently rename it.
- Candidate version `1.0.0-rc.2+2`; native SQLite via `idb_sqflite` and
  account-scoped outbox must survive an in-place install.
- An Android debug APK and a newly signed release APK may have different
  signing certificates. Android will refuse to install a different signer
  over an existing package. Never advise uninstalling when there are offline
  customer photos, drafts or unsynced records.
- Verify package name, installed signing certificate SHA-256 and versionCode
  against the owner's installed APK (not only CI's generated debug APK).
  If the signer differs, first obtain verified backup/sync evidence and
  explicit migration approval.

## Signing and CI gate

`.github/workflows/sales-android-release.yml` is a **manual gated** release
workflow on `main`, not a normal push build. It checks the exact SHA and a
green `Sales Miền Tây CI` run, exact pubspec versionCode, Android release
signing, a pinned signing certificate fingerprint, APK package/version and
Android `apksigner` validation. It has a separate
`publish_production=no|yes` gate.

Protected GitHub Actions secrets, **never in code/logs**:

- `FIELD_WORK_ANDROID_KEYSTORE_BASE64`
- `FIELD_WORK_ANDROID_STORE_PASSWORD`
- `FIELD_WORK_ANDROID_KEY_ALIAS`
- `FIELD_WORK_ANDROID_KEY_PASSWORD`
- `FIELD_WORK_ANDROID_CERT_SHA256`
- `FIELD_WORK_R2_ACCESS_KEY_ID` and `FIELD_WORK_R2_SECRET_ACCESS_KEY`
  (write rights **only** to the APK release bucket, not customer media).

These names document the contract, not evidence they have been provisioned.
Do not use a generated ephemeral debug keystore as a stand-in.

## Storage and private distribution

Private R2 bucket: `sales-mien-tay-app-releases` (separate from the
`PHOTOS_BUCKET` customer media bucket). Worker binding
`APP_RELEASES_BUCKET`; `APP_DOWNLOAD_HMAC_KEY` must be installed as a
Cloudflare Worker secret, never a plain-text variable.

- APK keys are immutable:
  `releases/<versionCode>/field-work-<versionCode>.apk`.
- `publish_android_release.py` verifies the uploaded object's size,
  SHA-256 and signer metadata, independently reads the uploaded bytes,
  saves the previous manifest under `releases/history/`, then atomically
  updates `releases/latest.json`. Never overwrite prior binary versions.
- Server enforces authenticated `GET /api/v1/app/releases/latest`,
  authenticated `POST /api/v1/app/releases/ticket` and authenticated
  `GET /api/v1/app/releases/download`. Ticket HMAC binds identity, access
  scope revision, immutable release SHA, version and a 5-minute expiry.
  Unknown packages/paths/expired tickets are rejected. No unsigned
  public bucket link or arbitrary object access.
- Missing R2 binding, signing certificate or HMAC secret must fail closed.
  It is **not** acceptable to declare release availability with a placeholder
  key or a hand-written `latest.json`.

## Android update flow

In the **native Android** account drawer (not PWA), select
**Cập nhật ứng dụng**. The app reads installed version and certificate from
Android PackageManager. It checks whether the release has a higher code and
identical package and signer. After authorized ticket issuance it streams the
APK into private cache with progress/retry/range resume and checks size +
SHA-256. Native code independently validates installed-vs-candidate
signer, package, versionCode and SHA-256 **again before install**. Android
PackageInstaller is invoked through FileProvider and an OS confirmation.
If Android needs permission to install from this source, the user must grant
it explicitly. No silent install, automatic uninstall or SQLite reset.

PWA continues to update using the web service worker; APK download controls
are intentionally hidden.

## Required acceptance before marking P0-I complete

- CI: backend typecheck + guards + Flutter analyze/widget + Chrome IndexedDB +
  Android native debug APK build all green on the *same commit*.
- Production Worker version/deployment bound to **both existing media R2**
  and private APK R2 while preserving all existing Worker secrets.
- Signed APK release artifact verified for package/version/signer/hash; R2
  binary downloaded and hash matched; `latest` pointer updated last.
- Production authenticated API check and anonymous/expired/foreign
  object negative tests; no customer data in logs or downloads.
- Physical Android UAT with two consecutive signed releases, offline
  download interruption/cancel/resume, tampered SHA, missing installer
  permission, install denial, repeat install and installed app reopen.
  Confirm SQLite/outbox/drafts/photo data remain intact.
- Budget/retention: customer photos and release objects use separate R2
  prefixes/buckets; never delete photo objects as part of APK retention.
- Document the package and signer of the APK already on the Owner's device.
  If it was signed with debug credentials that cannot be recovered,
  **pause first release and arrange explicit data-safe migration**.

CI green means **implementation verified**, not real-device release acceptance.
