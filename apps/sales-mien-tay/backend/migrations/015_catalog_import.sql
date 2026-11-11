BEGIN;
CREATE TABLE public.catalog_import_batches(
 id uuid PRIMARY KEY, actor_sub text NOT NULL, filename text NOT NULL, sheet text NOT NULL,
 request_hash text NOT NULL, row_count integer NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
REVOKE UPDATE,DELETE ON public.catalog_import_batches FROM sales_api;
GRANT SELECT,INSERT ON public.catalog_import_batches TO sales_api;
CREATE FUNCTION public.catalog_import_apply(a text,b uuid,f text,s text,h text,rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SET search_path=public,pg_temp AS $fn$
DECLARE batch catalog_import_batches%ROWTYPE; rec record; old catalog_products%ROWTYPE; saved catalog_products%ROWTYPE;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM staff_members WHERE user_sub=a AND active AND role='admin') THEN RAISE EXCEPTION 'catalog_forbidden'; END IF;
 PERFORM pg_advisory_xact_lock(hashtext('catalog_import_apply'));
 SELECT * INTO batch FROM catalog_import_batches WHERE id=b;
 IF FOUND THEN
  IF batch.actor_sub<>a OR batch.request_hash<>h THEN RAISE EXCEPTION 'catalog_conflict'; END IF;
  RETURN to_jsonb(batch);
 END IF;
 IF jsonb_typeof(rows)<>'array' OR jsonb_array_length(rows) NOT BETWEEN 1 AND 2000 THEN RAISE EXCEPTION 'catalog_invalid'; END IF;
 INSERT INTO catalog_import_batches(id,actor_sub,filename,sheet,request_hash,row_count) VALUES(b,a,f,s,h,jsonb_array_length(rows)) RETURNING * INTO batch;
 FOR rec IN SELECT * FROM jsonb_to_recordset(rows) AS x(company_code text,version integer,name text,sku text,brand text,category text,unit text,product_spec jsonb,active boolean) ORDER BY company_code LOOP
  SELECT * INTO old FROM catalog_products WHERE company_code=rec.company_code FOR UPDATE;
  IF FOUND THEN
   IF old.version<>rec.version THEN RAISE EXCEPTION 'catalog_stale'; END IF;
   UPDATE catalog_products SET name=rec.name,sku=rec.sku,brand=rec.brand,category=rec.category,unit=rec.unit,product_spec=rec.product_spec,needs_review=CASE WHEN name IS DISTINCT FROM rec.name THEN false ELSE needs_review END,version=version+1,updated_at=now() WHERE id=old.id RETURNING * INTO saved;
   INSERT INTO catalog_edits(op_id,actor_sub,product_id,before_data,after_data) VALUES(gen_random_uuid(),a,saved.id,to_jsonb(old),to_jsonb(saved));
  ELSE
   IF rec.version<>0 THEN RAISE EXCEPTION 'catalog_stale'; END IF;
   INSERT INTO catalog_products(company_code,name,sku,brand,category,unit,product_spec) VALUES(rec.company_code,rec.name,rec.sku,rec.brand,rec.category,rec.unit,rec.product_spec) RETURNING * INTO saved;
   INSERT INTO catalog_edits(op_id,actor_sub,product_id,after_data) VALUES(gen_random_uuid(),a,saved.id,to_jsonb(saved));
  END IF;
 END LOOP;
 RETURN to_jsonb(batch);
END $fn$;
REVOKE ALL ON FUNCTION public.catalog_import_apply(text,uuid,text,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.catalog_import_apply(text,uuid,text,text,text,jsonb) TO sales_api;
COMMIT;
