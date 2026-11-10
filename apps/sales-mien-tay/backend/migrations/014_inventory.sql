-- 014: separate inventory snapshots, batch audit, atomic confirm and rollback.
BEGIN;
ALTER TABLE public.catalog_products ADD COLUMN needs_review boolean NOT NULL DEFAULT false;
CREATE TABLE public.inventory_state(id integer PRIMARY KEY CHECK(id=1), revision bigint NOT NULL DEFAULT 0, latest_batch uuid);
INSERT INTO public.inventory_state(id) VALUES(1);
CREATE TABLE public.inventory_batches(
 id uuid PRIMARY KEY, actor_sub text NOT NULL, filename text NOT NULL, sheet text NOT NULL,
 request_hash text NOT NULL, content_hash text NOT NULL, applied_revision bigint NOT NULL UNIQUE, previous_batch uuid REFERENCES public.inventory_batches(id),
 row_count integer NOT NULL CHECK(row_count>0), status text NOT NULL DEFAULT 'applied' CHECK(status IN ('applied','rolled_back')),
 applied_at timestamptz NOT NULL DEFAULT now(), rolled_back_at timestamptz, rolled_back_by text, rollback_op uuid UNIQUE
);
CREATE TABLE public.inventory_stock(
 product_id uuid PRIMARY KEY REFERENCES public.catalog_products(id),
 quantity bigint CHECK(quantity BETWEEN 0 AND 2147483647), snapshot_at timestamptz,
 batch_id uuid REFERENCES public.inventory_batches(id),
 CHECK((quantity IS NULL AND snapshot_at IS NULL AND batch_id IS NULL) OR (quantity IS NOT NULL AND snapshot_at IS NOT NULL AND batch_id IS NOT NULL))
);
CREATE TABLE public.inventory_batch_rows(
 batch_id uuid NOT NULL REFERENCES public.inventory_batches(id), product_id uuid NOT NULL REFERENCES public.catalog_products(id),
 company_code text NOT NULL, row_number integer NOT NULL, old_quantity bigint, old_snapshot_at timestamptz,
 old_batch_id uuid REFERENCES public.inventory_batches(id), new_quantity bigint NOT NULL,
 created_product boolean NOT NULL, product_version integer NOT NULL, PRIMARY KEY(batch_id,product_id)
);
CREATE INDEX inventory_batches_recent ON public.inventory_batches(applied_at DESC);
REVOKE DELETE ON public.inventory_state,public.inventory_batches,public.inventory_stock,public.inventory_batch_rows FROM sales_api;
REVOKE UPDATE ON public.inventory_batch_rows FROM sales_api;
GRANT SELECT,INSERT,UPDATE ON public.inventory_state,public.inventory_batches,public.inventory_stock TO sales_api;
GRANT SELECT,INSERT ON public.inventory_batch_rows TO sales_api;
-- SQL function is invoker, checks active admin again in DB, serializes imports, all writes atomic.
CREATE FUNCTION public.inventory_apply(p_actor text,p_id uuid,p_file text,p_sheet text,p_hash text,p_content_hash text,p_revision bigint,p_rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SET search_path=public,pg_temp AS $fn$
DECLARE st inventory_state%ROWTYPE; prior inventory_batches%ROWTYPE; rec record; prod catalog_products%ROWTYPE; old_stock inventory_stock%ROWTYPE; created boolean; stamp timestamptz:=now(); cnt integer;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM staff_members WHERE user_sub=p_actor AND active AND role='admin') THEN RAISE EXCEPTION 'inventory_forbidden'; END IF;
 SELECT * INTO st FROM inventory_state WHERE id=1 FOR UPDATE;
 SELECT * INTO prior FROM inventory_batches WHERE id=p_id;
 IF FOUND THEN
  IF prior.actor_sub<>p_actor OR prior.request_hash<>p_hash THEN RAISE EXCEPTION 'inventory_conflict'; END IF;
  RETURN to_jsonb(prior);
 END IF;
 IF st.revision<>p_revision THEN RAISE EXCEPTION 'inventory_stale'; END IF;
 IF EXISTS(SELECT 1 FROM inventory_batches WHERE id=st.latest_batch AND content_hash=p_content_hash AND status='applied') THEN RAISE EXCEPTION 'inventory_duplicate'; END IF;
 IF jsonb_typeof(p_rows)<>'array' OR jsonb_array_length(p_rows) NOT BETWEEN 1 AND 2000 THEN RAISE EXCEPTION 'inventory_invalid'; END IF;
 SELECT count(DISTINCT x.company_code) INTO cnt FROM jsonb_to_recordset(p_rows) AS x(company_code text);
 IF cnt<>jsonb_array_length(p_rows) THEN RAISE EXCEPTION 'inventory_invalid'; END IF;
 INSERT INTO inventory_batches(id,actor_sub,filename,sheet,request_hash,content_hash,applied_revision,previous_batch,row_count,applied_at)
 VALUES(p_id,p_actor,p_file,p_sheet,p_hash,p_content_hash,st.revision+1,st.latest_batch,jsonb_array_length(p_rows),stamp);
 FOR rec IN SELECT * FROM jsonb_to_recordset(p_rows) AS x(company_code text,quantity bigint,row_number integer,product_version integer) ORDER BY company_code LOOP
  IF rec.company_code IS NULL OR length(rec.company_code) NOT BETWEEN 1 AND 80 OR rec.quantity IS NULL OR rec.quantity NOT BETWEEN 0 AND 2147483647 OR rec.row_number IS NULL OR rec.row_number<1 OR rec.product_version IS NULL OR rec.product_version<0 THEN RAISE EXCEPTION 'inventory_invalid'; END IF;
  SELECT * INTO prod FROM catalog_products WHERE company_code=rec.company_code FOR UPDATE;
  created:=NOT FOUND;
  IF created THEN
   IF rec.product_version<>0 THEN RAISE EXCEPTION 'inventory_stale'; END IF;
   INSERT INTO catalog_products(company_code,name,unit,needs_review) VALUES(rec.company_code,'Chưa xác minh: '||rec.company_code,NULL,true) RETURNING * INTO prod;
  ELSE
   IF prod.version<>rec.product_version OR NOT prod.active THEN RAISE EXCEPTION 'inventory_stale'; END IF;
  END IF;
  SELECT * INTO old_stock FROM inventory_stock WHERE product_id=prod.id;
  INSERT INTO inventory_batch_rows(batch_id,product_id,company_code,row_number,old_quantity,old_snapshot_at,old_batch_id,new_quantity,created_product,product_version)
  VALUES(p_id,prod.id,rec.company_code,rec.row_number,old_stock.quantity,old_stock.snapshot_at,old_stock.batch_id,rec.quantity,created,prod.version);
  INSERT INTO inventory_stock(product_id,quantity,snapshot_at,batch_id) VALUES(prod.id,rec.quantity,stamp,p_id)
  ON CONFLICT(product_id) DO UPDATE SET quantity=excluded.quantity,snapshot_at=excluded.snapshot_at,batch_id=excluded.batch_id;
 END LOOP;
 UPDATE inventory_state SET revision=st.revision+1,latest_batch=p_id WHERE id=1;
 RETURN (SELECT to_jsonb(b) FROM inventory_batches b WHERE id=p_id);
END $fn$;
CREATE FUNCTION public.inventory_rollback(p_actor text,p_id uuid,p_op uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=public,pg_temp AS $fn$
DECLARE st inventory_state%ROWTYPE; b inventory_batches%ROWTYPE; rec record; prod catalog_products%ROWTYPE;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM staff_members WHERE user_sub=p_actor AND active AND role='admin') THEN RAISE EXCEPTION 'inventory_forbidden'; END IF;
 SELECT * INTO st FROM inventory_state WHERE id=1 FOR UPDATE;
 SELECT * INTO b FROM inventory_batches WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'inventory_missing'; END IF;
 IF b.status='rolled_back' THEN
  IF b.rollback_op=p_op AND b.rolled_back_by=p_actor THEN RETURN to_jsonb(b); END IF;
  RAISE EXCEPTION 'inventory_conflict';
 END IF;
 IF st.latest_batch IS DISTINCT FROM p_id THEN RAISE EXCEPTION 'inventory_stale'; END IF;
 FOR rec IN SELECT * FROM inventory_batch_rows WHERE batch_id=p_id ORDER BY company_code LOOP
  SELECT * INTO prod FROM catalog_products WHERE id=rec.product_id FOR UPDATE;
  IF rec.created_product AND (prod.version<>rec.product_version OR NOT prod.needs_review) THEN RAISE EXCEPTION 'inventory_edited'; END IF;
  IF NOT EXISTS(SELECT 1 FROM inventory_stock WHERE product_id=rec.product_id AND batch_id=p_id) THEN RAISE EXCEPTION 'inventory_stale'; END IF;
  UPDATE inventory_stock SET quantity=rec.old_quantity,snapshot_at=rec.old_snapshot_at,batch_id=rec.old_batch_id WHERE product_id=rec.product_id;
  IF rec.created_product THEN UPDATE catalog_products SET active=false,version=version+1,updated_at=now() WHERE id=rec.product_id; END IF;
 END LOOP;
 UPDATE inventory_batches SET status='rolled_back',rolled_back_at=now(),rolled_back_by=p_actor,rollback_op=p_op WHERE id=p_id RETURNING * INTO b;
 UPDATE inventory_state SET revision=st.revision+1,latest_batch=b.previous_batch WHERE id=1;
 RETURN to_jsonb(b);
END $fn$;
REVOKE ALL ON FUNCTION public.inventory_apply(text,uuid,text,text,text,text,bigint,jsonb),public.inventory_rollback(text,uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.inventory_apply(text,uuid,text,text,text,text,bigint,jsonb),public.inventory_rollback(text,uuid,uuid) TO sales_api;
COMMIT;
