#!/usr/bin/env bash
# Reproducible Flutter web build for direct Vercel API deployment.
set -euo pipefail
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
# Gate production web release on the matching backend TypeScript source.
# Build does not deploy Worker or alter production secrets/bindings.
npm --prefix ../../backend install --ignore-scripts --no-audit --no-fund --no-package-lock
npm --prefix ../../backend run typecheck
# Block deployment if the work schedule audit values and CHECK constraint drift.
node ../../backend/scripts/check_work_audit_contract.mjs
sdk="/tmp/sales-flutter-sdk"
git clone --depth 1 --branch 3.47.9 https://github.com/flutter/flutter.git "$sdk"
export PATH="$sdk/bin:$PATH"
flutter config --no-analytics
flutter create --platforms=web,android .
flutter pub get
python3 scripts/generate_app_icons.py
python3 scripts/check_app_icons.py
flutter analyze --no-fatal-infos
flutter test
export FBMN_BUILD_SHA="${VERCEL_GIT_COMMIT_SHA:-${GITHUB_SHA:-unknown}}"
flutter build web --release --pwa-strategy=none --no-web-resources-cdn --dart-define=API_BASE_URL=https://field-sales-api.milktea-cus.workers.dev --dart-define=FBMN_BUILD_SHA="$FBMN_BUILD_SHA"

python3 scripts/build_offline_shell.py
