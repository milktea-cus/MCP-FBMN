-- 092: Prospect photos share existing private R2; promotion copies metadata
-- to customer_photos without reuploading bytes or discarding original evidence.
BEGIN;
CREATE TABLE IF NOT EXISTS public.field_market_prospect_photos (
 id uuid PRIMARY KEY,
 prospect_id uuid NOT NULL REFERENCES public.field_prospects(id) ON DELETE RESTRICT,
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 kind text NOT NULL CHECK(kind IN ('front','shelf','goods','other')),
 captured_at timestamptz NOT NULL,
 object_key text NOT NULL UNIQUE,
 thumbnail_key text NOT NULL UNIQUE,
 mime_type text NOT NULL DEFAULT 'image/jpeg' CHECK(mime_type='image/jpeg'),
 bytes integer NOT NULL CHECK(bytes BETWEEN 100 AND 2097152),
 sha256 text NOT NULL CHECK(sha256 ~ '^[a-f0-9]{64}$'),
 thumbnail_bytes integer NOT NULL CHECK(thumbnail_bytes BETWEEN 100 AND 153600),
 thumbnail_sha256 text NOT NULL CHECK(thumbnail_sha256 ~ '^[a-f0-9]{64}$'),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','ready')),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS field_market_prospect_photos_lead ON public.field_market_prospect_photos(prospect_id,captured_at,id);

CREATE OR REPLACE FUNCTION public.sales_market_prospect_reserve_photo(
 p_actor text,p_prospect uuid,p_id uuid,p_kind text,p_captured timestamptz,
 p_bytes integer,p_hash text,p_thumb_bytes integer,p_thumb_hash text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
DECLARE lead public.field_prospects%ROWTYPE;
 saved public.field_market_prospect_photos%ROWTYPE;
 key text;
BEGIN
 IF p_id IS NULL OR p_prospect IS NULL OR p_kind NOT IN ('front','shelf','goods','other')
  OR p_captured IS NULL OR p_captured<now()-interval '30 days' OR p_captured>now()+interval '1 minute'
  OR p_bytes NOT BETWEEN 100 AND 2097152 OR p_thumb_bytes NOT BETWEEN 100 AND 153600
  OR p_hash !~ '^[a-f0-9]{64}$' OR p_thumb_hash !~ '^[a-f0-9]{64}$'
 THEN RAISE EXCEPTION 'market_photo_invalid';END IF;
 SELECT * INTO lead FROM public.field_prospects WHERE id=p_prospect FOR UPDATE;
 IF NOT FOUND OR lead.owner_sub<>p_actor OR lead.province IS NULL OR
   NOT public.sales_can_access(p_actor,lead.owner_sub,lead.province,lead.district)
 THEN RAISE EXCEPTION 'market_photo_forbidden';END IF;
 SELECT * INTO saved FROM public.field_market_prospect_photos WHERE id=p_id;
 IF FOUND THEN
  IF saved.prospect_id<>p_prospect OR saved.owner_sub<>p_actor OR saved.kind<>p_kind OR
   saved.captured_at IS DISTINCT FROM p_captured OR saved.bytes<>p_bytes OR
   saved.sha256<>p_hash OR saved.thumbnail_bytes<>p_thumb_bytes OR
   saved.thumbnail_sha256<>p_thumb_hash
  THEN RAISE EXCEPTION 'market_photo_conflict';END IF;
  RETURN to_jsonb(saved);
 END IF;
 IF lead.status<>'new' THEN RAISE EXCEPTION 'market_photo_conflict';END IF;
 IF (SELECT count(*) FROM public.field_market_prospect_photos WHERE prospect_id=p_prospect)>=12
 THEN RAISE EXCEPTION 'market_photo_limit';END IF;
 key:='market-prospects/'||p_prospect::text||'/'||p_id::text;
 INSERT INTO public.field_market_prospect_photos(id,prospect_id,owner_sub,kind,
  captured_at,object_key,thumbnail_key,bytes,sha256,thumbnail_bytes,thumbnail_sha256)
 VALUES(p_id,p_prospect,p_actor,p_kind,p_captured,key,key||'/thumbnail',
  p_bytes,p_hash,p_thumb_bytes,p_thumb_hash)
 RETURNING * INTO saved;
 RETURN to_jsonb(saved);
END $fn$;

-- Link metadata on completion, if this prospect was already promoted.
CREATE OR REPLACE FUNCTION public.field_market_prospect_photo_to_customer()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
DECLARE cid uuid;
BEGIN
 IF NEW.status<>'ready' THEN RETURN NEW;END IF;
 SELECT converted_customer_id INTO cid FROM public.field_prospects
  WHERE id=NEW.prospect_id AND status='converted';
 IF cid IS NOT NULL THEN
  INSERT INTO public.customer_photos(id,customer_id,owner_sub,object_key,mime_type,bytes)
  VALUES(NEW.id,cid,NEW.owner_sub,NEW.object_key,NEW.mime_type,NEW.bytes)
  ON CONFLICT(id) DO NOTHING;
 END IF;
 RETURN NEW;
END $fn$;
DROP TRIGGER IF EXISTS field_market_prospect_photo_customer ON public.field_market_prospect_photos;
CREATE TRIGGER field_market_prospect_photo_customer AFTER INSERT OR UPDATE OF status
 ON public.field_market_prospect_photos FOR EACH ROW
 EXECUTE FUNCTION public.field_market_prospect_photo_to_customer();

CREATE OR REPLACE FUNCTION public.field_market_prospect_promoted_photos()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
BEGIN
 IF NEW.status='converted' AND NEW.converted_customer_id IS NOT NULL THEN
  INSERT INTO public.customer_photos(id,customer_id,owner_sub,object_key,mime_type,bytes)
  SELECT photo.id,NEW.converted_customer_id,photo.owner_sub,photo.object_key,photo.mime_type,photo.bytes
  FROM public.field_market_prospect_photos photo
  WHERE photo.prospect_id=NEW.id AND photo.status='ready'
  ON CONFLICT(id) DO NOTHING;
 END IF;
 RETURN NEW;
END $fn$;
DROP TRIGGER IF EXISTS field_market_prospect_promoted_photos ON public.field_prospects;
CREATE TRIGGER field_market_prospect_promoted_photos AFTER UPDATE OF status,converted_customer_id
 ON public.field_prospects FOR EACH ROW
 EXECUTE FUNCTION public.field_market_prospect_promoted_photos();

CREATE OR REPLACE FUNCTION public.sales_market_prospect_finalize_photo(
 p_actor text,p_id uuid,p_sha text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
DECLARE saved public.field_market_prospect_photos%ROWTYPE;
BEGIN
 UPDATE public.field_market_prospect_photos p SET status='ready'
 WHERE p.id=p_id AND p.owner_sub=p_actor AND p.sha256=p_sha
   AND EXISTS(SELECT 1 FROM public.field_prospects l
     WHERE l.id=p.prospect_id AND l.owner_sub=p_actor AND l.province IS NOT NULL
       AND public.sales_can_access(p_actor,l.owner_sub,l.province,l.district))
 RETURNING * INTO saved;
 IF NOT FOUND THEN RAISE EXCEPTION 'market_photo_forbidden';END IF;
 RETURN to_jsonb(saved);
END $fn$;

REVOKE ALL ON FUNCTION public.sales_market_prospect_reserve_photo(text,uuid,uuid,text,timestamptz,integer,text,integer,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sales_market_prospect_finalize_photo(text,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_market_prospect_reserve_photo(text,uuid,uuid,text,timestamptz,integer,text,integer,text) TO sales_api;
GRANT EXECUTE ON FUNCTION public.sales_market_prospect_finalize_photo(text,uuid,text) TO sales_api;
GRANT SELECT ON public.field_market_prospect_photos TO sales_api;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.field_market_prospect_photos FROM sales_api;
COMMIT;
