-- P0-3 correction: market brands are observations at customers, NOT SKU brands.
-- Existing SKU catalog belongs to Futurebook; keep market taxonomy independent.
CREATE TABLE IF NOT EXISTS public.market_brands (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 100),
 normalized_name text GENERATED ALWAYS AS (lower(regexp_replace(btrim(name),'[[:space:]]+',' ','g'))) STORED UNIQUE,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.market_customer_brands (
 customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
 brand_id uuid NOT NULL REFERENCES public.market_brands(id) ON DELETE RESTRICT,
 present boolean NOT NULL DEFAULT true,
 first_seen_at timestamptz NOT NULL,
 last_seen_at timestamptz NOT NULL,
 last_session_id uuid NOT NULL REFERENCES public.field_survey_sessions(id) ON DELETE RESTRICT,
 updated_by text NOT NULL REFERENCES public.staff_members(user_sub),
 PRIMARY KEY(customer_id,brand_id)
);
CREATE INDEX IF NOT EXISTS market_customer_brand_current_idx
 ON public.market_customer_brands(brand_id,customer_id) WHERE present;
CREATE INDEX IF NOT EXISTS market_customer_brand_last_idx
 ON public.market_customer_brands(customer_id,last_seen_at DESC);
CREATE TABLE IF NOT EXISTS public.market_survey_brand_observations (
 session_id uuid NOT NULL REFERENCES public.field_survey_sessions(id) ON DELETE RESTRICT,
 customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
 brand_id uuid NOT NULL REFERENCES public.market_brands(id) ON DELETE RESTRICT,
 observed_at timestamptz NOT NULL,
 actor_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 PRIMARY KEY(session_id,brand_id)
);
CREATE INDEX IF NOT EXISTS market_survey_observation_brand_idx
 ON public.market_survey_brand_observations(brand_id,customer_id,observed_at DESC);

ALTER TABLE public.field_survey_sessions
 ADD COLUMN IF NOT EXISTS market_brand_names jsonb DEFAULT NULL;
ALTER TABLE public.field_survey_sessions
 ADD CONSTRAINT market_brand_names_shape CHECK (
  market_brand_names IS NULL
  OR (jsonb_typeof(market_brand_names)='array'
      AND jsonb_array_length(market_brand_names) <= 50)
 );

-- SKU is Futurebook-owned product catalog, never a source for market coverage.
INSERT INTO public.catalog_brands(name)
 VALUES('Futurebook') ON CONFLICT(normalized_name) DO NOTHING;
UPDATE public.catalog_products SET brand='Futurebook',version=version+1,updated_at=now()
 WHERE brand IS NULL OR btrim(brand)='';

-- Atomically finalize the survey and refresh one customer/brand current presence.
-- Null market names => no market update (legacy clients); [] => explicitly none seen.
-- Unique customer/brand guarantees revisits do NOT increase market counts.
-- Out-of-order offline synchronization cannot roll back a later observation.
CREATE OR REPLACE FUNCTION public.sales_complete_survey_market(
 p_actor text,p_id uuid,p_ref uuid,p_version integer,
 p_end timestamptz,p_note text,p_answers jsonb,p_brands jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $fbmn$
DECLARE
 existing public.field_survey_sessions%ROWTYPE;
 saved public.field_survey_sessions%ROWTYPE;
 item jsonb; raw_name text; clean_name text; bid uuid;
 chosen_ids uuid[] := ARRAY[]::uuid[];
BEGIN
 IF p_actor IS NULL OR p_id IS NULL OR p_ref IS NULL
   OR p_version IS NULL OR p_version<1 OR p_end IS NULL
   OR p_note IS NULL OR length(p_note)>4000
   OR p_answers IS NULL OR jsonb_typeof(p_answers)<>'object'
   OR (p_brands IS NOT NULL AND
      (jsonb_typeof(p_brands)<>'array' OR jsonb_array_length(p_brands)>50))
 THEN RAISE EXCEPTION 'market_survey_invalid'; END IF;
 IF p_brands IS NOT NULL THEN
  FOR item IN SELECT value FROM jsonb_array_elements(p_brands) LOOP
   IF jsonb_typeof(item)<>'string' THEN RAISE EXCEPTION 'market_brand_invalid'; END IF;
   raw_name=item #>> '{}';
   clean_name=regexp_replace(btrim(raw_name),'[[:space:]]+',' ','g');
   IF length(clean_name) NOT BETWEEN 1 AND 100 OR
      clean_name ~ '[[:cntrl:]]'
   THEN RAISE EXCEPTION 'market_brand_invalid'; END IF;
  END LOOP;
 END IF;
 SELECT * INTO existing FROM public.field_survey_sessions
  WHERE id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'market_survey_not_found'; END IF;
 IF existing.owner_sub<>p_actor OR
   NOT public.sales_customer_fieldwork_allowed(p_actor,existing.customer_id)
   OR NOT public.sales_customer_allowed(p_actor,existing.customer_id,'view')
 THEN RAISE EXCEPTION 'market_survey_forbidden'; END IF;
 IF existing.last_mutation_ref=p_ref AND existing.status='completed'
 THEN RETURN to_jsonb(existing); END IF;
 IF existing.status<>'in_progress' OR existing.version<>p_version
 THEN RAISE EXCEPTION 'market_survey_stale'; END IF;
 IF p_end<existing.started_at OR
    p_end>now()+interval '1 minute' OR
    p_end<now()-interval '30 days'
 THEN RAISE EXCEPTION 'market_survey_invalid'; END IF;
 IF EXISTS(SELECT 1 FROM public.field_survey_photos ph
    WHERE ph.session_id=p_id AND ph.status<>'ready')
 OR (SELECT count(DISTINCT ph.kind) FROM public.field_survey_photos ph
    WHERE ph.session_id=p_id AND ph.status='ready'
      AND ph.kind IN ('front','shelf','goods'))<>3
 THEN RAISE EXCEPTION 'market_survey_photos'; END IF;
 -- Serialization by customer prevents concurrent surveys corrupting latest-state.
 PERFORM 1 FROM public.customers c WHERE c.id=existing.customer_id FOR UPDATE;
 IF p_brands IS NOT NULL THEN
  FOR item IN SELECT value FROM jsonb_array_elements(p_brands) LOOP
   raw_name=item #>> '{}';
   clean_name=regexp_replace(btrim(raw_name),'[[:space:]]+',' ','g');
   INSERT INTO public.market_brands(name) VALUES(clean_name)
    ON CONFLICT(normalized_name) DO NOTHING;
   SELECT id INTO bid FROM public.market_brands
    WHERE normalized_name=lower(clean_name);
   IF bid IS NULL THEN RAISE EXCEPTION 'market_brand_invalid'; END IF;
   IF NOT bid=ANY(chosen_ids) THEN
    chosen_ids=array_append(chosen_ids,bid);
    INSERT INTO public.market_survey_brand_observations
      (session_id,customer_id,brand_id,observed_at,actor_sub)
    VALUES(p_id,existing.customer_id,bid,p_end,p_actor)
    ON CONFLICT(session_id,brand_id) DO NOTHING;
    INSERT INTO public.market_customer_brands
     (customer_id,brand_id,present,first_seen_at,last_seen_at,last_session_id,updated_by)
    VALUES(existing.customer_id,bid,true,p_end,p_end,p_id,p_actor)
    ON CONFLICT(customer_id,brand_id) DO UPDATE SET
      present=true,
      last_seen_at=EXCLUDED.last_seen_at,
      last_session_id=EXCLUDED.last_session_id,
      updated_by=EXCLUDED.updated_by
    WHERE public.market_customer_brands.last_seen_at<=EXCLUDED.last_seen_at;
   END IF;
  END LOOP;
  -- An explicit replacement snapshot can mark absent brands as no longer seen.
  UPDATE public.market_customer_brands mc SET
    present=false,last_seen_at=p_end,last_session_id=p_id,updated_by=p_actor
  WHERE mc.customer_id=existing.customer_id AND mc.present
    AND NOT mc.brand_id=ANY(chosen_ids)
    AND mc.last_seen_at<=p_end;
 END IF;
 UPDATE public.field_survey_sessions s SET
  answers=p_answers,note=p_note,ended_at=p_end,status='completed',
  version=version+1,last_mutation_ref=p_ref,market_brand_names=p_brands
 WHERE s.id=p_id RETURNING * INTO saved;
 RETURN to_jsonb(saved);
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_complete_survey_market(text,uuid,uuid,integer,timestamptz,text,jsonb,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_complete_survey_market(text,uuid,uuid,integer,timestamptz,text,jsonb,jsonb) TO sales_api;
GRANT SELECT ON public.market_brands,public.market_customer_brands,public.market_survey_brand_observations TO sales_api;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON
 public.market_brands,public.market_customer_brands,public.market_survey_brand_observations
 FROM sales_api;
