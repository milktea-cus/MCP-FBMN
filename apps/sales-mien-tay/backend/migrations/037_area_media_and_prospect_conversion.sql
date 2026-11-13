-- P0-L: private area/chain-visit evidence and explicit prospect conversion.
-- Additive tables: no changes to existing customer records, no auto-creation of customers.
CREATE TABLE IF NOT EXISTS public.field_area_visit_photos (
 id uuid PRIMARY KEY,
 area_visit_id uuid NOT NULL REFERENCES public.field_area_visits(id) ON DELETE RESTRICT,
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 kind text NOT NULL CHECK(kind IN ('front','shelf','goods','other')),
 mime_type text NOT NULL DEFAULT 'image/jpeg' CHECK(mime_type='image/jpeg'),
 bytes integer NOT NULL CHECK(bytes BETWEEN 100 AND 2097152),
 sha256 text NOT NULL CHECK(sha256 ~ '^[0-9a-f]{64}$'),
 object_key text NOT NULL UNIQUE,
 thumbnail_key text NOT NULL UNIQUE,
 thumbnail_bytes integer NOT NULL CHECK(thumbnail_bytes BETWEEN 100 AND 153600),
 thumbnail_sha256 text NOT NULL CHECK(thumbnail_sha256 ~ '^[0-9a-f]{64}$'),
 captured_at timestamptz NOT NULL,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','ready')),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS area_visit_photos_visit_time ON public.field_area_visit_photos(area_visit_id,captured_at,id);

CREATE TABLE IF NOT EXISTS public.field_prospect_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 prospect_id uuid NOT NULL REFERENCES public.field_prospects(id) ON DELETE RESTRICT,
 actor_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 action text NOT NULL CHECK(action IN ('convert')),
 customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
 created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.sales_reserve_area_photo(
 p_actor text,p_visit uuid,p_id uuid,p_kind text,p_captured timestamptz,
 p_bytes integer,p_hash text,p_thumbnail_bytes integer,p_thumbnail_hash text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE visit public.field_area_visits%ROWTYPE;
 old public.field_area_visit_photos%ROWTYPE;
 saved public.field_area_visit_photos%ROWTYPE;
 resource text;
 thumb text;
BEGIN
 IF p_actor IS NULL OR p_visit IS NULL OR p_id IS NULL OR
 p_kind NOT IN ('front','shelf','goods','other') OR
 p_bytes NOT BETWEEN 100 AND 2097152 OR p_thumbnail_bytes NOT BETWEEN 100 AND 153600 OR
 p_hash !~ '^[0-9a-f]{64}$' OR p_thumbnail_hash !~ '^[0-9a-f]{64}$' OR
 p_captured IS NULL OR p_captured>now()+interval '1 minute' OR
 p_captured<now()-interval '30 days'
 THEN RAISE EXCEPTION 'area photo invalid'; END IF;
 SELECT * INTO visit FROM public.field_area_visits WHERE id=p_visit FOR UPDATE;
 IF NOT FOUND OR visit.owner_sub<>p_actor OR
 NOT EXISTS(
  SELECT 1 FROM public.field_route_stops st
   JOIN public.field_day_routes r ON r.id=st.day_route_id
   JOIN public.field_monthly_plans m ON m.id=r.monthly_plan_id
   WHERE st.id=visit.day_route_stop_id AND r.owner_sub=p_actor AND
    public.sales_monthly_plan_scope_allowed(p_actor,m.scope_kind,m.scope_key,m.province,m.district))
 THEN RAISE EXCEPTION 'area photo permission denied'; END IF;
 IF p_captured<visit.checkin_at-interval '1 minute' THEN RAISE EXCEPTION 'area photo invalid time'; END IF;
 resource:='area-visits/'||p_visit::text||'/'||p_id::text||'/'||p_hash;
 thumb:=resource||'/thumb-'||p_thumbnail_hash;
 SELECT * INTO old FROM public.field_area_visit_photos WHERE id=p_id;
 IF FOUND THEN
  IF old.owner_sub<>p_actor OR old.area_visit_id<>p_visit OR old.kind<>p_kind OR
   old.captured_at IS DISTINCT FROM p_captured OR old.sha256<>p_hash OR
   old.bytes<>p_bytes OR old.thumbnail_bytes<>p_thumbnail_bytes OR
   old.thumbnail_sha256<>p_thumbnail_hash
  THEN RAISE EXCEPTION 'area photo conflict'; END IF;
  RETURN to_jsonb(old);
 END IF;
 IF (SELECT count(*) FROM public.field_area_visit_photos WHERE area_visit_id=p_visit)>=12
 THEN RAISE EXCEPTION 'area photo limit'; END IF;
 INSERT INTO public.field_area_visit_photos
  (id,area_visit_id,owner_sub,kind,captured_at,bytes,sha256,object_key,thumbnail_bytes,thumbnail_sha256,thumbnail_key)
 VALUES(p_id,p_visit,p_actor,p_kind,p_captured,p_bytes,p_hash,resource,p_thumbnail_bytes,p_thumbnail_hash,thumb)
 RETURNING * INTO saved;
 RETURN to_jsonb(saved);
END
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_reserve_area_photo(text,uuid,uuid,text,timestamptz,integer,text,integer,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_reserve_area_photo(text,uuid,uuid,text,timestamptz,integer,text,integer,text) TO sales_api;

CREATE OR REPLACE FUNCTION public.sales_finalize_area_photo(p_actor text,p_id uuid,p_sha text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE saved public.field_area_visit_photos%ROWTYPE;
BEGIN
 UPDATE public.field_area_visit_photos p SET status='ready'
 WHERE p.id=p_id AND p.owner_sub=p_actor AND p.sha256=p_sha AND
 EXISTS(SELECT 1 FROM public.field_area_visits v
 JOIN public.field_route_stops st ON st.id=v.day_route_stop_id
 JOIN public.field_day_routes r ON r.id=st.day_route_id
 JOIN public.field_monthly_plans m ON m.id=r.monthly_plan_id
 WHERE v.id=p.area_visit_id AND
 public.sales_monthly_plan_scope_allowed(p_actor,m.scope_kind,m.scope_key,m.province,m.district))
 RETURNING * INTO saved;
 IF NOT FOUND THEN RAISE EXCEPTION 'area photo permission denied'; END IF;
 RETURN to_jsonb(saved);
END
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_finalize_area_photo(text,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_finalize_area_photo(text,uuid,text) TO sales_api;

-- Explicitly link a verified existing customer; never synthesize a customer from a lead.
CREATE OR REPLACE FUNCTION public.sales_convert_prospect(p_actor text,p_id uuid,p_customer uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE found public.field_prospects%ROWTYPE;
 stop_row public.field_route_stops%ROWTYPE;
 customer_row public.customers%ROWTYPE;
BEGIN
 SELECT * INTO found FROM public.field_prospects WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR found.owner_sub<>p_actor THEN RAISE EXCEPTION 'prospect permission denied'; END IF;
 IF found.status='converted' AND found.converted_customer_id=p_customer THEN RETURN to_jsonb(found); END IF;
 IF found.status<>'new' THEN RAISE EXCEPTION 'prospect conflict'; END IF;
 SELECT st.* INTO stop_row FROM public.field_route_stops st
 JOIN public.field_area_visits v ON v.day_route_stop_id=st.id
 WHERE v.id=found.area_visit_id;
 SELECT * INTO customer_row FROM public.customers WHERE id=p_customer;
 IF NOT FOUND OR NOT public.sales_customer_plannable(p_actor,p_customer)
 OR NOT public.sales_customer_allowed(p_actor,p_customer,'view') OR
 (stop_row.stop_kind='area' AND
  (customer_row.province IS DISTINCT FROM stop_row.province OR
  (stop_row.district<>'' AND customer_row.district IS DISTINCT FROM stop_row.district))) OR
 (stop_row.stop_kind='chain' AND NOT EXISTS(
  SELECT 1 FROM public.customer_scope_bindings cb WHERE cb.customer_id=p_customer
    AND cb.active AND cb.scope_kind='chain' AND cb.scope_key=stop_row.chain_id::text))
 THEN RAISE EXCEPTION 'prospect permission denied'; END IF;
 UPDATE public.field_prospects SET status='converted',converted_customer_id=p_customer,updated_at=now()
 WHERE id=p_id RETURNING * INTO found;
 INSERT INTO public.field_prospect_events(prospect_id,actor_sub,action,customer_id)
 VALUES(p_id,p_actor,'convert',p_customer);
 RETURN to_jsonb(found);
END
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_convert_prospect(text,uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_convert_prospect(text,uuid,uuid) TO sales_api;

-- Treat fieldwork at area/chain locations as real visits when locking a route/stop.
CREATE OR REPLACE FUNCTION public.field_guard_area_stop_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $fbmn$
BEGIN
 IF (NEW.sequence IS DISTINCT FROM OLD.sequence OR NEW.purpose IS DISTINCT FROM OLD.purpose)
 AND EXISTS(SELECT 1 FROM public.field_area_visits a WHERE a.day_route_stop_id=OLD.id)
 THEN RAISE EXCEPTION 'stop already visited'; END IF;
 RETURN NEW;
END $fbmn$;
DROP TRIGGER IF EXISTS field_area_stop_guard ON public.field_route_stops;
CREATE TRIGGER field_area_stop_guard BEFORE UPDATE ON public.field_route_stops
 FOR EACH ROW EXECUTE FUNCTION public.field_guard_area_stop_mutation();

CREATE OR REPLACE FUNCTION public.field_guard_area_route_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $fbmn$
BEGIN
 IF (NEW.route_date IS DISTINCT FROM OLD.route_date OR NEW.status='cancelled')
 AND EXISTS(SELECT 1 FROM public.field_route_stops s
 JOIN public.field_area_visits a ON a.day_route_stop_id=s.id WHERE s.day_route_id=OLD.id)
 THEN RAISE EXCEPTION 'route already visited'; END IF;
 RETURN NEW;
END $fbmn$;
DROP TRIGGER IF EXISTS field_area_route_guard ON public.field_day_routes;
CREATE TRIGGER field_area_route_guard BEFORE UPDATE ON public.field_day_routes
 FOR EACH ROW EXECUTE FUNCTION public.field_guard_area_route_mutation();

GRANT SELECT ON public.field_area_visit_photos,public.field_prospect_events TO sales_api;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON
 public.field_area_visit_photos,public.field_prospect_events FROM sales_api;
