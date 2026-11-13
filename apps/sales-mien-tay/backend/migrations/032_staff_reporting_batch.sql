-- 032_staff_reporting_batch.sql
-- Atomic edit: employee profile + changed direct reports.
-- Only Admin; no implicit edit privilege from the reporting hierarchy.
CREATE OR REPLACE FUNCTION public.sales_save_staff_with_reports(
 p_actor text, p_subject text, p_code text, p_full_name text, p_phone text,
 p_role text, p_active boolean, p_manager text, p_scopes jsonb,
 p_revision bigint, p_title text, p_changes jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public'
AS $fbmn$
DECLARE
 result jsonb;
 change jsonb;
 target_sub text;
 should_assign boolean;
 expected_rev bigint;
 previous public.staff_members%ROWTYPE;
 next_manager text;
 changed_count integer := 0;
 seen text[] := ARRAY[]::text[];
BEGIN
 PERFORM pg_advisory_xact_lock(74162901);
 IF p_changes IS NULL OR jsonb_typeof(p_changes)<>'array' OR jsonb_array_length(p_changes)>200
 THEN RAISE EXCEPTION 'invalid report changes'; END IF;
 IF p_role<>'manager' AND EXISTS(SELECT 1 FROM public.staff_members WHERE manager_sub=p_subject)
 THEN RAISE EXCEPTION 'manager has reports'; END IF;
 IF p_role<>'manager' AND jsonb_array_length(p_changes)>0
 THEN RAISE EXCEPTION 'invalid reports for role'; END IF;
 -- The existing eleven-argument function verifies Admin, account, parent, title,
 -- stale profile revision, role constraints, last Admin and hierarchy cycles.
 -- Freeze and validate direct-report revisions BEFORE saving the manager.
 -- sales_save_staff invalidates ancestor scope_revision within this same transaction.
 FOR change IN SELECT value FROM jsonb_array_elements(p_changes) LOOP
   IF jsonb_typeof(change)<>'object'
      OR jsonb_typeof(change->'user_sub')<>'string'
      OR jsonb_typeof(change->'assigned')<>'boolean'
      OR jsonb_typeof(change->'scope_revision') NOT IN ('string','number')
      OR NOT (change->>'scope_revision') ~ '^[0-9]{1,18}
   IF jsonb_typeof(change)<>'object'
      OR jsonb_typeof(change->'user_sub')<>'string'
      OR jsonb_typeof(change->'assigned')<>'boolean'
      OR jsonb_typeof(change->'scope_revision') NOT IN ('string','number')
      OR NOT (change->>'scope_revision') ~ '^[0-9]{1,18}$'
   THEN RAISE EXCEPTION 'invalid report changes'; END IF;
   target_sub := change->>'user_sub';
   should_assign := (change->>'assigned')::boolean;
   expected_rev := (change->>'scope_revision')::bigint;
   IF target_sub=p_subject OR target_sub=ANY(seen)
   THEN RAISE EXCEPTION 'invalid duplicate or self report'; END IF;
   seen := array_append(seen,target_sub);
   SELECT * INTO previous FROM public.staff_members
     WHERE user_sub=target_sub FOR UPDATE;
   IF NOT FOUND OR previous.role='admin' OR NOT previous.active
   THEN RAISE EXCEPTION 'invalid report'; END IF;
   IF previous.scope_revision<>expected_rev
   THEN RAISE EXCEPTION 'stale report revision'; END IF;
   IF NOT should_assign AND previous.manager_sub IS DISTINCT FROM p_subject
   THEN RAISE EXCEPTION 'stale report parent'; END IF;
   next_manager := CASE WHEN should_assign THEN p_subject ELSE NULL END;
   IF previous.manager_sub IS DISTINCT FROM next_manager THEN
     IF should_assign AND public.sales_staff_in_subtree(target_sub,p_subject)
     THEN RAISE EXCEPTION 'invalid manager cycle'; END IF;
     UPDATE public.staff_members SET manager_sub=next_manager,
       scope_revision=scope_revision+1,updated_at=now()
       WHERE user_sub=target_sub;
     -- Offline leases of both old and new supervisor branches must be invalidated.
     WITH RECURSIVE ancestor(id,path) AS (
       SELECT root,ARRAY[root] FROM unnest(ARRAY[previous.manager_sub,next_manager]) root WHERE root IS NOT NULL
       UNION ALL
       SELECT m.manager_sub,a.path||m.manager_sub FROM ancestor a
       JOIN public.staff_members m ON m.user_sub=a.id
       WHERE m.manager_sub IS NOT NULL AND NOT m.manager_sub=ANY(a.path)
     )
     UPDATE public.staff_members SET scope_revision=scope_revision+1,updated_at=now()
     WHERE user_sub<>target_sub AND user_sub IN (SELECT id FROM ancestor);
     INSERT INTO public.staff_permission_events(actor_sub,target_sub,action,before_state,after_state)
       VALUES(p_actor,target_sub,'reassign_direct_report',
       jsonb_build_object('manager_sub',previous.manager_sub,'scope_revision',previous.scope_revision),
       jsonb_build_object('manager_sub',next_manager));
     changed_count := changed_count+1;
   END IF;
 END LOOP;
 RETURN jsonb_build_object('profile',result,'reports_changed',changed_count);
END
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_save_staff_with_reports(text,text,text,text,text,text,boolean,text,jsonb,bigint,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_staff_with_reports(text,text,text,text,text,text,boolean,text,jsonb,bigint,text,jsonb) TO sales_api;

   THEN RAISE EXCEPTION 'invalid report changes'; END IF;
   target_sub := change->>'user_sub';
   should_assign := (change->>'assigned')::boolean;
   expected_rev := (change->>'scope_revision')::bigint;
   IF target_sub=p_subject OR target_sub=ANY(seen)
   THEN RAISE EXCEPTION 'invalid duplicate or self report'; END IF;
   seen := array_append(seen,target_sub);
   SELECT * INTO previous FROM public.staff_members
     WHERE user_sub=target_sub FOR UPDATE;
   IF NOT FOUND OR previous.role='admin' OR NOT previous.active
   THEN RAISE EXCEPTION 'invalid report'; END IF;
   IF NOT should_assign AND previous.manager_sub IS DISTINCT FROM p_subject
   THEN RAISE EXCEPTION 'stale report parent'; END IF;
 END LOOP;
 result := public.sales_save_staff(p_actor,p_subject,p_code,p_full_name,p_phone,
                                   p_role,p_active,p_manager,p_scopes,p_revision,p_title);
 FOR change IN SELECT value FROM jsonb_array_elements(p_changes) LOOP
   IF jsonb_typeof(change)<>'object'
      OR jsonb_typeof(change->'user_sub')<>'string'
      OR jsonb_typeof(change->'assigned')<>'boolean'
      OR jsonb_typeof(change->'scope_revision') NOT IN ('string','number')
      OR NOT (change->>'scope_revision') ~ '^[0-9]{1,18}$'
   THEN RAISE EXCEPTION 'invalid report changes'; END IF;
   target_sub := change->>'user_sub';
   should_assign := (change->>'assigned')::boolean;
   expected_rev := (change->>'scope_revision')::bigint;
   SELECT * INTO previous FROM public.staff_members
     WHERE user_sub=target_sub FOR UPDATE;
   IF NOT FOUND OR previous.role='admin' OR NOT previous.active
   THEN RAISE EXCEPTION 'invalid report'; END IF;
   IF previous.scope_revision<>expected_rev
   THEN RAISE EXCEPTION 'stale report revision'; END IF;
   IF NOT should_assign AND previous.manager_sub IS DISTINCT FROM p_subject
   THEN RAISE EXCEPTION 'stale report parent'; END IF;
   next_manager := CASE WHEN should_assign THEN p_subject ELSE NULL END;
   IF previous.manager_sub IS DISTINCT FROM next_manager THEN
     IF should_assign AND public.sales_staff_in_subtree(target_sub,p_subject)
     THEN RAISE EXCEPTION 'invalid manager cycle'; END IF;
     UPDATE public.staff_members SET manager_sub=next_manager,
       scope_revision=scope_revision+1,updated_at=now()
       WHERE user_sub=target_sub;
     -- Offline leases of both old and new supervisor branches must be invalidated.
     WITH RECURSIVE ancestor(id,path) AS (
       SELECT root,ARRAY[root] FROM unnest(ARRAY[previous.manager_sub,next_manager]) root WHERE root IS NOT NULL
       UNION ALL
       SELECT m.manager_sub,a.path||m.manager_sub FROM ancestor a
       JOIN public.staff_members m ON m.user_sub=a.id
       WHERE m.manager_sub IS NOT NULL AND NOT m.manager_sub=ANY(a.path)
     )
     UPDATE public.staff_members SET scope_revision=scope_revision+1,updated_at=now()
     WHERE user_sub<>target_sub AND user_sub IN (SELECT id FROM ancestor);
     INSERT INTO public.staff_permission_events(actor_sub,target_sub,action,before_state,after_state)
       VALUES(p_actor,target_sub,'reassign_direct_report',
       jsonb_build_object('manager_sub',previous.manager_sub,'scope_revision',previous.scope_revision),
       jsonb_build_object('manager_sub',next_manager));
     changed_count := changed_count+1;
   END IF;
 END LOOP;
 RETURN jsonb_build_object('profile',result,'reports_changed',changed_count);
END
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_save_staff_with_reports(text,text,text,text,text,text,boolean,text,jsonb,bigint,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_staff_with_reports(text,text,text,text,text,text,boolean,text,jsonb,bigint,text,jsonb) TO sales_api;
