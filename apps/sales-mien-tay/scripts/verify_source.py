#!/usr/bin/env python3
"""Fast offline source checks; no network or production credentials required."""
import json
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
print("PASS: inventory, province/district catalog, app modules and source policy")
