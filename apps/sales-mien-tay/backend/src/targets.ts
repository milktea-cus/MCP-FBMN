import {neon} from '@neondatabase/serverless';
import type {userFromRequest} from './auth';
type User=Awaited<ReturnType<typeof userFromRequest>>;
const json=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const bad=(error:string,status=400)=>json({error},status);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export async function targetRoutes(req:Request,env:{DATABASE_URL:string},u:User,url:URL):Promise<Response|null>{
 if(!['/api/v1/targets','/api/v1/targets/options'].includes(url.pathname))return null;
 const sql=neon(env.DATABASE_URL);
 const owner=url.searchParams.get('owner')??'';
 if(req.method==='GET'){
  const staff=await sql`SELECT user_sub,full_name,employee_code FROM staff_members WHERE active AND public.sales_can_access(${u.sub},user_sub,NULL,NULL) ORDER BY full_name,user_sub`;
  const chosen=owner||staff.find(s=>s.user_sub===u.sub)?.user_sub||staff[0]?.user_sub||'';
  if(chosen&&!staff.some(s=>s.user_sub===chosen))return bad('Không có quyền nhân viên',403);
  if(url.pathname.endsWith('/options')){
   const d=url.searchParams.get('dimension'),q=(url.searchParams.get('q')??'').slice(0,120);
   if(!chosen)return json({items:[]});
   if(d==='customer')return json({items:await sql`SELECT id::text AS id,name,code FROM customers WHERE owner_sub=${chosen} AND public.sales_can_access(${u.sub},owner_sub,province,district) AND public.sales_can_access(owner_sub,owner_sub,province,district) AND (name ILIKE '%'||${q}||'%' OR code ILIKE '%'||${q}||'%') ORDER BY name,id LIMIT 100`});
   if(d==='product')return json({items:await sql`SELECT id::text AS id,name,company_code AS code FROM catalog_products WHERE active AND (name ILIKE '%'||${q}||'%' OR company_code ILIKE '%'||${q}||'%') ORDER BY company_code LIMIT 100`});
   return bad('Loại phân bổ không hợp lệ');
  }
  const year=Number(url.searchParams.get('year'));
  if(!Number.isInteger(year)||year<2000||year>2100)return bad('Năm không hợp lệ');
  const items=chosen?await sql`SELECT t.owner_sub,extract(month from t.month)::int AS month,t.dimension,t.entity_id,t.amount::text AS amount,t.version,
    CASE t.dimension WHEN 'employee' THEN s.full_name WHEN 'customer' THEN c.name ELSE p.name END AS name,
    CASE t.dimension WHEN 'customer' THEN c.code WHEN 'product' THEN p.company_code ELSE s.employee_code END AS code
    FROM sales_targets t JOIN staff_members s ON s.user_sub=t.owner_sub
    LEFT JOIN customers c ON t.dimension='customer' AND c.id::text=t.entity_id
    LEFT JOIN catalog_products p ON t.dimension='product' AND p.id::text=t.entity_id
    WHERE t.owner_sub=${chosen} AND t.month>=make_date(${year},1,1) AND t.month<make_date(${year+1},1,1)
    AND (t.dimension<>'customer' OR (c.owner_sub=t.owner_sub AND public.sales_can_access(${u.sub},c.owner_sub,c.province,c.district)))
    ORDER BY t.dimension,t.entity_id,t.month`:[];
  const allocations=chosen?await sql`SELECT extract(month from month)::int AS month,dimension,sum(amount)::text AS amount FROM sales_targets WHERE owner_sub=${chosen} AND month>=make_date(${year},1,1) AND month<make_date(${year+1},1,1) AND dimension<>'employee' GROUP BY 1,2`:[];
  return json({staff,owner:chosen,items,allocations,actual_available:false,can_edit:u.admin||u.manager});
 }
 if(req.method!=='POST'||url.pathname.endsWith('/options'))return bad('Method not allowed',405);
 if(!u.admin&&!u.manager)return bad('Chỉ Admin/Manager được giao chỉ tiêu',403);
 let b:any;try{const raw=await req.text();if(raw.length>16000)throw Error();b=JSON.parse(raw);}catch{return bad('Dữ liệu không hợp lệ');}
 if(!b||!uuid.test(String(b.client_ref))||typeof b.owner!=='string'||!Number.isInteger(b.year)||b.year<2000||b.year>2100||
 !['employee','customer','product'].includes(b.dimension)||typeof b.entity_id!=='string'||(b.dimension==='employee'?b.entity_id!=='':!uuid.test(b.entity_id))||
 !Array.isArray(b.months)||b.months.length<1||b.months.length>12||b.months.some((r:any)=>!r||!Number.isInteger(r.month)||r.month<1||r.month>12||!Number.isSafeInteger(r.amount)||r.amount<0||r.amount>1e12||!Number.isInteger(r.version)||r.version<0||r.version>2147483646)||
 new Set(b.months.map((r:any)=>r.month)).size!==b.months.length)return bad('Chỉ tiêu hoặc phiên bản không hợp lệ');
 try{
  const result=await sql`SELECT public.sales_target_apply(${u.sub},${b.client_ref}::uuid,${b.owner},${b.year},${b.dimension},${b.entity_id},${JSON.stringify(b.months)}::jsonb) AS items`;
  return json({items:result[0].items});
 }catch(e){const m=String((e as Error).message);
  if(m.includes('target_forbidden'))return bad('Không có quyền giao chỉ tiêu',403);
  if(m.includes('target_overallocated'))return bad('Phân bổ vượt chỉ tiêu nhân viên ở ít nhất một tháng',409);
  if(m.includes('target_stale')||m.includes('target_conflict'))return bad('Chỉ tiêu đã thay đổi. Tải lại trước khi lưu.',409);
  if(m.includes('target_invalid'))return bad('Chỉ tiêu không hợp lệ');
  throw e;
 }
}
