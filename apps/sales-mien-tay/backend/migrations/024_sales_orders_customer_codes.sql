-- 024: Sales-only order export without ERP stock gating, and immutable customer code.
-- Internal Field Work code is separate from the optional company customer code.
BEGIN;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS field_code varchar(6);
CREATE OR REPLACE FUNCTION public.field_customer_code_root(p_name text,p_province text)
RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog,public AS $root$
DECLARE a text; n text; p text[]; w text[]; place text; who text;
BEGIN
 a:=regexp_replace(translate(lower(coalesce(p_province,'')),'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ','aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'),'[^a-z0-9]+',' ','g');
 n:=regexp_replace(translate(lower(coalesce(p_name,'')),'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ','aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'),'[^a-z0-9]+',' ','g');
 p:=regexp_split_to_array(btrim(a),'\s+');
 w:=regexp_split_to_array(btrim(n),'\s+');
 IF array_length(p,1)>1 THEN
   place:=substr(p[1],1,1)||substr(p[array_length(p,1)],1,1);
 ELSE
   place:=substr(coalesce(p[1],'XX')||'XX',1,2);
 END IF;
 IF array_length(w,1)>1 THEN
   who:=substr(w[array_length(w,1)-1],1,1)||substr(w[array_length(w,1)],1,1);
 ELSE
   who:=substr(coalesce(w[1],'XX')||'XX',1,2);
 END IF;
 RETURN upper(substr(coalesce(place,'XX')||'XX',1,2)||
              substr(coalesce(who,'XX')||'XX',1,2));
END $root$;
CREATE OR REPLACE FUNCTION public.field_customer_code_assign()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $trg$
DECLARE prefix text; candidate text; ix integer;
BEGIN
 -- Field Work code is immutable. The company/import code stays in customers.code.
 IF TG_OP='UPDATE' AND OLD.field_code IS NOT NULL THEN
   NEW.field_code:=OLD.field_code;
   RETURN NEW;
 END IF;
 -- Enforce server-generated codes: offline clients cannot spoof code identity.
 PERFORM pg_advisory_xact_lock(hashtext('field-work:customer-codes'));
 prefix:=public.field_customer_code_root(NEW.name,NEW.province);
 FOR ix IN 1..1295 LOOP
  candidate:=prefix||
   substr('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ',(ix/36)+1,1)||
   substr('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ',mod(ix,36)+1,1);
  IF NOT EXISTS(SELECT 1 FROM public.customers WHERE field_code=candidate)
    THEN NEW.field_code:=candidate; RETURN NEW; END IF;
 END LOOP;
 RAISE EXCEPTION 'field_customer_code_exhausted';
END $trg$;
DROP TRIGGER IF EXISTS field_customer_code_trg ON public.customers;
CREATE TRIGGER field_customer_code_trg BEFORE INSERT OR UPDATE OF field_code,name,province
 ON public.customers FOR EACH ROW EXECUTE FUNCTION public.field_customer_code_assign();
-- Backfill only NULL codes; stable order and no business-record mutation otherwise.
DO $backfill$
DECLARE item record;
BEGIN
 FOR item IN SELECT id FROM public.customers WHERE field_code IS NULL ORDER BY created_at,id LOOP
  UPDATE public.customers SET field_code=NULL WHERE id=item.id;
 END LOOP;
END $backfill$;
CREATE UNIQUE INDEX IF NOT EXISTS customers_field_code_unique
 ON public.customers(field_code);
ALTER TABLE public.customers ALTER COLUMN field_code SET NOT NULL;
DO $constraint$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint
  WHERE conrelid='public.customers'::regclass AND conname='customers_field_code_format') THEN
  ALTER TABLE public.customers ADD CONSTRAINT customers_field_code_format
   CHECK(field_code ~ '^[A-Z0-9]{6}$');
 END IF;
END $constraint$;
REVOKE ALL ON FUNCTION public.field_customer_code_assign() FROM PUBLIC;
CREATE OR REPLACE FUNCTION public.field_order_apply(
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
  IF old.owner_sub<>owner_id THEN RAISE EXCEPTION 'order_forbidden';END IF;
  IF action<>'save' AND old.customer_id<>cid THEN RAISE EXCEPTION 'order_forbidden';END IF;
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
   UPDATE public.field_orders SET note=memo,customer_id=cid,updated_by=a,version=version+1,updated_at=now()
    WHERE id=order_key RETURNING * INTO saved;
   DELETE FROM public.field_order_lines WHERE field_order_lines.order_id=order_key;
  END IF;
  INSERT INTO public.field_order_lines(order_id,line_id,product_id,quantity,unit,line_position)
  SELECT order_key,(x.entry->>'line_id')::uuid,(x.entry->>'product_id')::uuid,
   (x.entry->>'quantity')::bigint,x.entry->>'unit',x.ordinality::integer
  FROM jsonb_array_elements(items) WITH ORDINALITY AS x(entry,ordinality);
 ELSIF action='export' THEN
  IF jsonb_array_length(items)<>0 THEN RAISE EXCEPTION 'order_invalid'; END IF;
  -- Field Work is a Sales request, NOT an inventory reservation / ERP.
  -- Validate live catalog identifiers and units only. Stock is advisory in
  -- the separate Tra tồn module and must not block recording/exporting an order.
  IF NOT EXISTS(SELECT 1 FROM public.field_order_lines WHERE order_id=order_key)
  THEN RAISE EXCEPTION 'order_invalid';END IF;
  IF EXISTS(
   SELECT 1 FROM public.field_order_lines l
    LEFT JOIN public.catalog_products p ON p.id=l.product_id
   WHERE l.order_id=order_key
    AND (p.id IS NULL OR NOT p.active OR p.unit IS NULL OR p.unit<>l.unit)
  ) THEN RAISE EXCEPTION 'order_invalid_unit';END IF;
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
COMMIT;
