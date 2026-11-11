-- 023: Customer/SKU assortment. Order evidence is DERIVED, never copied into
-- mutable flags: a cancelled/superseded order stops counting automatically.
-- Imported company documents remain evidence even when adjusted later.
BEGIN;
CREATE TABLE public.customer_products(
 customer_id uuid NOT NULL REFERENCES public.customers(id),
 product_id uuid NOT NULL REFERENCES public.catalog_products(id),
 verified boolean NOT NULL DEFAULT false,
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 verification_note text,
 verified_at timestamptz,
 verified_by text,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by text NOT NULL,
 PRIMARY KEY(customer_id,product_id),
 CONSTRAINT customer_products_note_length CHECK (
  verification_note IS NULL OR length(verification_note) BETWEEN 8 AND 500)
);
CREATE INDEX customer_products_product ON public.customer_products(product_id);
CREATE TABLE public.customer_product_ops(
 op_id uuid PRIMARY KEY,
 customer_id uuid NOT NULL REFERENCES public.customers(id),
 product_id uuid NOT NULL REFERENCES public.catalog_products(id),
 actor_sub text NOT NULL,
 request_data jsonb NOT NULL,
 before_data jsonb,
 after_data jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX customer_product_ops_customer ON public.customer_product_ops(customer_id,created_at DESC);

-- A single logical row per customer+SKU. Product is "Đã đặt" ONLY while an
-- exported order remains valid; no inferred sales or inventory posting.
CREATE VIEW public.customer_product_assortment AS
WITH evidence AS (
 SELECT o.customer_id,l.product_id,
  count(DISTINCT o.id) FILTER(WHERE o.status='exported')::integer AS ordered_orders,
  count(DISTINCT o.id) FILTER(WHERE o.status='imported')::integer AS imported_orders,
  max(o.exported_at) FILTER(WHERE o.status='exported') AS last_ordered_at,
  max(coalesce(o.imported_at,o.exported_at)) FILTER(WHERE o.status='imported') AS last_imported_at
 FROM public.field_orders o JOIN public.field_order_lines l ON l.order_id=o.id
 WHERE o.status IN ('exported','imported')
 GROUP BY o.customer_id,l.product_id
), item_keys AS (
 SELECT customer_id,product_id FROM public.customer_products WHERE verified
 UNION
 SELECT customer_id,product_id FROM evidence
)
SELECT keys.customer_id,keys.product_id,
 p.company_code,p.sku,p.name,p.brand,p.unit,p.category,
 coalesce(m.verified,false) AS is_trading,
 coalesce(e.imported_orders,0) AS imported_orders,
 coalesce(e.ordered_orders,0) AS ordered_orders,
 CASE WHEN coalesce(m.verified,false) THEN 'trading'
      WHEN coalesce(e.imported_orders,0)>0 THEN 'imported'
      ELSE 'ordered' END AS status,
 m.version AS manual_version,m.verification_note,m.verified_at,m.verified_by,
 e.last_ordered_at,e.last_imported_at,
 greatest(m.verified_at,e.last_ordered_at,e.last_imported_at) AS evidence_at
FROM item_keys keys
 JOIN public.catalog_products p ON p.id=keys.product_id
 LEFT JOIN public.customer_products m
  ON m.customer_id=keys.customer_id AND m.product_id=keys.product_id
 LEFT JOIN evidence e
  ON e.customer_id=keys.customer_id AND e.product_id=keys.product_id;

-- Only the SECURITY DEFINER entrypoint can mutate verified manual evidence.
-- A replayed UUID must match actor and payload; optimistic version protects
-- concurrent sales on the same shop/SKU, and every mutation is audited.
CREATE FUNCTION public.customer_product_apply(
 a text,op uuid,cid uuid,pid uuid,expected integer,mode text,reason text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path=pg_catalog,public AS $fn$
DECLARE
 role_name text;
 customer_owner text;
 previous public.customer_products%ROWTYPE;
 saved public.customer_products%ROWTYPE;
 previous_op public.customer_product_ops%ROWTYPE;
 request_json jsonb;
 outcome jsonb;
 clean_reason text;
BEGIN
 SELECT role INTO role_name FROM public.staff_members
 WHERE user_sub=a AND active;
 clean_reason:=btrim(reason);
 IF role_name IS NULL OR op IS NULL OR cid IS NULL OR pid IS NULL
  THEN RAISE EXCEPTION 'assortment_forbidden'; END IF;
 IF expected IS NULL OR expected<0 OR mode IS NULL OR mode NOT IN ('verify','unverify')
   OR clean_reason IS NULL OR length(clean_reason) NOT BETWEEN 8 AND 500
   THEN RAISE EXCEPTION 'assortment_invalid'; END IF;
 SELECT c.owner_sub INTO customer_owner
 FROM public.customers c JOIN public.staff_members owner
 ON owner.user_sub=c.owner_sub AND owner.active
 WHERE c.id=cid AND c.status<>'inactive'
 AND public.sales_can_access(a,c.owner_sub,c.province,c.district)
 AND public.sales_can_access(c.owner_sub,c.owner_sub,c.province,c.district);
 IF NOT FOUND THEN RAISE EXCEPTION 'assortment_forbidden'; END IF;
 IF role_name='sales' AND customer_owner<>a THEN
  RAISE EXCEPTION 'assortment_forbidden'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.catalog_products p WHERE p.id=pid AND p.active)
  THEN RAISE EXCEPTION 'assortment_product'; END IF;
 request_json:=jsonb_build_object('customer_id',cid,'product_id',pid,
  'expected_version',expected,'action',mode,'reason',clean_reason);
 PERFORM pg_advisory_xact_lock(hashtext('assortment:'||cid::text||':'||pid::text));
 SELECT * INTO previous_op FROM public.customer_product_ops WHERE op_id=op;
 IF FOUND THEN
  IF previous_op.actor_sub<>a OR previous_op.request_data<>request_json
  THEN RAISE EXCEPTION 'assortment_conflict'; END IF;
  RETURN previous_op.after_data;
 END IF;
 SELECT * INTO previous FROM public.customer_products
 WHERE customer_id=cid AND product_id=pid FOR UPDATE;
 IF NOT FOUND THEN
  IF expected<>0 OR mode<>'verify' THEN RAISE EXCEPTION 'assortment_stale'; END IF;
  INSERT INTO public.customer_products(
   customer_id,product_id,verified,version,verification_note,
   verified_at,verified_by,updated_by
  ) VALUES(cid,pid,true,1,clean_reason,now(),a,a)
  RETURNING * INTO saved;
 ELSE
  IF previous.version<>expected THEN RAISE EXCEPTION 'assortment_stale'; END IF;
  UPDATE public.customer_products
  SET verified=(mode='verify'),version=version+1,
   verification_note=clean_reason,
   verified_at=CASE WHEN mode='verify' THEN now() ELSE NULL END,
   verified_by=CASE WHEN mode='verify' THEN a ELSE NULL END,
   updated_at=now(),updated_by=a
  WHERE customer_id=cid AND product_id=pid RETURNING * INTO saved;
 END IF;
 outcome:=jsonb_build_object('item',to_jsonb(saved));
 INSERT INTO public.customer_product_ops(
  op_id,customer_id,product_id,actor_sub,request_data,before_data,after_data
 ) VALUES(op,cid,pid,a,request_json,
  CASE WHEN previous.customer_id IS NULL THEN NULL ELSE to_jsonb(previous) END,
  outcome);
 RETURN outcome;
END $fn$;
REVOKE ALL ON FUNCTION public.customer_product_apply(text,uuid,uuid,uuid,integer,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.customer_product_apply(text,uuid,uuid,uuid,integer,text,text) TO sales_api;
REVOKE ALL ON public.customer_products,public.customer_product_ops FROM sales_api;
GRANT SELECT ON public.customer_products,public.customer_product_ops TO sales_api;
GRANT SELECT ON public.customer_product_assortment TO sales_api;
COMMIT;
