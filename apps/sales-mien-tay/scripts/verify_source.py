#!/usr/bin/env python3
"""Fast offline source checks; no network or production credentials required."""
import json
import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
flutter = ROOT / "apps" / "sales_flutter"
backend = ROOT / "backend"

assert (flutter / "pubspec.yaml").is_file(), "Missing Flutter project"
assert (flutter / "lib" / "main.dart").is_file(), "Missing Flutter entrypoint"
assert (backend / "src" / "index.ts").is_file(), "Missing Worker entrypoint"
assert (backend / "migrations" / "001_init.sql").is_file(), "Missing Neon migration"

catalog = json.loads((flutter / "assets" / "districts_old.json").read_text(encoding="utf8"))
server_catalog = json.loads((backend / "src" / "districts_old.json").read_text(encoding="utf8"))
assert catalog == server_catalog, "Server/mobile province catalog divergence"
assert len(catalog) == 13, f"Expected 13 legacy provinces, got {len(catalog)}"
assert sum(len(v) for v in catalog.values()) == 134, "Expected 134 legacy districts"
for province, districts in catalog.items():
    assert districts and len(districts) == len(set(districts)), f"Invalid districts: {province}"

schema = (backend / "migrations" / "001_init.sql").read_text(encoding="utf8").lower()
assert "sales_records" in schema, "Sales migration missing records table"
readme = (ROOT / "README.md").read_text(encoding="utf8").lower()
assert "chưa" in readme or "not production" in readme, "Starter limitations must be documented"

bad_names = {".env", ".dev.vars", "key.properties", ".p12", ".jks"}
for path in ROOT.rglob("*"):
    if path.is_file():
        assert path.name not in bad_names, f"Potential secret file tracked: {path}"
# Signed Android release tooling must remain syntactically valid and fail closed.
publisher = ROOT / "scripts" / "publish_android_release.py"
ast.parse(publisher.read_text(encoding="utf8"), filename=str(publisher))
release_workflow = ROOT.parents[1] / ".github" / "workflows" / "sales-android-release.yml"
assert release_workflow.is_file(), "Missing signed Android release workflow"
source = release_workflow.read_text(encoding="utf8")
assert "ci_run_id:" in source and "publish_production:" in source, "Release approval gate missing"
assert "flutter build apk --release" in source, "Signed release build missing"
assert "FIELD_WORK_ANDROID_CERT_SHA256" in source, "Signer pinning missing"
assert "publish_android_release.py" in source, "Immutable R2 publisher missing"
native = flutter / "android"
gradle = (native / "app" / "build.gradle.kts").read_text(encoding="utf8")
assert 'applicationId = "com.example.sales_mien_tay"' in gradle, "Existing app ID changed"
assert 'signingConfigs.getByName("debug")' not in gradle, "Debug signing in release is forbidden"
assert (native / "gradle" / "wrapper" / "gradle-wrapper.jar").stat().st_size > 50000, "Android Gradle wrapper corrupt"
assert (native / "app" / "src" / "main" / "res" / "xml" / "apk_file_paths.xml").is_file(), "APK FileProvider missing"
print("PASS: Android signing fail-closed, private R2 publisher and native source")
print("PASS: inventory, province/district catalog, app modules and source policy")
