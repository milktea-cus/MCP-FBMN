-- 022: P0-C lifecycle; additive, never delete or rewrite imported company records.
BEGIN;
ALTER TABLE public.field_orders DROP CONSTRAINT IF EXISTS field_orders_status_check;
ALTER TABLE public.field_orders ADD CONSTRAINT field_orders_status_check
 CHECK (status IN ('draft','exported','imported','cancelled','superseded'));
ALTER TABLE public.field_orders
 ADD COLUMN IF NOT EXISTS cancel_reason text,
 ADD COLUMN IF NOT EXISTS cancelled_at timestamptz,
 ADD COLUMN IF NOT EXISTS replaces_order_id uuid REFERENCES public.field_orders(id),
 ADD COLUMN IF NOT EXISTS replacement_reason text,
 ADD COLUMN IF NOT EXISTS superseded_at timestamptz;
ALTER TABLE public.field_orders
 ADD CONSTRAINT field_orders_cancel_reason_check CHECK (cancel_reason IS NULL OR length(cancel_reason) BETWEEN 8 AND 300),
 ADD CONSTRAINT field_orders_replacement_reason_check CHECK (replacement_reason IS NULL OR length(replacement_reason) BETWEEN 8 AND 300),
 ADD CONSTRAINT field_orders_not_self_replacing CHECK (replaces_order_id IS NULL OR replaces_order_id<>id);
CREATE UNIQUE INDEX field_orders_single_replacement
 ON public.field_orders(replaces_order_id) WHERE replaces_order_id IS NOT NULL;
CREATE INDEX field_orders_status_created ON public.field_orders(status,created_at DESC);

-- Even the existing save/export SECURITY DEFINER function cannot export an
-- adjustment to an already-imported company document as a normal Sales user.
CREATE FUNCTION public.field_order_adjustment_export_guard() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $guard$
BEGIN
 IF NEW.status='exported' AND OLD.status='draft' AND NEW.replaces_order_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM public.field_orders source
                WHERE source.id=NEW.replaces_order_id AND source.status='imported')
    AND NOT EXISTS (SELECT 1 FROM public.staff_members s
      WHERE s.user_sub=NEW.updated_by AND s.active AND s.role='admin') THEN
  RAISE EXCEPTION 'order_forbidden';
 END IF;
 RETURN NEW;
END $guard$;
CREATE TRIGGER field_order_guard_import_adjustment
 BEFORE UPDATE OF status ON public.field_orders
 FOR EACH ROW EXECUTE FUNCTION public.field_order_adjustment_export_guard();
REVOKE ALL ON FUNCTION public.field_order_adjustment_export_guard() FROM PUBLIC;

-- Atomic operation: client_ref is globally idempotent, scoped to actor +
-- exact payload. One source-order lock also serializes field_order_apply.
CREATE FUNCTION public.field_order_lifecycle(
 a text,op uuid,order_key uuid,expected integer,mode text,
 reason text,replacement_key uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path=pg_catalog,public AS $fn$
DECLARE
 actor_role text;
 old public.field_orders%ROWTYPE;
 saved public.field_orders%ROWTYPE;
 child public.field_orders%ROWTYPE;
 prior public.field_order_ops%ROWTYPE;
 request_json jsonb;
 result_json jsonb;
 clean_reason text;
BEGIN
 SELECT role INTO actor_role FROM public.staff_members
  WHERE user_sub=a AND active;
 clean_reason:=btrim(reason);
 IF actor_role IS NULL OR op IS NULL OR order_key IS NULL
  THEN RAISE EXCEPTION 'order_forbidden'; END IF;
 IF expected IS NULL OR expected<1 OR mode IS NULL OR mode NOT IN ('cancel','replace')
   OR clean_reason IS NULL OR length(clean_reason) NOT BETWEEN 8 AND 300
   OR (mode='cancel' AND replacement_key IS NOT NULL)
   OR (mode='replace' AND (replacement_key IS NULL OR replacement_key=order_key))
   THEN RAISE EXCEPTION 'order_invalid'; END IF;
 request_json:=jsonb_build_object('action',mode,'order_id',order_key,
   'expected_version',expected,'reason',clean_reason,'replacement_id',replacement_key);
 PERFORM pg_advisory_xact_lock(hashtext('field_order:'||order_key::text));
 SELECT * INTO prior FROM public.field_order_ops WHERE op_id=op;
 IF FOUND THEN
  IF prior.actor_sub<>a OR prior.request_data<>request_json
    THEN RAISE EXCEPTION 'order_conflict'; END IF;
  RETURN prior.after_data;
 END IF;
 SELECT * INTO old FROM public.field_orders WHERE id=order_key FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'order_missing'; END IF;
 IF NOT EXISTS (
  SELECT 1 FROM public.customers c
   JOIN public.staff_members owner ON owner.user_sub=c.owner_sub AND owner.active
  WHERE c.id=old.customer_id AND c.owner_sub=old.owner_sub
   AND public.sales_can_access(a,old.owner_sub,c.province,c.district)
   AND public.sales_can_access(old.owner_sub,old.owner_sub,c.province,c.district)
 ) THEN RAISE EXCEPTION 'order_forbidden'; END IF;
 IF actor_role='sales' AND old.owner_sub<>a THEN
  RAISE EXCEPTION 'order_forbidden'; END IF;
 IF old.version<>expected THEN RAISE EXCEPTION 'order_stale'; END IF;
 IF mode='cancel' THEN
  IF NOT (old.status='draft' OR
    (old.status='exported' AND actor_role='admin')) THEN
   RAISE EXCEPTION 'order_state'; END IF;
  UPDATE public.field_orders SET
   status='cancelled',cancel_reason=clean_reason,cancelled_at=now(),
   version=version+1,updated_by=a,updated_at=now()
  WHERE id=order_key RETURNING * INTO saved;
  result_json:=jsonb_build_object('item',to_jsonb(saved));
 ELSE
  -- Changing an exported/imported document is compensating, not mutation.
  IF actor_role<>'admin' OR old.status NOT IN ('exported','imported')
    THEN RAISE EXCEPTION 'order_state'; END IF;
  IF EXISTS(SELECT 1 FROM public.field_orders
     WHERE id=replacement_key OR replaces_order_id=order_key)
    THEN RAISE EXCEPTION 'order_conflict'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.field_order_lines WHERE order_id=order_key)
    THEN RAISE EXCEPTION 'order_invalid'; END IF;
  INSERT INTO public.field_orders(
   id,owner_sub,customer_id,note,created_by,updated_by,
   replaces_order_id,replacement_reason
  ) VALUES(
   replacement_key,old.owner_sub,old.customer_id,old.note,a,a,
   order_key,clean_reason
  ) RETURNING * INTO child;
  INSERT INTO public.field_order_lines(
   order_id,line_id,product_id,quantity,unit,line_position
  )
  SELECT replacement_key,gen_random_uuid(),product_id,quantity,unit,line_position
  FROM public.field_order_lines WHERE order_id=order_key
  ORDER BY line_position;
  -- Imported is immutable in status and company reference. Admin must
  -- reconcile the adjustment with the external company document separately.
  UPDATE public.field_orders SET
   status=CASE WHEN status='exported' THEN 'superseded' ELSE status END,
   superseded_at=CASE WHEN status='exported' THEN now() ELSE superseded_at END,
   version=version+1,updated_by=a,updated_at=now()
  WHERE id=order_key RETURNING * INTO saved;
  result_json:=jsonb_build_object('item',to_jsonb(saved),
    'replacement',to_jsonb(child));
  INSERT INTO public.field_order_ops(
   op_id,order_id,actor_sub,request_data,before_data,after_data
  ) VALUES(
   gen_random_uuid(),replacement_key,a,
   jsonb_build_object('action','replacement_created','source_order',order_key,
    'reason',clean_reason,'request_op',op),NULL,to_jsonb(child)
  );
 END IF;
 INSERT INTO public.field_order_ops(
  op_id,order_id,actor_sub,request_data,before_data,after_data
 ) VALUES(op,order_key,a,request_json,to_jsonb(old),result_json);
 RETURN result_json;
END $fn$;
REVOKE ALL ON FUNCTION public.field_order_lifecycle(text,uuid,uuid,integer,text,text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.field_order_lifecycle(text,uuid,uuid,integer,text,text,uuid) TO sales_api;
COMMIT;
