-- 060: Trip owner works with customers in assigned area or named scopes,
-- regardless of which employee originally created the customer.
-- Only VIEW is expanded; edit/media/report/export/actuals/target unchanged.
CREATE OR REPLACE FUNCTION public.sales_customer_allowed(p_actor text,p_customer uuid,p_action text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog','public'
AS $fbmn$
 SELECT EXISTS (
 SELECT 1 FROM public.staff_members a JOIN public.customers c ON c.id=p_customer
 WHERE a.user_sub=p_actor AND a.active AND public.sales_identity_exists(a.user_sub)
   AND (
     a.role='admin'
     OR (c.owner_sub=p_actor AND p_action IN ('view','create','edit','media','report','export','actuals','target'))
     OR (p_action='view' AND (
       public.sales_auto_customer_view(p_actor,c.id)
       OR public.sales_customer_plannable(p_actor,c.id)))
     OR EXISTS (
       SELECT 1 FROM public.scope_grants g
       WHERE g.grantee_sub=a.user_sub AND g.active AND g.action=p_action
         AND (
           (g.scope_kind='customer' AND g.scope_key=c.id::text)
           OR (g.scope_kind IN ('territory','team','chain','staff') AND EXISTS(
             SELECT 1 FROM public.customer_scope_bindings b
             WHERE b.customer_id=c.id AND b.active AND b.scope_kind=g.scope_kind AND b.scope_key=g.scope_key
               AND (b.scope_kind<>'territory' OR b.scope_key IN (c.province||'|',c.province||'|'||c.district))
           ))
           OR (g.scope_kind='staff' AND public.sales_staff_in_subtree(g.scope_key,c.owner_sub))
         )
     )
   )
 );
$fbmn$;
-- Retain every historical version. Publish immutable global v4, removing
-- two inherited seeded questions from the owner's three custom questions.
INSERT INTO public.field_survey_templates(id,province,version,questions,created_by)
SELECT gen_random_uuid(),'*',4,
  (SELECT jsonb_agg(q.value ORDER BY q.ordinality) FROM
    jsonb_array_elements(t.questions) WITH ORDINALITY q(value,ordinality)
    WHERE q.value->>'id' IN ('common_contact','common_visit_purpose','common_follow_up')),
  'system:remove-inherited-questions'
FROM public.field_survey_templates t
WHERE t.province='*' AND t.version=3
 AND (SELECT max(version) FROM public.field_survey_templates WHERE province='*')=3
 AND jsonb_array_length(t.questions)=5
 AND (SELECT count(*) FROM jsonb_array_elements(t.questions) q
  WHERE q->>'id' IN ('common_contact','common_visit_purpose','common_follow_up'))=3
 AND EXISTS(SELECT 1 FROM jsonb_array_elements(t.questions) q
  WHERE q->>'id'='common_contact' AND q->>'label'='Nhãn Hàng Kinh Doanh')
 AND EXISTS(SELECT 1 FROM jsonb_array_elements(t.questions) q
  WHERE q->>'id'='common_follow_up' AND q->>'label'='Đánh Giá')
ON CONFLICT(province,version) DO NOTHING;
