-- Chạy một lần trên Neon; không chứa thông tin cá nhân thật.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS sales_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind text NOT NULL CHECK (kind IN ('survey', 'target', 'forecast', 'visit', 'dealer', 'competitor', 'support')),
  owner_sub text NOT NULL,
  province text,
  district text,
  customer_name text,
  period_ym text CHECK (period_ym IS NULL OR period_ym ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  data jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(data) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS one_target_per_owner_month
  ON sales_records (owner_sub, period_ym) WHERE kind = 'target';
CREATE INDEX IF NOT EXISTS sales_records_owner_kind_updated
  ON sales_records (owner_sub, kind, updated_at DESC);
CREATE INDEX IF NOT EXISTS sales_records_province_period
  ON sales_records (province, period_ym);

-- Nhắc lại quy ước: với dữ liệu khảo sát, 'Có' mới tính hiện diện.
-- Bảng ghi theo từng điểm bán; không lấy tổng hiện diện NPP/nhãn làm tổng điểm bán.