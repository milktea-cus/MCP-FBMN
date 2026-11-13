-- P0-M: territory/chain allocations replace new SKU allocations, while preserving legacy rows.
ALTER TABLE public.sales_targets DROP CONSTRAINT IF EXISTS sales_targets_dimension_check;
ALTER TABLE public.sales_targets ADD CONSTRAINT sales_targets_dimension_check
 CHECK(dimension IN ('employee','territory','chain','customer','product'));

-- Record sales geography at write time: customer transfers must not rewrite history.
ALTER TABLE public.sales_actuals
 ADD COLUMN IF NOT EXISTS territory_snapshot_key text,
 ADD COLUMN IF NOT EXISTS territory_snapshot_province text,
 ADD COLUMN IF NOT EXISTS territory_snapshot_district text,
 ADD COLUMN IF NOT EXISTS chain_snapshot_key text,
 ADD COLUMN IF NOT EXISTS scope_snapshot_source text
 CHECK(scope_snapshot_source IN ('captured','backfill'));

CREATE OR REPLACE FUNCTION public.sales_actual_capture_scope()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $fbmn$
DECLARE province_name text; district_name text; assigned_chain text;
BEGIN
 IF TG_OP='INSERT' OR NEW.customer_id IS DISTINCT FROM OLD.customer_id THEN
  SELECT c.province,c.district INTO province_name,district_name
   FROM public.customers c WHERE c.id=NEW.customer_id;
  NEW.territory_snapshot_province:=province_name;
  NEW.territory_snapshot_district:=district_name;
  NEW.territory_snapshot_key:=CASE WHEN province_name IS NOT NULL
   THEN province_name||'|'||coalesce(district_name,'') ELSE NULL END;
  SELECT CASE WHEN count(*)=1 THEN min(b.scope_key) ELSE NULL END INTO assigned_chain
   FROM public.customer_scope_bindings b
   WHERE b.customer_id=NEW.customer_id AND b.scope_kind='chain' AND b.active;
  NEW.chain_snapshot_key:=assigned_chain;
  NEW.scope_snapshot_source:='captured';
 END IF;
 RETURN NEW;
END $fbmn$;
DROP TRIGGER IF EXISTS sales_actual_capture_scope_trigger ON public.sales_actuals;
CREATE TRIGGER sales_actual_capture_scope_trigger
 BEFORE INSERT OR UPDATE OF customer_id ON public.sales_actuals
 FOR EACH ROW EXECUTE FUNCTION public.sales_actual_capture_scope();

-- Existing rows keep amounts and ownership unchanged; historical geography is best-effort backfill.
UPDATE public.sales_actuals a SET
 territory_snapshot_province=c.province,territory_snapshot_district=c.district,
 territory_snapshot_key=c.province||'|'||c.district,
 scope_snapshot_source='backfill'
 FROM public.customers c
 WHERE a.customer_id=c.id AND a.territory_snapshot_key IS NULL;

CREATE OR REPLACE FUNCTION public.sales_target_apply(
 a text,b uuid,o text,yr integer,d text,e text,rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE rec record;old public.sales_targets%ROWTYPE;saved public.sales_targets%ROWTYPE;
 prior public.sales_target_mutations%ROWTYPE;req jsonb;before_rows jsonb:='[]'::jsonb;
 after_rows jsonb:='[]'::jsonb;allocated numeric;parent_amount bigint;m date;
 province_name text;district_name text;
BEGIN
 IF b IS NULL OR NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=a AND active AND role IN ('admin','manager'))
 OR NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=o AND active)
 OR NOT public.sales_staff_action_allowed(a,o,'target')
 THEN RAISE EXCEPTION 'target_forbidden'; END IF;
 IF yr NOT BETWEEN 2000 AND 2100 OR d NOT IN ('employee','territory','chain') OR e IS NULL
 OR (d='employee' AND e<>'') OR (d<>'employee' AND e='')
 OR rows IS NULL OR jsonb_typeof(rows)<>'array' OR jsonb_array_length(rows) NOT BETWEEN 1 AND 12
 THEN RAISE EXCEPTION 'target_invalid'; END IF;
 IF d='territory' THEN
  province_name:=split_part(e,'|',1);district_name:=split_part(e,'|',2);
  IF position('|' IN e)<2 OR e<>province_name||'|'||district_name
    OR length(province_name)>100 OR length(district_name)>100
    OR NOT EXISTS(SELECT 1 FROM public.staff_members s WHERE s.user_sub=o AND (
      (s.role='admin' AND EXISTS(SELECT 1 FROM public.territory_catalog t
        WHERE t.level='province' AND t.active AND t.name=province_name))
      OR EXISTS(SELECT 1 FROM public.staff_scopes sc
       WHERE sc.user_sub=o AND sc.province=province_name AND
       (sc.district='' OR sc.district=district_name) AND
       (district_name<>'' OR sc.district=''))))
  THEN RAISE EXCEPTION 'target_forbidden'; END IF;
 END IF;
 IF d='chain' AND NOT EXISTS(
  SELECT 1 FROM public.customer_chains ch
   JOIN public.staff_members s ON s.user_sub=o WHERE ch.id::text=e AND
   (s.role='admin' OR EXISTS(SELECT 1 FROM public.staff_business_assignments ba
    WHERE ba.user_sub=o AND ba.active AND ba.scope_kind='chain' AND ba.scope_key=e)))
 THEN RAISE EXCEPTION 'target_forbidden'; END IF;
 PERFORM pg_advisory_xact_lock(hashtext('sales_target:'||o||':'||yr));
 req:=jsonb_build_object('owner',o,'year',yr,'dimension',d,'entity',e,'months',rows);
 SELECT * INTO prior FROM public.sales_target_mutations WHERE id=b;
 IF FOUND THEN
  IF prior.actor_sub<>a OR prior.request<>req THEN RAISE EXCEPTION 'target_conflict'; END IF;
  RETURN prior.after_data;
 END IF;
 IF (SELECT count(DISTINCT x.month)
 FROM jsonb_to_recordset(rows) AS x(month integer,amount bigint,version integer))<>jsonb_array_length(rows)
 THEN RAISE EXCEPTION 'target_invalid'; END IF;
 FOR rec IN SELECT * FROM jsonb_to_recordset(rows)
  AS x(month integer,amount bigint,version integer) ORDER BY month LOOP
  IF rec.month IS NULL OR rec.month NOT BETWEEN 1 AND 12 OR
   rec.amount IS NULL OR rec.amount NOT BETWEEN 0 AND 1000000000000 OR
   rec.version IS NULL OR rec.version<0 THEN RAISE EXCEPTION 'target_invalid'; END IF;
  m:=make_date(yr,rec.month,1);
  SELECT * INTO old FROM public.sales_targets
   WHERE owner_sub=o AND month=m AND dimension=d AND entity_id=e FOR UPDATE;
  IF coalesce(old.version,0)<>rec.version THEN RAISE EXCEPTION 'target_stale'; END IF;
  before_rows:=before_rows||jsonb_build_array(to_jsonb(old));
  INSERT INTO public.sales_targets(owner_sub,month,dimension,entity_id,amount)
   VALUES(o,m,d,e,rec.amount)
  ON CONFLICT(owner_sub,month,dimension,entity_id)
   DO UPDATE SET amount=excluded.amount,version=sales_targets.version+1,updated_at=now()
  RETURNING * INTO saved;
  after_rows:=after_rows||jsonb_build_array(to_jsonb(saved));
  SELECT coalesce(max(amount) FILTER(WHERE dimension='employee'),0)
   INTO parent_amount FROM public.sales_targets WHERE owner_sub=o AND month=m;
  SELECT coalesce(sum(amount),0) INTO allocated FROM public.sales_targets
   WHERE owner_sub=o AND month=m AND dimension IN('territory','chain');
  IF allocated>parent_amount THEN RAISE EXCEPTION 'target_overallocated'; END IF;
 END LOOP;
 INSERT INTO public.sales_target_mutations(id,actor_sub,owner_sub,request,before_data,after_data)
 VALUES(b,a,o,req,before_rows,after_rows);
 RETURN after_rows;
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_target_apply(text,uuid,text,integer,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_target_apply(text,uuid,text,integer,text,text,jsonb) TO sales_api;
-- Historical SKU/customer targets are preserved and remain SELECT-only.
