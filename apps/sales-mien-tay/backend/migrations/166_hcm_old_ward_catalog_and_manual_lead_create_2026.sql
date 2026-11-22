-- 166 | 2026-11-22 | Address governance for HCMC-old contemporary wards.
-- Gate the 3 researched wards and keep historical Quận 1 ACL unchanged.
-- Additive seed, no customer/legacy prospect changes. Additional old-HCMC wards
-- must be explicitly researched and added here before ingest via the field UI.
CREATE TABLE IF NOT EXISTS public.sales_hcm_old_wards (
 province text NOT NULL DEFAULT 'TP Hồ Chí Minh',
 ward_new text NOT NULL,
 legacy_district text NOT NULL,
 legal_source text NOT NULL DEFAULT '1685/NQ-UBTVQH15',
 active boolean NOT NULL DEFAULT true,
 PRIMARY KEY (province,ward_new),
 CHECK (province='TP Hồ Chí Minh')
);
INSERT INTO public.sales_hcm_old_wards(province,ward_new,legacy_district,legal_source)
VALUES ('TP Hồ Chí Minh','Sài Gòn','Quận 1','1685/NQ-UBTVQH15'),
       ('TP Hồ Chí Minh','Tân Định','Quận 1','1685/NQ-UBTVQH15'),
       ('TP Hồ Chí Minh','Bến Thành','Quận 1','1685/NQ-UBTVQH15')
ON CONFLICT (province,ward_new) DO NOTHING;

-- This table is a legacy province/district compatibility catalog.
-- Do NOT add "ward" into the district level. This doesn't grant staff scopes.
INSERT INTO public.territory_catalog(code,name,level,parent_code)
VALUES ('hcm-old-province','TP Hồ Chí Minh','province',NULL)
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.territory_catalog(code,name,level,parent_code)
VALUES ('hcm-old-q1','Quận 1','district','hcm-old-province')
ON CONFLICT (code) DO NOTHING;

-- Database-level check against accidental out-of-scope ward spelling for
-- researched HCMC old-ward leads (legacy NULL ward rows are unaffected).
DO $$
BEGIN
 IF NOT EXISTS (
   SELECT 1 FROM pg_constraint WHERE conname='field_prospects_hcm_old_ward_fk'
    AND conrelid='public.field_prospects'::regclass
 ) THEN
  ALTER TABLE public.field_prospects
   ADD CONSTRAINT field_prospects_hcm_old_ward_fk
   FOREIGN KEY (province,ward_new)
   REFERENCES public.sales_hcm_old_wards(province,ward_new);
 END IF;
END $$;

-- Adapter is atomic: the pre-existing create function validates actor ACL,
-- source data, school match and idempotent UUID; then persists current ward
-- inside the same SQL statement. No new-ward data may be invented by client.
CREATE OR REPLACE FUNCTION public.sales_market_prospect_create_with_ward(
 p_actor text,p_ref uuid,p_name text,p_address text,p_province text,p_district text,
 p_ward text,p_category text,p_phone text,p_tax text,p_note text,p_school uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
DECLARE saved jsonb;
BEGIN
 IF p_province<>'TP Hồ Chí Minh' OR p_ward IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.sales_hcm_old_wards w
  WHERE w.province=p_province AND w.legacy_district=p_district
   AND w.ward_new=p_ward AND w.active
 ) THEN
  RAISE EXCEPTION 'market_invalid_ward';
 END IF;
 saved:=public.sales_market_prospect_create(p_actor,p_ref,p_name,p_address,
   p_province,p_district,p_category,p_phone,p_tax,p_note,p_school);
 UPDATE public.field_prospects AS p
 SET ward_new=p_ward
 WHERE p.id=p_ref AND (p.ward_new IS NULL OR p.ward_new=p_ward);
 IF NOT FOUND THEN RAISE EXCEPTION 'market_conflict'; END IF;
 SELECT to_jsonb(p) INTO saved FROM public.field_prospects p WHERE p.id=p_ref;
 RETURN saved;
END $fn$;

COMMENT ON TABLE public.sales_hcm_old_wards IS
 'Whitelist of 102 pre-2025 HCMC wards progressively verified by historic territory and contemporary resolution.';
