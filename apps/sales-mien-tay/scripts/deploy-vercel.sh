#!/usr/bin/env bash
# Vercel CLI deployment - must only run after PR CI and UAT approval.
set -euo pipefail
: "${VERCEL_TOKEN:?Set VERCEL_TOKEN securely in CI secret/environment}"
: "${VERCEL_ORG_ID:?Set VERCEL_ORG_ID}"
: "${VERCEL_PROJECT_ID:?Set VERCEL_PROJECT_ID}"
: "${API_BASE_URL:?Set API_BASE_URL for the production API}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/apps/sales_flutter"
cd "$APP"
flutter pub get
flutter analyze --no-fatal-infos
flutter build web --release --dart-define="API_BASE_URL=$API_BASE_URL"
cp vercel.json build/web/vercel.json
cd build/web
mkdir -p .vercel
printf '{"orgId":"%s","projectId":"%s"}\n' "$VERCEL_ORG_ID" "$VERCEL_PROJECT_ID" > .vercel/project.json
npx --yes vercel@latest deploy --prod --yes --token "$VERCEL_TOKEN"
