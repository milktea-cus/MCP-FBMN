BEGIN;
CREATE TABLE public.sales_targets (
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 month date NOT NULL CHECK (extract(day from month)=1),
 dimension text NOT NULL CHECK (dimension IN ('employee','customer','product')),
 entity_id text NOT NULL,
 amount bigint NOT NULL CHECK (amount BETWEEN 0 AND 1000000000000),
 version integer NOT NULL DEFAULT 1,
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(owner_sub,month,dimension,entity_id),
 CHECK ((dimension='employee' AND entity_id='') OR (dimension<>'employee' AND entity_id<>''))
);
CREATE TABLE public.sales_target_mutations (
 id uuid PRIMARY KEY, actor_sub text NOT NULL, owner_sub text NOT NULL,
 request jsonb NOT NULL, before_data jsonb NOT NULL, after_data jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sales_targets_month ON public.sales_targets(month,owner_sub);
CREATE FUNCTION public.sales_target_apply(a text,b uuid,o text,yr integer,d text,e text,rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
DECLARE rec record; old public.sales_targets%ROWTYPE; saved public.sales_targets%ROWTYPE;
 prior public.sales_target_mutations%ROWTYPE; req jsonb; before_rows jsonb:='[]'; after_rows jsonb:='[]'; total bigint; m date;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=a AND active AND role IN ('admin','manager'))
 OR NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=o AND active)
 OR NOT public.sales_can_access(a,o,NULL,NULL) THEN RAISE EXCEPTION 'target_forbidden'; END IF;
 IF yr NOT BETWEEN 2000 AND 2100 OR d NOT IN ('employee','customer','product') OR e IS NULL
 OR (d='employee' AND e<>'') OR (d<>'employee' AND e='') OR jsonb_typeof(rows)<>'array'
 OR jsonb_array_length(rows) NOT BETWEEN 1 AND 12 THEN RAISE EXCEPTION 'target_invalid'; END IF;
 IF d='customer' AND NOT EXISTS(SELECT 1 FROM public.customers c WHERE c.id::text=e AND c.owner_sub=o
 AND public.sales_can_access(a,o,c.province,c.district) AND public.sales_can_access(o,o,c.province,c.district)) THEN RAISE EXCEPTION 'target_forbidden'; END IF;
 IF d='product' AND NOT EXISTS(SELECT 1 FROM public.catalog_products WHERE id::text=e AND active) THEN RAISE EXCEPTION 'target_invalid'; END IF;
 PERFORM pg_advisory_xact_lock(hashtext('sales_target:'||o||':'||yr));
 req:=jsonb_build_object('owner',o,'year',yr,'dimension',d,'entity',e,'months',rows);
 SELECT * INTO prior FROM public.sales_target_mutations WHERE id=b;
 IF FOUND THEN
  IF prior.actor_sub<>a OR prior.request<>req THEN RAISE EXCEPTION 'target_conflict'; END IF;
  RETURN prior.after_data;
 END IF;
 IF (SELECT count(DISTINCT x.month) FROM jsonb_to_recordset(rows) AS x(month integer,amount bigint,version integer))<>jsonb_array_length(rows)
 THEN RAISE EXCEPTION 'target_invalid'; END IF;
 FOR rec IN SELECT * FROM jsonb_to_recordset(rows) AS x(month integer,amount bigint,version integer) ORDER BY month LOOP
  IF rec.month IS NULL OR rec.month NOT BETWEEN 1 AND 12 OR rec.amount IS NULL OR rec.amount NOT BETWEEN 0 AND 1000000000000
  OR rec.version IS NULL OR rec.version<0 THEN RAISE EXCEPTION 'target_invalid'; END IF;
  m:=make_date(yr,rec.month,1);
  SELECT * INTO old FROM public.sales_targets WHERE owner_sub=o AND month=m AND dimension=d AND entity_id=e;
  IF coalesce(old.version,0)<>rec.version THEN RAISE EXCEPTION 'target_stale'; END IF;
  before_rows:=before_rows||jsonb_build_array(to_jsonb(old));
  INSERT INTO public.sales_targets(owner_sub,month,dimension,entity_id,amount) VALUES(o,m,d,e,rec.amount)
  ON CONFLICT(owner_sub,month,dimension,entity_id) DO UPDATE SET amount=excluded.amount,version=sales_targets.version+1,updated_at=now()
  RETURNING * INTO saved;
  after_rows:=after_rows||jsonb_build_array(to_jsonb(saved));
  SELECT coalesce(max(amount) FILTER(WHERE dimension='employee'),0) INTO total FROM public.sales_targets WHERE owner_sub=o AND month=m;
  IF EXISTS(SELECT 1 FROM public.sales_targets WHERE owner_sub=o AND month=m AND dimension<>'employee' GROUP BY dimension HAVING sum(amount)>total)
  THEN RAISE EXCEPTION 'target_overallocated'; END IF;
 END LOOP;
 INSERT INTO public.sales_target_mutations(id,actor_sub,owner_sub,request,before_data,after_data) VALUES(b,a,o,req,before_rows,after_rows);
 RETURN after_rows;
END $fn$;
REVOKE ALL ON FUNCTION public.sales_target_apply(text,uuid,text,integer,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_target_apply(text,uuid,text,integer,text,text,jsonb) TO sales_api;
REVOKE ALL ON public.sales_targets,public.sales_target_mutations FROM sales_api;
GRANT SELECT ON public.sales_targets TO sales_api;
COMMIT;
