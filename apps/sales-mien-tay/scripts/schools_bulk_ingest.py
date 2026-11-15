#!/usr/bin/env python3
"""Compile a provenance-checked, add-only nationwide school import migration.

This tool does NOT connect to production. It validates a CSV manifest against
Field Work's frozen 13-province / 134-district geography, then emits one SQL
migration for review and CI. Full-coverage gate is ON by default.

Usage:
  python3 scripts/schools_bulk_ingest.py --input official_schools.csv --output backend/migrations/0NN_schools_bulk.sql --batch 2026-11-16-schools-official
  python3 scripts/schools_bulk_ingest.py --input subset.csv --allow-partial --check-only
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
import unicodedata
from collections import Counter
from pathlib import Path
from urllib.parse import quote, urlparse

ROOT = Path(__file__).resolve().parents[1]
DISTRICTS = ROOT / "backend" / "src" / "districts_old.json"
LEVELS = {
    "1": "Tiểu học", "cấp 1": "Tiểu học", "tiểu học": "Tiểu học",
    "2": "THCS", "cấp 2": "THCS", "thcs": "THCS",
    "3": "THPT", "cấp 3": "THPT", "thpt": "THPT",
    "1-2": "Tiểu học & THCS", "1,2": "Tiểu học & THCS",
    "tiểu học & thcs": "Tiểu học & THCS",
    "2-3": "THCS & THPT", "2,3": "THCS & THPT",
    "thcs & thpt": "THCS & THPT",
    "1-2-3": "Tiểu học & THCS & THPT",
    "1,2,3": "Tiểu học & THCS & THPT",
    "tiểu học & thcs & thpt": "Tiểu học & THCS & THPT",
}
REQUIRED = ("name", "education_level", "province_old", "district_old", "address_text", "source_url")


def normalized(value: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFKC", value).casefold()
                   if c.isalnum())


def valid_url(value: str) -> bool:
    try:
        url = urlparse(value)
        return url.scheme == "https" and bool(url.hostname) and not url.username and not url.password
    except ValueError:
        return False


def sql_literal(value: str | None) -> str:
    return "NULL" if value is None else "'" + value.replace("'", "''") + "'"


def read_rows(csv_path: Path, geography: dict[str, list[str]], *,
              allow_partial: bool) -> tuple[list[dict[str, str]], dict[str, object]]:
    errors: list[str] = []
    rows: list[dict[str, str]] = []
    source_refs: set[str] = set()
    school_keys: set[tuple[str, str, str]] = set()
    used_districts: set[tuple[str, str]] = set()
    with csv_path.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)
        if not reader.fieldnames or any(k not in reader.fieldnames for k in REQUIRED):
            raise ValueError("Thiếu cột bắt buộc: " + ", ".join(REQUIRED))
        for line, raw in enumerate(reader, 2):
            if None in raw:
                errors.append(f"Dòng {line}: dư cột/CSV lỗi")
                continue
            x = {k: (v or "").strip() for k, v in raw.items()}
            missing = [k for k in REQUIRED if not x.get(k)]
            if missing:
                errors.append(f"Dòng {line}: thiếu {', '.join(missing)}")
                continue
            province, district = x["province_old"], x["district_old"]
            if district not in geography.get(province, []):
                errors.append(f"Dòng {line}: địa giới cũ không hợp lệ: {province} / {district}")
                continue
            level = LEVELS.get(x["education_level"].casefold())
            if level is None:
                errors.append(f"Dòng {line}: cấp học không hợp lệ: {x['education_level']}")
                continue
            if not valid_url(x["source_url"]):
                errors.append(f"Dòng {line}: source_url phải là HTTPS có thể đối chiếu")
                continue
            supplied_maps = x.get("maps_search_url", "")
            if supplied_maps and not (valid_url(supplied_maps)
                and urlparse(supplied_maps).hostname in ("www.google.com", "google.com")
                and urlparse(supplied_maps).path.startswith("/maps/search")):
                errors.append(f"Dòng {line}: Maps URL phải là Google Maps search")
                continue
            school_key = (province, district, normalized(x["name"]))
            if school_key in school_keys:
                errors.append(f"Dòng {line}: trùng trường trong cùng huyện: {x['name']}")
                continue
            identity = x.get("school_code") or x.get("source_ref") or (
                province + "|" + district + "|" + normalized(x["name"]))
            ref = x.get("source_ref") or "BULK26-" + hashlib.sha256(
                (province + "|" + district + "|" + identity).encode("utf-8")).hexdigest()[:20]
            if ref in source_refs or not re.fullmatch(r"[A-Za-z0-9._:-]{3,80}", ref):
                errors.append(f"Dòng {line}: source_ref trùng hoặc không hợp lệ: {ref}")
                continue
            x["source_ref"] = ref
            x["education_level"] = level
            x["maps_search_url"] = supplied_maps or (
                "https://www.google.com/maps/search/?api=1&query="
                + quote(x["name"] + ", " + x["address_text"], safe=""))
            x["address_detail_level"] = x.get("address_detail_level") or "Chỉ đối chiếu địa chỉ từ nguồn"
            x["verification_note"] = x.get("verification_note") or (
                "Nhập hàng loạt từ nguồn truy xuất trong source_url; chưa xác minh GPS. "
                "Google Maps là đường dẫn tìm kiếm, không phải ghim đã xác minh.")
            # Never assign GPS on school import. Verified coordinates need a distinct
            # signed/field-verified workflow; this batch only uses Maps search URLs.
            source_refs.add(ref)
            school_keys.add(school_key)
            used_districts.add((province, district))
            rows.append(x)
    expected = {(p, d) for p, districts in geography.items() for d in districts}
    missing_districts = sorted(expected - used_districts)
    if errors:
        raise ValueError("Dữ liệu không đạt kiểm tra:\n" + "\n".join(errors[:40])
                         + (f"\n... và {len(errors)-40} lỗi khác" if len(errors)>40 else ""))
    if not rows:
        raise ValueError("Không có trường hợp lệ; dừng nhập")
    if not allow_partial and missing_districts:
        raise ValueError(f"Chưa đủ {len(expected)} huyện cũ; còn thiếu {len(missing_districts)} huyện. "
                         "Bổ sung dữ liệu hoặc dùng --allow-partial khi kiểm thử, "
                         "KHÔNG gọi lô chưa đủ là hoàn thiện.")
    report = {
        "schools_in_manifest": len(rows),
        "old_provinces_with_data": len({r["province_old"] for r in rows}),
        "old_districts_with_data": len(used_districts),
        "old_districts_expected": len(expected),
        "missing_districts": missing_districts,
        "by_level": dict(Counter(x["education_level"] for x in rows)),
        "verified_gps": 0,
        "maps_search_only": len(rows),
    }
    return rows, report


def compile_sql(rows: list[dict[str, str]], batch: str) -> str:
    if not re.fullmatch(r"[a-zA-Z0-9_-]{8,80}", batch):
        raise ValueError("Batch ID chỉ cho phép a-z, A-Z, 0-9, _ và -")
    columns = ("source_ref", "name", "education_level", "province_old",
               "district_old", "ward_old", "address_text", "maps_search_url",
               "source_url", "verification_note", "address_detail_level")
    values = []
    for x in rows:
        values.append("  (" + ", ".join(sql_literal(x.get(k) or None) for k in columns) + ")")
    column_list = ",".join(columns)
    return f"""-- FBMN bulk import: reviewed school institutions for 13 historical provinces.
-- Generated by scripts/schools_bulk_ingest.py. Source URLs required per row.
-- Run ONLY after source review, production backup strategy and green CI.
-- Add-only, name/district de-dup; does not merge/delete old school records.
-- Nonverified Google Maps *search* URLs only; GPS always false.
BEGIN;
WITH incoming({column_list}) AS (
 VALUES
{',\n'.join(values)}
)
INSERT INTO public.schools
({column_list},source_batch,gps_verified)
SELECT {','.join('x.' + c for c in columns)},{sql_literal(batch)},FALSE
FROM incoming x
WHERE NOT EXISTS (
 SELECT 1 FROM public.schools s
 WHERE s.province_old=x.province_old AND s.district_old=x.district_old
 AND lower(regexp_replace(btrim(s.name),'[^[:alnum:]]','','g')) =
     lower(regexp_replace(btrim(x.name),'[^[:alnum:]]','','g'))
)
ON CONFLICT (source_ref) DO NOTHING;
COMMIT;
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="Authoritative school CSV manifest")
    parser.add_argument("--output", type=Path, help="Destination SQL migration (only after review)")
    parser.add_argument("--batch", default="2026-11-16-schools-official")
    parser.add_argument("--allow-partial", action="store_true", help="For interim audits only")
    parser.add_argument("--check-only", action="store_true", help="Validate without writing SQL")
    args = parser.parse_args()
    if not args.check_only and args.output is None:
        parser.error("--output is required unless --check-only")
    geography = json.loads(DISTRICTS.read_text(encoding="utf-8"))
    try:
        rows, report = read_rows(args.input, geography, allow_partial=args.allow_partial)
        # Validate batch even in check-only mode.
        sql = compile_sql(rows, args.batch)
    except (ValueError, OSError, csv.Error) as error:
        print("REJECTED: " + str(error), file=sys.stderr)
        return 2
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if not args.check_only:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(sql, encoding="utf-8")
        print(f"Review migration: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
