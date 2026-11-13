import {neon} from '@neondatabase/serverless';
import type {userFromRequest} from './auth';
import {publishNotification} from './notifications';
type User=Awaited<ReturnType<typeof userFromRequest>>;
const json=(v:unknown,status=200)=>new Response(JSON.stringify(v),{
 status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const bad=(error:string,status=400)=>json({error},status);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const territory=(s:string)=>s.length<=240&&s.includes('|')&&s.indexOf('|')===s.lastIndexOf('|')&&s.indexOf('|')>0;
export async function targetRoutes(req:Request,env:{
 DATABASE_URL:string;VAPID_PUBLIC_KEY?:string;VAPID_PRIVATE_JWK?:string;VAPID_SUBJECT?:string
},u:User,url:URL):Promise<Response|null>{
 if(!['/api/v1/targets','/api/v1/targets/options'].includes(url.pathname))return null;
 const sql=neon(env.DATABASE_URL);
 const owner=url.searchParams.get('owner')??'';
 if(req.method==='GET'){
  const staff=await sql`SELECT user_sub,full_name,employee_code
   FROM staff_members WHERE active AND public.sales_staff_action_allowed(
    ${u.sub},user_sub,'target') ORDER BY full_name,user_sub`;
  const chosen=owner||staff.find(s=>s.user_sub===u.sub)?.user_sub||staff[0]?.user_sub||'';
  if(chosen&&!staff.some(s=>s.user_sub===chosen))return bad('Không có quyền nhân viên',403);
  if(url.pathname.endsWith('/options')){
   if(!chosen)return json({items:[]});
   const dimension=url.searchParams.get('dimension')??'';
   const q=(url.searchParams.get('q')??'').trim().slice(0,120);
   if(dimension==='territory'){
    const items=await sql`WITH allowed AS(
     SELECT sc.province,sc.district FROM public.staff_scopes sc
     JOIN public.staff_members s ON s.user_sub=sc.user_sub
     WHERE sc.user_sub=${chosen} AND s.role<>'admin'
      AND NOT EXISTS(SELECT 1 FROM public.staff_scopes full
        WHERE full.user_sub=sc.user_sub AND full.province=sc.province
          AND full.district='' AND sc.district<>'')
     UNION ALL
     SELECT tc.name,'' FROM public.territory_catalog tc
      WHERE tc.level='province' AND tc.active
       AND EXISTS(SELECT 1 FROM public.staff_members s
        WHERE s.user_sub=${chosen} AND s.role='admin')
    ) SELECT DISTINCT province||'|'||district AS id,
      CASE WHEN district='' THEN province||' · toàn tỉnh'
       ELSE province||' · '||district END AS name,
      CASE WHEN district='' THEN 'Toàn tỉnh' ELSE district END AS code
     FROM allowed WHERE province ILIKE '%'||${q}||'%' OR district ILIKE '%'||${q}||'%'
     ORDER BY name LIMIT 100`;
    return json({items});
   }
   if(dimension==='chain'){
    const items=await sql`SELECT c.id::text AS id,c.name,c.id::text AS code
     FROM public.customer_chains c
     WHERE (EXISTS(SELECT 1 FROM public.staff_members s
       WHERE s.user_sub=${chosen} AND s.role='admin')
      OR EXISTS(SELECT 1 FROM public.staff_business_assignments a
       WHERE a.user_sub=${chosen} AND a.active
       AND a.scope_kind='chain' AND a.scope_key=c.id::text))
      AND c.name ILIKE '%'||${q}||'%'
     ORDER BY c.name,c.id LIMIT 100`;
    return json({items});
   }
   return bad('Chỉ phân bổ theo địa bàn hoặc chuỗi');
  }
  const year=Number(url.searchParams.get('year'));
  if(!Number.isInteger(year)||year<2000||year>2100)return bad('Năm không hợp lệ');
  const items=chosen?await sql`SELECT t.owner_sub,extract(month from t.month)::int AS month,
    t.dimension,t.entity_id,t.amount::text AS amount,t.version,
    CASE t.dimension
     WHEN 'employee' THEN s.full_name
     WHEN 'territory' THEN
      CASE WHEN split_part(t.entity_id,'|',2)='' THEN split_part(t.entity_id,'|',1)||' · toàn tỉnh'
      ELSE split_part(t.entity_id,'|',1)||' · '||split_part(t.entity_id,'|',2) END
     WHEN 'chain' THEN ch.name
     WHEN 'customer' THEN c.name
     ELSE p.name END AS name,
    CASE t.dimension WHEN 'employee' THEN s.employee_code
     WHEN 'territory' THEN split_part(t.entity_id,'|',2)
     WHEN 'chain' THEN ch.id::text
     WHEN 'customer' THEN c.code ELSE p.company_code END AS code
    FROM public.sales_targets t
    JOIN public.staff_members s ON s.user_sub=t.owner_sub
    LEFT JOIN public.customers c ON t.dimension='customer' AND c.id::text=t.entity_id
    LEFT JOIN public.catalog_products p ON t.dimension='product' AND p.id::text=t.entity_id
    LEFT JOIN public.customer_chains ch ON t.dimension='chain' AND ch.id::text=t.entity_id
    WHERE t.owner_sub=${chosen}
     AND t.month>=make_date(${year},1,1) AND t.month<make_date(${year+1},1,1)
     AND (t.dimension<>'customer' OR (c.owner_sub=t.owner_sub AND
      public.sales_customer_allowed(${u.sub},c.id,'target')))
    ORDER BY t.dimension,t.entity_id,t.month`:[];
  const allocations=chosen?await sql`SELECT extract(month from month)::int AS month,
   dimension,sum(amount)::text AS amount
   FROM public.sales_targets WHERE owner_sub=${chosen}
    AND month>=make_date(${year},1,1) AND month<make_date(${year+1},1,1)
    AND dimension IN ('territory','chain') GROUP BY 1,2`:[];
  const actuals=chosen?await sql`SELECT extract(month from a.sale_date)::int AS month,
    sum(a.amount)::text AS amount,count(*)::int AS records
    FROM public.sales_actuals a
    JOIN public.customers c ON c.id=a.customer_id AND c.owner_sub=a.owner_sub
    WHERE a.owner_sub=${chosen} AND a.status='active'
    AND a.sale_date>=make_date(${year},1,1) AND a.sale_date<make_date(${year+1},1,1)
    AND public.sales_customer_allowed(${u.sub},c.id,'actuals')
    GROUP BY 1 ORDER BY 1`:[];
  const breakdown=chosen?await sql`WITH eligible AS (
     SELECT a.* FROM public.sales_actuals a
     JOIN public.customers c ON c.id=a.customer_id AND c.owner_sub=a.owner_sub
     WHERE a.owner_sub=${chosen} AND a.status='active'
      AND a.sale_date>=make_date(${year},1,1)
      AND a.sale_date<make_date(${year+1},1,1)
      AND public.sales_customer_allowed(${u.sub},c.id,'actuals')
    )
    SELECT extract(month from sale_date)::int AS month,'territory' AS dimension,
     territory_snapshot_key AS entity_id,sum(amount)::text AS amount,
     count(*)::int AS records,bool_or(scope_snapshot_source='backfill') AS has_backfill
    FROM eligible WHERE territory_snapshot_key IS NOT NULL GROUP BY 1,3
    UNION ALL
    SELECT extract(month from sale_date)::int AS month,'chain' AS dimension,
     chain_snapshot_key AS entity_id,sum(amount)::text AS amount,
     count(*)::int AS records,bool_or(scope_snapshot_source='backfill') AS has_backfill
    FROM eligible WHERE chain_snapshot_key IS NOT NULL GROUP BY 1,3`:[];
  return json({staff,owner:chosen,items,allocations,actuals,actual_breakdown:breakdown,
   actual_available:actuals.length>0,can_edit:u.admin||u.manager,
   legacy_dimensions:['product','customer']});
 }
 if(req.method!=='POST'||url.pathname.endsWith('/options'))return bad('Method not allowed',405);
 if(!u.admin&&!u.manager)return bad('Chỉ Admin/Manager được giao chỉ tiêu',403);
 let b:Record<string,unknown>;
 try{
  if(!req.headers.get('Content-Type')?.includes('application/json'))throw Error('Content type');
  const raw=await req.text();if(raw.length>16000)throw Error('size');
  const v=JSON.parse(raw) as unknown;
  if(!v||typeof v!=='object'||Array.isArray(v))throw Error('object');
  b=v as Record<string,unknown>;
 }catch{return bad('Dữ liệu không hợp lệ');}
 if(!uuid.test(String(b.client_ref??''))||typeof b.owner!=='string'||
  !Number.isInteger(b.year)||Number(b.year)<2000||Number(b.year)>2100||
  !['employee','territory','chain'].includes(String(b.dimension))||
  typeof b.entity_id!=='string'||
  (b.dimension==='employee'?b.entity_id!=='':b.dimension==='territory'?
    !territory(b.entity_id):!uuid.test(b.entity_id))||
  !Array.isArray(b.months)||b.months.length<1||b.months.length>12||
  b.months.some((raw)=>{
   if(!raw||typeof raw!=='object'||Array.isArray(raw))return true;
   const v=raw as Record<string,unknown>;
   return !Number.isInteger(v.month)||Number(v.month)<1||Number(v.month)>12||
    !Number.isSafeInteger(v.amount)||Number(v.amount)<0||Number(v.amount)>1e12||
    !Number.isInteger(v.version)||Number(v.version)<0||Number(v.version)>2147483646;
  })||new Set(b.months.map((row)=>(row as Record<string,unknown>).month)).size!==b.months.length)
  return bad('Chỉ tiêu hoặc phiên bản không hợp lệ');
 try{
  const saved=await sql`SELECT public.sales_target_apply(
   ${u.sub},${b.client_ref as string}::uuid,${b.owner as string},
   ${b.year as number},${b.dimension as string},${b.entity_id as string},
   ${JSON.stringify(b.months)}::jsonb) AS items`;
  if(b.owner!==u.sub){
   try{await publishNotification(env,b.owner as string,'target:'+b.client_ref,
    'Được giao chỉ tiêu','Có chỉ tiêu kinh doanh mới. Mở Field Work để xem.');}
   catch{/* A notification outage cannot reverse a committed target assignment. */}
  }
  return json({items:saved[0].items});
 }catch(e){
  const m=(e as Error).message??'';
  if(m.includes('target_forbidden'))return bad('Không có quyền giao chỉ tiêu hoặc chưa giao địa bàn/chuỗi',403);
  if(m.includes('target_overallocated'))return bad('Địa bàn và chuỗi cộng lại vượt Target nhân viên',409);
  if(m.includes('target_stale')||m.includes('target_conflict'))return bad('Chỉ tiêu đã thay đổi. Tải lại trước khi lưu.',409);
  if(m.includes('target_invalid'))return bad('Chỉ tiêu không hợp lệ');
  return bad('Không lưu được Target',503);
 }
}
