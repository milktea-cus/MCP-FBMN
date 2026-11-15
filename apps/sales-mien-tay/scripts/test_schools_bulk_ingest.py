"""Offline regression checks for the 13-province one-shot school compiler."""
import csv
import json
import tempfile
import unittest
from pathlib import Path

from schools_bulk_ingest import DISTRICTS, compile_sql, read_rows


class SchoolBulkImportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.geo = json.loads(DISTRICTS.read_text(encoding="utf-8"))
        assert len(cls.geo) == 13
        assert sum(len(v) for v in cls.geo.values()) == 134

    def write_csv(self, rows, path):
        names = ("name", "education_level", "province_old", "district_old",
                 "address_text", "source_url", "school_code")
        with path.open("w", encoding="utf-8", newline="") as output:
            writer = csv.DictWriter(output, fieldnames=names)
            writer.writeheader()
            writer.writerows(rows)

    def row(self, province, district, suffix="A", level="2-3"):
        return {
            "name": f"Trường kiểm thử {district} {suffix}",
            "education_level": level,
            "province_old": province,
            "district_old": district,
            "address_text": f"Huyện {district}, tỉnh {province}, Việt Nam",
            "source_url": "https://example.org/test-school",
            "school_code": f"CODE-{province}-{district}-{suffix}",
        }

    def test_full_134_district_manifest_compiles_atomically(self):
        rows = [self.row(p, d) for p, districts in self.geo.items() for d in districts]
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "schools.csv"
            self.write_csv(rows, path)
            accepted, report = read_rows(path, self.geo, allow_partial=False)
        self.assertEqual(report["schools_in_manifest"], 134)
        self.assertEqual(report["old_provinces_with_data"], 13)
        self.assertEqual(report["old_districts_with_data"], 134)
        self.assertEqual(report["missing_districts"], [])
        sql = compile_sql(accepted, "2026-11-16-official-audit")
        self.assertIn("BEGIN;", sql)
        self.assertIn("ON CONFLICT (source_ref) DO NOTHING;", sql)
        self.assertIn("'THCS & THPT'", sql)
        self.assertEqual(sql.count("https://www.google.com/maps/search/"), 134)
        self.assertEqual(sql.count("'BULK26-"), 134)
        self.assertNotIn("DELETE FROM", sql)
        self.assertNotIn("gps_verified=TRUE", sql)

    def test_partial_manifest_is_rejected_by_default(self):
        province, districts = next(iter(self.geo.items()))
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "schools.csv"
            self.write_csv([self.row(province, districts[0])], path)
            with self.assertRaisesRegex(ValueError, "Chưa đủ 134 huyện"):
                read_rows(path, self.geo, allow_partial=False)
            rows, coverage = read_rows(path, self.geo, allow_partial=True)
            self.assertEqual(len(rows), 1)
            self.assertEqual(len(coverage["missing_districts"]), 133)

    def test_duplicate_same_district_rejected(self):
        province, districts = next(iter(self.geo.items()))
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "schools.csv"
            self.write_csv([self.row(province, districts[0], "A"),
                            self.row(province, districts[0], "A")], path)
            with self.assertRaisesRegex(ValueError, "trùng trường"):
                read_rows(path, self.geo, allow_partial=True)

    def test_invalid_school_levels_and_source_urls_rejected(self):
        province, districts = next(iter(self.geo.items()))
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "schools.csv"
            bad = self.row(province, districts[0], level="Mầm non")
            bad["source_url"] = "http://unverified.example.org"
            self.write_csv([bad], path)
            with self.assertRaisesRegex(ValueError, "cấp học không hợp lệ"):
                read_rows(path, self.geo, allow_partial=True)
            bad["education_level"] = "1"
            self.write_csv([bad], path)
            with self.assertRaisesRegex(ValueError, "source_url phải là HTTPS"):
                read_rows(path, self.geo, allow_partial=True)


if __name__ == "__main__":
    unittest.main()
