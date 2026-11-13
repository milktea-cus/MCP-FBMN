-- P0-L2-D: one canonical brand list, sourced from company SKU brands.
-- Additive only: existing SKU/customer/survey brand text and historical records remain.
CREATE TABLE IF NOT EXISTS public.catalog_brands (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 name text NOT NULL CHECK(length(btrim(name)) BETWEEN 1 AND 120),
 normalized_name text GENERATED ALWAYS AS (lower(btrim(name))) STORED,
 active boolean NOT NULL DEFAULT true,
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 last_mutation_ref uuid,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT catalog_brands_name_unique UNIQUE(normalized_name)
);
INSERT INTO public.catalog_brands(name)
SELECT DISTINCT ON (lower(btrim(brand))) btrim(brand)
FROM public.catalog_products
WHERE brand IS NOT NULL AND btrim(brand)<>''
ORDER BY lower(btrim(brand)),btrim(brand)
ON CONFLICT(normalized_name) DO NOTHING;

-- Sync new/edited company SKU brand values into the same catalog.
CREATE OR REPLACE FUNCTION public.sales_catalog_product_brand_sync()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $fbmn$
BEGIN
 IF NEW.brand IS NOT NULL AND btrim(NEW.brand)<>'' THEN
  INSERT INTO public.catalog_brands(name) VALUES(btrim(NEW.brand))
  ON CONFLICT(normalized_name) DO NOTHING;
 END IF;
 RETURN NEW;
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_catalog_product_brand_sync() FROM PUBLIC;
DO $fbmn$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.catalog_products'::regclass
   AND tgname='catalog_product_brand_sync' AND NOT tgisinternal) THEN
  CREATE TRIGGER catalog_product_brand_sync
  AFTER INSERT OR UPDATE OF brand ON public.catalog_products
  FOR EACH ROW EXECUTE FUNCTION public.sales_catalog_product_brand_sync();
 END IF;
END $fbmn$;

CREATE TABLE IF NOT EXISTS public.catalog_brand_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 brand_id uuid NOT NULL REFERENCES public.catalog_brands(id) ON DELETE RESTRICT,
 actor_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 action text NOT NULL CHECK(action IN ('create','set_active')),
 before_state jsonb,
 after_state jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.sales_save_catalog_brand(
 p_actor text,p_id uuid,p_mutation uuid,p_expected integer,p_name text,p_active boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $fbmn$
DECLARE old public.catalog_brands%ROWTYPE;
 saved public.catalog_brands%ROWTYPE;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.staff_members s
    WHERE s.user_sub=p_actor AND s.role='admin' AND s.active
    AND public.sales_identity_exists(s.user_sub))
 THEN RAISE EXCEPTION 'brand_forbidden'; END IF;
 IF p_id IS NULL OR p_mutation IS NULL OR p_expected IS NULL OR p_expected<0
    OR p_name IS NULL OR length(btrim(p_name)) NOT BETWEEN 1 AND 120
    OR p_active IS NULL
 THEN RAISE EXCEPTION 'brand_invalid'; END IF;
 SELECT * INTO old FROM public.catalog_brands WHERE id=p_id FOR UPDATE;
 IF FOUND THEN
  IF old.last_mutation_ref=p_mutation THEN RETURN to_jsonb(old); END IF;
  IF old.version<>p_expected OR old.normalized_name<>lower(btrim(p_name))
  THEN RAISE EXCEPTION 'brand_stale'; END IF;
  UPDATE public.catalog_brands SET active=p_active,version=version+1,
    last_mutation_ref=p_mutation,updated_at=now()
  WHERE id=p_id RETURNING * INTO saved;
  INSERT INTO public.catalog_brand_audit(brand_id,actor_sub,action,before_state,after_state)
    VALUES(p_id,p_actor,'set_active',to_jsonb(old),to_jsonb(saved));
 ELSE
  IF p_expected<>0 OR NOT p_active THEN RAISE EXCEPTION 'brand_stale'; END IF;
  INSERT INTO public.catalog_brands(id,name,active,last_mutation_ref)
    VALUES(p_id,btrim(p_name),true,p_mutation) RETURNING * INTO saved;
  INSERT INTO public.catalog_brand_audit(brand_id,actor_sub,action,after_state)
    VALUES(p_id,p_actor,'create',to_jsonb(saved));
 END IF;
 RETURN to_jsonb(saved);
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_save_catalog_brand(text,uuid,uuid,integer,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_catalog_brand(text,uuid,uuid,integer,text,boolean) TO sales_api;
GRANT SELECT ON public.catalog_brands TO sales_api;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.catalog_brands FROM sales_api;
REVOKE ALL ON public.catalog_brand_audit FROM sales_api;
