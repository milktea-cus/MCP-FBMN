-- 229 N2: complete actual Admin org/territory/chain/team/customer assignments.
-- Transactional audit triggers; same 15-min recipient group and generic payload.
CREATE OR REPLACE FUNCTION public.sales_n2_staff_audit()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog,public AS $n2$
DECLARE kind text; old_staff jsonb;new_staff jsonb; target_active boolean;
BEGIN
 IF NEW.actor_sub IS NULL OR NEW.target_sub IS NULL OR NEW.actor_sub=NEW.target_sub
  OR NEW.action NOT IN ('save','reassign_direct_report','assign_territories')
  THEN RETURN NEW; END IF;
 IF NEW.action='assign_territories' THEN
   -- sales_set_staff_territories emits this audit only when the canonical
   -- province/district set actually changes, not on repeated saves.
   IF coalesce(NEW.before_state,'[]'::jsonb)
       IS NOT DISTINCT FROM coalesce(NEW.after_state,'[]'::jsonb)
   THEN RETURN NEW; END IF;
   kind:='assignment';
 ELSIF NEW.action='reassign_direct_report' THEN
   IF NEW.before_state->>'manager_sub' IS NOT DISTINCT FROM NEW.after_state->>'manager_sub'
     THEN RETURN NEW; END IF;
   kind:='assignment';
 ELSE
   old_staff:=NEW.before_state->'staff';
   new_staff:=NEW.after_state->'staff';
   IF new_staff IS NULL THEN RETURN NEW; END IF;
   IF (old_staff->>'role') IS DISTINCT FROM (new_staff->>'role')
      OR (old_staff->>'active') IS DISTINCT FROM (new_staff->>'active') THEN
     kind:='security';
   ELSIF (old_staff->>'manager_sub') IS DISTINCT FROM (new_staff->>'manager_sub')
      OR coalesce(NEW.before_state->'scopes','[]'::jsonb)
         IS DISTINCT FROM coalesce(NEW.after_state->'scopes','[]'::jsonb) THEN
     kind:='assignment';
   ELSE RETURN NEW;
   END IF;
 END IF;
 SELECT s.active AND public.sales_identity_exists(s.user_sub) INTO target_active
  FROM public.staff_members s WHERE s.user_sub=NEW.target_sub;
 IF NOT coalesce(target_active,false) THEN RETURN NEW; END IF;
 PERFORM public.sales_notification_enqueue('staff:'||NEW.id::text,kind,
  'staff:'||NEW.target_sub,NEW.actor_sub,NEW.target_sub,
  'Quyền hoặc phân công đã thay đổi',
  'Mở Field Work để cập nhật phạm vi làm việc.',NEW.happened_at);
 RETURN NEW;
EXCEPTION WHEN OTHERS THEN
 RAISE WARNING 'N2 staff audit notification failed (SQLSTATE %)',SQLSTATE;
 RETURN NEW;
END $n2$;

CREATE OR REPLACE FUNCTION public.sales_n2_org_scope_audit()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog,public AS $n2$
DECLARE recipient text; category text:='assignment'; before_active text; after_active text;
BEGIN
 IF NEW.actor_sub IS NULL OR NEW.subject_kind NOT IN
  ('grant','business_assignment','team_member','customer_binding')
 THEN RETURN NEW; END IF;
 IF NEW.subject_kind='grant' THEN
   recipient:=NEW.after_state->>'grantee_sub';
   before_active:=NEW.before_state->>'active';
   after_active:=NEW.after_state->>'active';
   IF NOT EXISTS(SELECT 1 FROM public.scope_grants g
      WHERE g.id::text=NEW.subject_key AND g.grantee_sub=recipient
        AND g.active::text=after_active) THEN RETURN NEW; END IF;
   IF NEW.after_state->>'action' IN ('staff_manage','approve','transfer')
     THEN category:='security'; END IF;
 ELSIF NEW.subject_kind='business_assignment' THEN
   recipient:=NEW.after_state->>'user_sub';
   before_active:=NEW.before_state->>'active';
   after_active:=NEW.after_state->>'active';
   IF NOT EXISTS(SELECT 1 FROM public.staff_business_assignments b
      WHERE b.id::text=NEW.subject_key AND b.user_sub=recipient
        AND b.active::text=after_active) THEN RETURN NEW; END IF;
 ELSIF NEW.subject_kind='team_member' THEN
   recipient:=NEW.after_state->>'member';
   before_active:=CASE WHEN NEW.action='join' THEN 'false' ELSE 'true' END;
   after_active:=NEW.after_state->>'active';
   IF EXISTS(SELECT 1 FROM public.org_team_members t
       WHERE t.team_id::text=NEW.subject_key AND t.user_sub=recipient)
      IS DISTINCT FROM (after_active='true') THEN RETURN NEW; END IF;
 ELSE
   -- Binding a customer to a territory/team/chain has no single personal
   -- recipient; only the explicit staff binding may notify that staff.
   IF NEW.after_state->>'scope_kind'<>'staff' THEN RETURN NEW; END IF;
   recipient:=NEW.after_state->>'scope_key';
   before_active:=NEW.before_state->>'active';
   after_active:=NEW.after_state->>'active';
   IF NOT EXISTS(SELECT 1 FROM public.customer_scope_bindings b
      WHERE b.customer_id::text=NEW.subject_key AND b.scope_kind='staff'
        AND b.scope_key=recipient AND b.active::text=after_active) THEN RETURN NEW; END IF;
 END IF;
 IF recipient IS NULL OR recipient='' OR recipient=NEW.actor_sub
   OR after_active NOT IN ('true','false') THEN RETURN NEW; END IF;
 -- Replaying a grant/assignment with only assigned_by or updated_at changed
 -- is not a business transition. Creating an already-inactive row is also a no-op.
 IF (before_active IS NOT DISTINCT FROM after_active)
   OR (before_active IS NULL AND after_active='false') THEN RETURN NEW; END IF;
 PERFORM public.sales_notification_enqueue('org:'||NEW.id::text,category,
   'staff:'||recipient,NEW.actor_sub,recipient,
   'Phân công hoặc quyền đã thay đổi',
   'Mở Field Work để cập nhật thông tin công việc.',NEW.happened_at);
 RETURN NEW;
EXCEPTION WHEN OTHERS THEN
 RAISE WARNING 'N2 organization audit notification failed (SQLSTATE %)',SQLSTATE;
 RETURN NEW;
END $n2$;

DROP TRIGGER IF EXISTS trg_n2_org_notification ON public.scope_change_audit;
CREATE TRIGGER trg_n2_org_notification AFTER INSERT ON public.scope_change_audit
 FOR EACH ROW EXECUTE FUNCTION public.sales_n2_org_scope_audit();
REVOKE ALL ON FUNCTION public.sales_n2_org_scope_audit() FROM PUBLIC;
-- Keep producer_enabled OFF until integration and CI gates are green.
