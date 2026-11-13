-- P0-3: one canonical brand identity across products, customer evidence, surveys and reporting.
-- Additive: do not rewrite legacy SKU.brand strings or historic survey versions.
ALTER TABLE public.catalog_products
 ADD COLUMN IF NOT EXISTS brand_id uuid REFERENCES public.catalog_brands(id) ON DELETE RESTRICT;
CREATE INDEX IF NOT EXISTS catalog_products_brand_id_idx ON public.catalog_products(brand_id);

CREATE TABLE IF NOT EXISTS public.catalog_brand_aliases (
 alias_name text NOT NULL CHECK(length(btrim(alias_name)) BETWEEN 1 AND 120),
 normalized_alias text GENERATED ALWAYS AS (lower(btrim(alias_name))) STORED PRIMARY KEY,
 brand_id uuid NOT NULL REFERENCES public.catalog_brands(id) ON DELETE RESTRICT,
 created_by text NOT NULL REFERENCES public.staff_members(user_sub),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS catalog_brand_aliases_brand_idx ON public.catalog_brand_aliases(brand_id);

CREATE TABLE IF NOT EXISTS public.catalog_brand_alias_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 mutation_ref uuid NOT NULL UNIQUE,
 brand_id uuid NOT NULL REFERENCES public.catalog_brands(id) ON DELETE RESTRICT,
 alias_name text NOT NULL,
 actor_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.sales_catalog_product_brand_sync()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $fbmn$
DECLARE resolved_id uuid;
BEGIN
 IF NEW.brand IS NOT NULL AND btrim(NEW.brand)<>'' THEN
  SELECT a.brand_id INTO resolved_id
    FROM public.catalog_brand_aliases a
   WHERE a.normalized_alias=lower(btrim(NEW.brand));
  IF resolved_id IS NULL THEN
   INSERT INTO public.catalog_brands(name) VALUES(btrim(NEW.brand))
   ON CONFLICT(normalized_name) DO NOTHING RETURNING id INTO resolved_id;
   IF resolved_id IS NULL THEN
     SELECT id INTO resolved_id FROM public.catalog_brands
     WHERE normalized_name=lower(btrim(NEW.brand));
   END IF;
  END IF;
 END IF;
 UPDATE public.catalog_products p SET brand_id=resolved_id
  WHERE p.id=NEW.id AND p.brand_id IS DISTINCT FROM resolved_id;
 RETURN NEW;
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_catalog_product_brand_sync() FROM PUBLIC;

UPDATE public.catalog_products p SET brand_id=COALESCE(
 (SELECT a.brand_id FROM public.catalog_brand_aliases a
  WHERE a.normalized_alias=lower(btrim(p.brand))),
 (SELECT b.id FROM public.catalog_brands b
  WHERE b.normalized_name=lower(btrim(p.brand))))
WHERE p.brand IS NOT NULL AND btrim(p.brand)<>''
 AND p.brand_id IS DISTINCT FROM COALESCE(
 (SELECT a.brand_id FROM public.catalog_brand_aliases a
  WHERE a.normalized_alias=lower(btrim(p.brand))),
 (SELECT b.id FROM public.catalog_brands b
  WHERE b.normalized_name=lower(btrim(p.brand))));

CREATE TABLE IF NOT EXISTS public.customer_brand_verifications (
 customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
 brand_id uuid NOT NULL REFERENCES public.catalog_brands(id) ON DELETE RESTRICT,
 is_trading boolean NOT NULL DEFAULT false,
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 verification_note text NOT NULL CHECK(length(btrim(verification_note)) BETWEEN 8 AND 500),
 verified_by text NOT NULL REFERENCES public.staff_members(user_sub),
 verified_at timestamptz NOT NULL DEFAULT now(),
 last_mutation_ref uuid NOT NULL,
 PRIMARY KEY(customer_id,brand_id)
);
CREATE INDEX IF NOT EXISTS customer_brand_verifications_brand_idx
 ON public.customer_brand_verifications(brand_id) WHERE is_trading;

CREATE TABLE IF NOT EXISTS public.customer_brand_verification_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 mutation_ref uuid NOT NULL UNIQUE,
 customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
 brand_id uuid NOT NULL REFERENCES public.catalog_brands(id) ON DELETE RESTRICT,
 actor_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 action text NOT NULL CHECK(action IN ('verify','unverify')),
 reason text NOT NULL,
 before_state jsonb,
 after_state jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.sales_customer_brand_apply(
 p_actor text,p_ref uuid,p_customer uuid,p_brand uuid,
 p_expected integer,p_action text,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $fbmn$
DECLARE previous public.customer_brand_verifications%ROWTYPE;
 saved public.customer_brand_verifications%ROWTYPE;
 logged public.customer_brand_verification_audit%ROWTYPE;
 wanted boolean;
BEGIN
 IF NOT public.sales_customer_allowed(p_actor,p_customer,'edit')
  OR NOT EXISTS(SELECT 1 FROM public.staff_members s WHERE s.user_sub=p_actor
    AND s.active AND public.sales_identity_exists(s.user_sub))
 THEN RAISE EXCEPTION 'brand_customer_forbidden'; END IF;
 IF p_ref IS NULL OR p_customer IS NULL OR p_brand IS NULL
    OR p_expected IS NULL OR p_expected<0 OR p_expected>2147483646
    OR p_action NOT IN ('verify','unverify')
    OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 8 AND 500
 THEN RAISE EXCEPTION 'brand_customer_invalid'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.catalog_brands WHERE id=p_brand AND active)
 THEN RAISE EXCEPTION 'brand_customer_inactive'; END IF;
 wanted=(p_action='verify');
 SELECT * INTO logged FROM public.customer_brand_verification_audit WHERE mutation_ref=p_ref;
 IF FOUND THEN
  IF logged.actor_sub=p_actor AND logged.customer_id=p_customer
    AND logged.brand_id=p_brand AND logged.action=p_action AND logged.reason=btrim(p_reason)
  THEN RETURN logged.after_state; END IF;
  RAISE EXCEPTION 'brand_customer_conflict';
 END IF;
 SELECT * INTO previous FROM public.customer_brand_verifications
 WHERE customer_id=p_customer AND brand_id=p_brand FOR UPDATE;
 IF FOUND THEN
  IF previous.version<>p_expected THEN RAISE EXCEPTION 'brand_customer_stale'; END IF;
  UPDATE public.customer_brand_verifications
  SET is_trading=wanted,version=version+1,
    verification_note=btrim(p_reason),verified_by=p_actor,verified_at=now(),
    last_mutation_ref=p_ref
  WHERE customer_id=p_customer AND brand_id=p_brand RETURNING * INTO saved;
 ELSE
  IF p_expected<>0 THEN RAISE EXCEPTION 'brand_customer_stale'; END IF;
  INSERT INTO public.customer_brand_verifications
    (customer_id,brand_id,is_trading,verification_note,verified_by,last_mutation_ref)
  VALUES(p_customer,p_brand,wanted,btrim(p_reason),p_actor,p_ref)
  RETURNING * INTO saved;
 END IF;
 INSERT INTO public.customer_brand_verification_audit
   (mutation_ref,customer_id,brand_id,actor_sub,action,reason,before_state,after_state)
 VALUES(p_ref,p_customer,p_brand,p_actor,p_action,btrim(p_reason),
   CASE WHEN previous.customer_id IS NULL THEN NULL ELSE to_jsonb(previous) END,to_jsonb(saved));
 RETURN to_jsonb(saved);
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_customer_brand_apply(text,uuid,uuid,uuid,integer,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_customer_brand_apply(text,uuid,uuid,uuid,integer,text,text) TO sales_api;

CREATE OR REPLACE FUNCTION public.sales_brand_alias_add(
 p_actor text,p_ref uuid,p_brand uuid,p_alias text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $fbmn$
DECLARE known public.catalog_brand_alias_audit%ROWTYPE; result_row public.catalog_brand_aliases%ROWTYPE;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.staff_members s WHERE s.user_sub=p_actor
    AND s.role='admin' AND s.active AND public.sales_identity_exists(s.user_sub))
 THEN RAISE EXCEPTION 'brand_alias_forbidden'; END IF;
 IF p_ref IS NULL OR p_brand IS NULL OR p_alias IS NULL
   OR length(btrim(p_alias)) NOT BETWEEN 1 AND 120
 THEN RAISE EXCEPTION 'brand_alias_invalid'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.catalog_brands b WHERE b.id=p_brand AND b.active)
 THEN RAISE EXCEPTION 'brand_alias_inactive'; END IF;
 SELECT * INTO known FROM public.catalog_brand_alias_audit WHERE mutation_ref=p_ref;
 IF FOUND THEN
   IF known.actor_sub=p_actor AND known.brand_id=p_brand AND known.alias_name=btrim(p_alias)
   THEN RETURN jsonb_build_object('brand_id',known.brand_id,'alias_name',known.alias_name,'idempotent',true); END IF;
   RAISE EXCEPTION 'brand_alias_conflict';
 END IF;
 IF EXISTS(SELECT 1 FROM public.catalog_brands WHERE normalized_name=lower(btrim(p_alias)))
 THEN RAISE EXCEPTION 'brand_alias_conflict'; END IF;
 INSERT INTO public.catalog_brand_aliases(alias_name,brand_id,created_by)
 VALUES(btrim(p_alias),p_brand,p_actor)
 ON CONFLICT(normalized_alias) DO NOTHING RETURNING * INTO result_row;
 IF result_row.brand_id IS NULL THEN RAISE EXCEPTION 'brand_alias_conflict'; END IF;
 INSERT INTO public.catalog_brand_alias_audit(mutation_ref,brand_id,alias_name,actor_sub)
 VALUES(p_ref,p_brand,btrim(p_alias),p_actor);
 UPDATE public.catalog_products SET brand_id=p_brand
 WHERE lower(btrim(brand))=lower(btrim(p_alias))
   AND brand_id IS DISTINCT FROM p_brand;
 RETURN jsonb_build_object('brand_id',result_row.brand_id,'alias_name',result_row.alias_name);
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_brand_alias_add(text,uuid,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_brand_alias_add(text,uuid,uuid,text) TO sales_api;

GRANT SELECT ON public.catalog_brand_aliases,public.customer_brand_verifications TO sales_api;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON
 public.catalog_brand_aliases,public.customer_brand_verifications FROM sales_api;
REVOKE ALL ON public.catalog_brand_alias_audit,public.customer_brand_verification_audit FROM sales_api;
