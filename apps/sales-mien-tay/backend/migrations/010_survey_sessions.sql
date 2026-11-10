-- 010: Unified field survey session, immutable province templates and private media.
BEGIN;
CREATE TABLE IF NOT EXISTS public.field_survey_templates (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 province text NOT NULL, version integer NOT NULL CHECK(version>0),
 questions jsonb NOT NULL CHECK(jsonb_typeof(questions)='array'),
 created_by text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(province,version)
);
CREATE TABLE IF NOT EXISTS public.field_survey_sessions (
 id uuid PRIMARY KEY, customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
 owner_sub text NOT NULL, province text NOT NULL, district text NOT NULL,
 route_stop_id uuid REFERENCES public.sales_records(id) ON DELETE RESTRICT,
 template_id uuid NOT NULL REFERENCES public.field_survey_templates(id) ON DELETE RESTRICT,
 started_at timestamptz NOT NULL, ended_at timestamptz,
 latitude double precision NOT NULL CHECK(latitude BETWEEN -90 AND 90),
 longitude double precision NOT NULL CHECK(longitude BETWEEN -180 AND 180),
 accuracy_m double precision NOT NULL CHECK(accuracy_m BETWEEN 0 AND 100),
 distance_m double precision NOT NULL CHECK(distance_m BETWEEN 0 AND 200),
 status text NOT NULL DEFAULT 'in_progress' CHECK(status IN ('in_progress','completed')),
 answers jsonb NOT NULL DEFAULT '{}'::jsonb CHECK(jsonb_typeof(answers)='object'),
 note text NOT NULL DEFAULT '', version integer NOT NULL DEFAULT 1 CHECK(version>0),
 last_mutation_ref uuid,
 CHECK((status='in_progress' AND ended_at IS NULL) OR (status='completed' AND ended_at>=started_at))
);
CREATE INDEX IF NOT EXISTS field_survey_session_owner_time ON public.field_survey_sessions(owner_sub,started_at DESC);
CREATE INDEX IF NOT EXISTS field_survey_session_customer_time ON public.field_survey_sessions(customer_id,started_at DESC);
CREATE INDEX IF NOT EXISTS field_survey_session_stop ON public.field_survey_sessions(route_stop_id);
CREATE TABLE IF NOT EXISTS public.field_survey_photos (
 id uuid PRIMARY KEY, session_id uuid NOT NULL REFERENCES public.field_survey_sessions(id) ON DELETE RESTRICT,
 kind text NOT NULL CHECK(kind IN ('front','shelf','goods','other')),
 mime_type text NOT NULL CHECK(mime_type IN ('image/jpeg','image/png','image/webp')),
 bytes integer NOT NULL CHECK(bytes BETWEEN 1 AND 5242880),
 sha256 text NOT NULL CHECK(sha256 ~ '^[0-9a-f]{64}$'),
 object_key text NOT NULL UNIQUE,
 captured_at timestamptz NOT NULL, created_by text NOT NULL,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','ready')),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS field_survey_photo_session ON public.field_survey_photos(session_id,status);
-- Generic initial form; NPP choices are intentionally not invented. Admin publishes a province-specific next version.
INSERT INTO public.field_survey_templates(province,version,questions,created_by)
SELECT p,1,'[
 {"id":"npp","label":"NPP đang phân phối (tên thực tế)","type":"text","required":true},
 {"id":"futurebook","label":"Futurebook có hiện diện?","type":"boolean","required":true},
 {"id":"brands","label":"Nhãn hàng / đối thủ","type":"text","required":true},
 {"id":"sku","label":"SKU / hàng hóa / sản lượng","type":"text","required":true},
 {"id":"display","label":"Quầy kệ / trưng bày","type":"text","required":true},
 {"id":"potential","label":"Tiềm năng / ghi chú thêm","type":"text","required":false}
]'::jsonb,'system:initial'
FROM unnest(ARRAY['Long An','Tiền Giang','Bến Tre','Trà Vinh','Vĩnh Long','Đồng Tháp','An Giang','Kiên Giang','Hậu Giang','Sóc Trăng','Bạc Liêu','Cà Mau','Cần Thơ']) p
ON CONFLICT(province,version) DO NOTHING;
GRANT SELECT,INSERT ON public.field_survey_templates TO sales_api;
GRANT SELECT,INSERT,UPDATE ON public.field_survey_sessions,public.field_survey_photos TO sales_api;
COMMIT;
