-- 002: Customer/field-service foundation. Additive; does not alter or delete existing sales data.
CREATE TABLE IF NOT EXISTS staff_scopes (
  user_sub text NOT NULL,
  province text NOT NULL,
  district text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_sub, province, district)
);
CREATE INDEX IF NOT EXISTS idx_staff_scopes_province ON staff_scopes(province, district);

CREATE TABLE IF NOT EXISTS customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_ref uuid NOT NULL,
  owner_sub text NOT NULL,
  name text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 2 AND 240),
  code text,
  category text NOT NULL DEFAULT 'tap_hoa' CHECK (category IN ('tap_hoa','sieu_thi','dai_ly','npp','khac')),
  contact_name text,
  phone text CHECK (phone IS NULL OR char_length(phone) BETWEEN 8 AND 20),
  address_line text NOT NULL CHECK (char_length(btrim(address_line)) BETWEEN 3 AND 500),
  province text NOT NULL,
  district text NOT NULL,
  latitude double precision,
  longitude double precision,
  location_accuracy_m double precision,
  location_consent boolean NOT NULL DEFAULT false,
  note text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','potential')),
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT valid_customer_coords CHECK (
    ((latitude IS NULL AND longitude IS NULL) OR
      (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180))
    AND (location_accuracy_m IS NULL OR location_accuracy_m BETWEEN 0 AND 10000)
    AND (latitude IS NULL OR location_consent)
  ),
  UNIQUE(owner_sub, client_ref)
);
CREATE INDEX IF NOT EXISTS idx_customers_owner_updated ON customers(owner_sub, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_customers_territory ON customers(province, district, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(lower(name));

CREATE TABLE IF NOT EXISTS customer_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  owner_sub text NOT NULL,
  object_key text NOT NULL UNIQUE,
  mime_type text NOT NULL CHECK (mime_type IN ('image/jpeg','image/png','image/webp')),
  bytes integer NOT NULL CHECK (bytes BETWEEN 1 AND 5242880),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_customer_photos_customer ON customer_photos(customer_id, created_at DESC);

CREATE TABLE IF NOT EXISTS field_visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  owner_sub text NOT NULL,
  client_ref uuid NOT NULL,
  checkin_at timestamptz NOT NULL DEFAULT now(),
  latitude double precision NOT NULL CHECK(latitude BETWEEN -90 AND 90),
  longitude double precision NOT NULL CHECK(longitude BETWEEN -180 AND 180),
  accuracy_m double precision NOT NULL CHECK(accuracy_m BETWEEN 0 AND 100),
  distance_m double precision CHECK(distance_m BETWEEN 0 AND 200),
  note text,
  UNIQUE(owner_sub, client_ref)
);
CREATE INDEX IF NOT EXISTS idx_field_visits_customer ON field_visits(customer_id, checkin_at DESC);

CREATE TABLE IF NOT EXISTS field_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_sub text NOT NULL,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  happened_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_field_audit_entity ON field_audit_events(entity_type, entity_id, happened_at DESC);