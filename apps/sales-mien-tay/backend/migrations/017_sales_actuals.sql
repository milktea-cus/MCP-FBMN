BEGIN;
CREATE UNIQUE INDEX IF NOT EXISTS customers_unique_company_code_per_owner ON public.customers(owner_sub,code) WHERE code IS NOT NULL AND btrim(code)<>'';
CREATE TABLE public.sales_actuals(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 customer_id uuid NOT NULL REFERENCES public.customers(id),
 product_id uuid NOT NULL REFERENCES public.catalog_products(id),
 sale_date date NOT NULL CHECK(sale_date BETWEEN DATE '2000-01-01' AND DATE '2100-12-31'),
 quantity integer NOT NULL CHECK(quantity BETWEEN 1 AND 1000000000),
 amount bigint NOT NULL CHECK(amount BETWEEN 0 AND 1000000000000),
 source text NOT NULL CHECK(source IN ('manual','company')),
 external_ref text,
 line_ref text,
 status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','void')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 created_by text NOT NULL,
 updated_by text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK((source='manual' AND external_ref IS NULL AND line_ref IS NULL) OR
 (source='company' AND length(btrim(external_ref)) BETWEEN 1 AND 120 AND length(btrim(line_ref)) BETWEEN 1 AND 80))
);
CREATE UNIQUE INDEX sales_actual_company_key ON public.sales_actuals(external_ref,line_ref) WHERE source='company';
CREATE INDEX sales_actual_owner_date ON public.sales_actuals(owner_sub,sale_date);
CREATE INDEX sales_actual_customer_date ON public.sales_actuals(customer_id,sale_date);
CREATE INDEX sales_actual_product_date ON public.sales_actuals(product_id,sale_date);
CREATE TABLE public.sales_actual_batches(
 id uuid PRIMARY KEY, actor_sub text NOT NULL, filename text NOT NULL,
 sheet text NOT NULL, request_hash text NOT NULL, row_count integer NOT NULL,
 inserted_count integer NOT NULL, skipped_count integer NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.sales_actual_edits(
 op_id uuid PRIMARY KEY,
 actual_id uuid NOT NULL REFERENCES public.sales_actuals(id),
 batch_id uuid REFERENCES public.sales_actual_batches(id),
 actor_sub text NOT NULL,
 request_data jsonb,
 before_data jsonb,
 after_data jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sales_actual_edits_actual ON public.sales_actual_edits(actual_id,created_at);
CREATE INDEX sales_actual_edits_batch ON public.sales_actual_edits(batch_id);
REVOKE ALL ON public.sales_actuals,public.sales_actual_batches,public.sales_actual_edits FROM sales_api;
GRANT SELECT ON public.sales_actuals,public.sales_actual_batches,public.sales_actual_edits TO sales_api;

CREATE FUNCTION public.sales_actual_authorized(a text, o text, c uuid, p uuid) RETURNS boolean
LANGUAGE sql STABLE SET search_path=pg_catalog,public AS $fn$
 SELECT EXISTS(
  SELECT 1 FROM public.staff_members actor JOIN public.staff_members own ON own.user_sub=o
  JOIN public.customers cust ON cust.id=c AND cust.owner_sub=o
  JOIN public.catalog_products prod ON prod.id=p
  WHERE actor.user_sub=a AND actor.active AND own.active AND prod.active
  AND public.sales_can_access(a,o,cust.province,cust.district)
  AND public.sales_can_access(o,o,cust.province,cust.district)
 );
$fn$;
REVOKE ALL ON FUNCTION public.sales_actual_authorized(text,text,uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_actual_authorized(text,text,uuid,uuid) TO sales_api;

CREATE FUNCTION public.sales_actual_import_apply(a text,b uuid,f text,s text,h text,rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
DECLARE oldbatch public.sales_actual_batches%ROWTYPE; rec record; old public.sales_actuals%ROWTYPE; saved public.sales_actuals%ROWTYPE; added integer:=0; skipped integer:=0; result jsonb;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=a AND active AND role IN ('admin','manager')) THEN RAISE EXCEPTION 'actual_forbidden'; END IF;
 IF b IS NULL OR length(btrim(f)) NOT BETWEEN 1 AND 180 OR length(btrim(s)) NOT BETWEEN 1 AND 80 OR length(h)<>64
 OR jsonb_typeof(rows)<>'array' OR jsonb_array_length(rows) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'actual_invalid'; END IF;
 PERFORM pg_advisory_xact_lock(hashtext('actual_company_import'));
 SELECT * INTO oldbatch FROM public.sales_actual_batches WHERE id=b;
 IF FOUND THEN
  IF oldbatch.actor_sub<>a OR oldbatch.request_hash<>h THEN RAISE EXCEPTION 'actual_conflict'; END IF;
  RETURN to_jsonb(oldbatch);
 END IF;
 INSERT INTO public.sales_actual_batches(id,actor_sub,filename,sheet,request_hash,row_count,inserted_count,skipped_count)
 VALUES(b,a,f,s,h,jsonb_array_length(rows),0,0);
 FOR rec IN SELECT * FROM jsonb_to_recordset(rows) AS x(
   owner_sub text,customer_id uuid,product_id uuid,sale_date date,quantity integer,amount bigint,external_ref text,line_ref text
 ) LOOP
  IF rec.owner_sub IS NULL OR rec.customer_id IS NULL OR rec.product_id IS NULL
  OR rec.sale_date NOT BETWEEN DATE '2000-01-01' AND DATE '2100-12-31' OR rec.sale_date IS NULL
  OR rec.quantity IS NULL OR rec.quantity NOT BETWEEN 1 AND 1000000000
  OR rec.amount IS NULL OR rec.amount NOT BETWEEN 0 AND 1000000000000
  OR rec.external_ref IS NULL OR length(btrim(rec.external_ref)) NOT BETWEEN 1 AND 120
  OR rec.line_ref IS NULL OR length(btrim(rec.line_ref)) NOT BETWEEN 1 AND 80 THEN RAISE EXCEPTION 'actual_invalid'; END IF;
  IF NOT public.sales_actual_authorized(a,rec.owner_sub,rec.customer_id,rec.product_id) THEN RAISE EXCEPTION 'actual_forbidden'; END IF;
  SELECT * INTO old FROM public.sales_actuals WHERE source='company' AND external_ref=rec.external_ref AND line_ref=rec.line_ref FOR UPDATE;
  IF FOUND THEN
   IF old.owner_sub<>rec.owner_sub OR old.customer_id<>rec.customer_id OR old.product_id<>rec.product_id
   OR old.sale_date<>rec.sale_date OR old.quantity<>rec.quantity OR old.amount<>rec.amount OR old.status<>'active' THEN RAISE EXCEPTION 'actual_duplicate_conflict'; END IF;
   skipped:=skipped+1;
  ELSE
   INSERT INTO public.sales_actuals(owner_sub,customer_id,product_id,sale_date,quantity,amount,source,external_ref,line_ref,created_by,updated_by)
   VALUES(rec.owner_sub,rec.customer_id,rec.product_id,rec.sale_date,rec.quantity,rec.amount,'company',rec.external_ref,rec.line_ref,a,a) RETURNING * INTO saved;
   INSERT INTO public.sales_actual_edits(op_id,actual_id,batch_id,actor_sub,after_data) VALUES(gen_random_uuid(),saved.id,b,a,to_jsonb(saved));
   added:=added+1;
  END IF;
 END LOOP;
 UPDATE public.sales_actual_batches SET inserted_count=added,skipped_count=skipped WHERE id=b RETURNING * INTO oldbatch;
 result:=to_jsonb(oldbatch);
 RETURN result;
END $fn$;
REVOKE ALL ON FUNCTION public.sales_actual_import_apply(text,uuid,text,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_actual_import_apply(text,uuid,text,text,text,jsonb) TO sales_api;

CREATE FUNCTION public.sales_actual_write(a text,op uuid,target uuid,expected_version integer,doc jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
DECLARE prior public.sales_actual_edits%ROWTYPE; old public.sales_actuals%ROWTYPE; saved public.sales_actuals%ROWTYPE;
 o text; c uuid; p uuid; dt date; qty int; amt bigint; next_status text; actor_role text;
BEGIN
 SELECT role INTO actor_role FROM public.staff_members WHERE user_sub=a AND active;
 IF actor_role IS NULL THEN RAISE EXCEPTION 'actual_forbidden'; END IF;
 SELECT * INTO prior FROM public.sales_actual_edits WHERE op_id=op;
 IF FOUND THEN
  IF prior.actor_sub<>a OR prior.request_data IS DISTINCT FROM jsonb_build_object('target',target,'version',expected_version,'doc',doc) THEN RAISE EXCEPTION 'actual_conflict'; END IF;
  RETURN prior.after_data;
 END IF;
 IF jsonb_typeof(doc)<>'object' OR op IS NULL THEN RAISE EXCEPTION 'actual_invalid'; END IF;
 o:=doc->>'owner_sub';c:=(doc->>'customer_id')::uuid;p:=(doc->>'product_id')::uuid;
 dt:=(doc->>'sale_date')::date;qty:=(doc->>'quantity')::integer;amt:=(doc->>'amount')::bigint;
 next_status:=coalesce(doc->>'status','active');
 IF qty NOT BETWEEN 1 AND 1000000000 OR qty IS NULL OR amt NOT BETWEEN 0 AND 1000000000000 OR amt IS NULL
 OR dt NOT BETWEEN DATE '2000-01-01' AND DATE '2100-12-31' OR dt IS NULL OR next_status NOT IN ('active','void')
 THEN RAISE EXCEPTION 'actual_invalid'; END IF;
 IF NOT public.sales_actual_authorized(a,o,c,p) THEN RAISE EXCEPTION 'actual_forbidden'; END IF;
 IF target IS NULL THEN
  IF expected_version<>0 OR next_status<>'active' OR (actor_role='sales' AND o<>a) THEN RAISE EXCEPTION 'actual_forbidden'; END IF;
  INSERT INTO public.sales_actuals(owner_sub,customer_id,product_id,sale_date,quantity,amount,source,status,created_by,updated_by)
  VALUES(o,c,p,dt,qty,amt,'manual','active',a,a) RETURNING * INTO saved;
 ELSE
  SELECT * INTO old FROM public.sales_actuals WHERE id=target FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'actual_not_found'; END IF;
  IF old.version<>expected_version THEN RAISE EXCEPTION 'actual_stale'; END IF;
  IF actor_role='sales' AND (old.owner_sub<>a OR old.source<>'manual') THEN RAISE EXCEPTION 'actual_forbidden'; END IF;
  IF old.source='company' AND actor_role NOT IN ('admin','manager') THEN RAISE EXCEPTION 'actual_forbidden'; END IF;
  IF NOT public.sales_actual_authorized(a,old.owner_sub,old.customer_id,old.product_id)
  OR (actor_role='sales' AND o<>old.owner_sub) THEN RAISE EXCEPTION 'actual_forbidden'; END IF;
  UPDATE public.sales_actuals SET owner_sub=o,customer_id=c,product_id=p,sale_date=dt,quantity=qty,amount=amt,
  status=next_status,version=version+1,updated_by=a,updated_at=now()
  WHERE id=target RETURNING * INTO saved;
 END IF;
 INSERT INTO public.sales_actual_edits(op_id,actual_id,actor_sub,request_data,before_data,after_data) VALUES(op,saved.id,a,jsonb_build_object('target',target,'version',expected_version,'doc',doc),to_jsonb(old),to_jsonb(saved));
 RETURN to_jsonb(saved);
END $fn$;
REVOKE ALL ON FUNCTION public.sales_actual_write(text,uuid,uuid,integer,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_actual_write(text,uuid,uuid,integer,jsonb) TO sales_api;
COMMIT;