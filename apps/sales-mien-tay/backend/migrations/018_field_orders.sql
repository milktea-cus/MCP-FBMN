BEGIN;
-- 018: Field Work order preparation only. No price, no financial posting, no stock decrement.
CREATE TABLE public.field_orders(
 id uuid PRIMARY KEY,
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 customer_id uuid NOT NULL REFERENCES public.customers(id),
 status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','exported','imported')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 note text NOT NULL DEFAULT '' CHECK(length(note)<=500),
 import_reference text,
 exported_at timestamptz,
 imported_at timestamptz,
 created_by text NOT NULL,
 updated_by text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX field_orders_owner ON public.field_orders(owner_sub,created_at DESC);
CREATE TABLE public.field_order_lines(
 order_id uuid NOT NULL REFERENCES public.field_orders(id),
 line_id uuid NOT NULL,
 product_id uuid NOT NULL REFERENCES public.catalog_products(id),
 quantity bigint NOT NULL CHECK(quantity BETWEEN 1 AND 100000000),
 unit text NOT NULL CHECK(length(unit) BETWEEN 1 AND 80),
 PRIMARY KEY(order_id,line_id),
 UNIQUE(order_id,product_id)
);
CREATE TABLE public.field_order_ops(
 op_id uuid PRIMARY KEY,
 order_id uuid NOT NULL REFERENCES public.field_orders(id),
 actor_sub text NOT NULL,
 request_data jsonb NOT NULL,
 before_data jsonb,
 after_data jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX field_order_ops_order ON public.field_order_ops(order_id,created_at);
-- There are default privileges on this production DB; explicitly revoke table mutations.
REVOKE ALL ON public.field_orders,public.field_order_lines,public.field_order_ops FROM sales_api;
GRANT SELECT ON public.field_orders,public.field_order_lines,public.field_order_ops TO sales_api;

CREATE FUNCTION public.field_order_apply(
 a text,op uuid,order_key uuid,expected integer,owner_id text,cid uuid,
 action text,items jsonb,memo text,stale_ack boolean,import_ref text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
DECLARE actor_role text; old public.field_orders%ROWTYPE; saved public.field_orders%ROWTYPE;
 prior public.field_order_ops%ROWTYPE; request_json jsonb; prev_json jsonb;
 line record; count_lines integer; rec record; stock_issue text; customer_code text; is_new boolean;
 BEGIN
 SELECT role INTO actor_role FROM public.staff_members WHERE user_sub=a AND active;
 IF actor_role IS NULL OR op IS NULL OR order_key IS NULL THEN RAISE EXCEPTION 'order_forbidden';END IF;
 IF owner_id IS NULL OR cid IS NULL OR action NOT IN ('save','export','imported') OR
    expected IS NULL OR expected<0 OR memo IS NULL OR length(memo)>500 OR
    jsonb_typeof(items)<>'array' OR jsonb_array_length(items)>100 THEN RAISE EXCEPTION 'order_invalid'; END IF;
 request_json:=jsonb_build_object('id',order_key,'expected',expected,'owner',owner_id,
  'customer',cid,'action',action,'items',items,'memo',memo,'ack',stale_ack,'reference',import_ref);
 PERFORM pg_advisory_xact_lock(hashtext('field_order:'||order_key::text));
 SELECT * INTO prior FROM public.field_order_ops WHERE op_id=op;
 IF FOUND THEN
  IF prior.actor_sub<>a OR prior.request_data<>request_json THEN RAISE EXCEPTION 'order_conflict';END IF;
  RETURN prior.after_data;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.customers c JOIN public.staff_members s ON s.user_sub=c.owner_sub AND s.active
    WHERE c.id=cid AND c.owner_sub=owner_id AND
    public.sales_can_access(a,owner_id,c.province,c.district) AND
    public.sales_can_access(owner_id,owner_id,c.province,c.district)) THEN RAISE EXCEPTION 'order_forbidden';END IF;
 IF actor_role='sales' AND owner_id<>a THEN RAISE EXCEPTION 'order_forbidden';END IF;
 SELECT * INTO old FROM public.field_orders WHERE id=order_key FOR UPDATE;
 is_new:=NOT FOUND;
 IF is_new THEN
  IF action<>'save' OR expected<>0 OR jsonb_array_length(items)<1 THEN RAISE EXCEPTION 'order_invalid';END IF;
 ELSE
  IF old.version<>expected THEN RAISE EXCEPTION 'order_stale';END IF;
  IF old.owner_sub<>owner_id OR old.customer_id<>cid THEN RAISE EXCEPTION 'order_forbidden';END IF;
  IF (action='save' AND old.status<>'draft')
    OR (action='export' AND old.status<>'draft')
    OR (action='imported' AND (old.status<>'exported' OR actor_role<>'admin')) THEN RAISE EXCEPTION 'order_state'; END IF;
 END IF;
 IF action='save' THEN
  count_lines:=jsonb_array_length(items);
  IF count_lines NOT BETWEEN 1 AND 100 OR
     (SELECT count(DISTINCT (x->>'line_id')) FROM jsonb_array_elements(items) x)<>count_lines OR
     (SELECT count(DISTINCT (x->>'product_id')) FROM jsonb_array_elements(items) x)<>count_lines
     THEN RAISE EXCEPTION 'order_invalid';END IF;
  FOR line IN SELECT * FROM jsonb_to_recordset(items) AS x(line_id uuid,product_id uuid,quantity bigint,unit text) LOOP
   IF line.line_id IS NULL OR line.product_id IS NULL OR line.quantity NOT BETWEEN 1 AND 100000000
     OR line.quantity IS NULL OR line.unit IS NULL OR length(line.unit) NOT BETWEEN 1 AND 80
     OR NOT EXISTS(SELECT 1 FROM public.catalog_products p WHERE p.id=line.product_id AND p.active
       AND p.unit=line.unit) THEN RAISE EXCEPTION 'order_invalid_unit'; END IF;
  END LOOP;
  IF is_new THEN
   INSERT INTO public.field_orders(id,owner_sub,customer_id,note,created_by,updated_by)
    VALUES(order_key,owner_id,cid,memo,a,a) RETURNING * INTO saved;
  ELSE
   UPDATE public.field_orders SET note=memo,updated_by=a,version=version+1,updated_at=now()
    WHERE id=order_key RETURNING * INTO saved;
   DELETE FROM public.field_order_lines WHERE field_order_lines.order_id=order_key;
  END IF;
  INSERT INTO public.field_order_lines(order_id,line_id,product_id,quantity,unit)
  SELECT order_key,x.line_id,x.product_id,x.quantity,x.unit
  FROM jsonb_to_recordset(items) AS x(line_id uuid,product_id uuid,quantity bigint,unit text);
 ELSIF action='export' THEN
  IF jsonb_array_length(items)<>0 THEN RAISE EXCEPTION 'order_invalid'; END IF;
  SELECT coalesce(nullif(btrim(m.company_code),''),nullif(btrim(c.code),'')) INTO customer_code
    FROM public.customers c LEFT JOIN public.catalog_customer_mapping m ON m.customer_id=c.id WHERE c.id=cid;
  IF customer_code IS NULL THEN RAISE EXCEPTION 'order_customer_code';END IF;
  IF NOT EXISTS(SELECT 1 FROM public.field_order_lines WHERE field_order_lines.order_id=order_key)
  THEN RAISE EXCEPTION 'order_invalid'; END IF;
  FOR rec IN SELECT l.quantity,l.unit,p.company_code,p.name,p.active,p.unit AS stock_unit,
    st.quantity AS available,st.snapshot_at
    FROM public.field_order_lines l JOIN public.catalog_products p ON p.id=l.product_id
    LEFT JOIN public.inventory_stock st ON st.product_id=p.id
    WHERE l.order_id=order_key LOOP
   IF NOT rec.active OR rec.stock_unit IS NULL OR rec.unit<>rec.stock_unit THEN
    RAISE EXCEPTION 'order_invalid_unit';END IF;
   IF rec.available IS NULL OR rec.snapshot_at IS NULL THEN RAISE EXCEPTION 'order_stock_missing'; END IF;
   IF rec.quantity>rec.available THEN RAISE EXCEPTION 'order_stock_short';END IF;
   IF rec.snapshot_at<now()-interval '7 days' THEN RAISE EXCEPTION 'order_stock_expired';END IF;
   IF rec.snapshot_at<now()-interval '24 hours' AND NOT stale_ack THEN
     RAISE EXCEPTION 'order_stock_stale';END IF;
  END LOOP;
  UPDATE public.field_orders SET status='exported',version=version+1,updated_by=a,
   updated_at=now(),exported_at=now() WHERE id=order_key RETURNING * INTO saved;
 ELSIF action='imported' THEN
  IF actor_role<>'admin' OR import_ref IS NULL OR length(btrim(import_ref)) NOT BETWEEN 1 AND 120
    THEN RAISE EXCEPTION 'order_invalid';END IF;
  UPDATE public.field_orders SET status='imported',version=version+1,updated_by=a,
   updated_at=now(),import_reference=btrim(import_ref),imported_at=now()
   WHERE id=order_key RETURNING * INTO saved;
 END IF;
 prev_json:=CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END;
 INSERT INTO public.field_order_ops(op_id,order_id,actor_sub,request_data,before_data,after_data)
 VALUES(op,order_key,a,request_json,prev_json,to_jsonb(saved));
 RETURN to_jsonb(saved);
 END $fn$;
REVOKE ALL ON FUNCTION public.field_order_apply(text,uuid,uuid,integer,text,uuid,text,jsonb,text,boolean,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.field_order_apply(text,uuid,uuid,integer,text,uuid,text,jsonb,text,boolean,text) TO sales_api;
COMMIT;