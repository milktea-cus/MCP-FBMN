import {neon} from '@neondatabase/serverless';
import type {AuthEnv} from './auth';
import districts from './districts_old.json';
import {normalizeLocalScopes,legacyMonthlyScope} from './local_multi_scopes';
type Actor={sub:string;admin:boolean;manager:boolean};
const json=(data:unknown,status=200)=>new Response(JSON.stringify(data),{
 status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const fail=(error:string,status=400)=>json({error},status);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const monthPattern=/^\d{4}-(0[1-9]|1[0-2])$/;
export function localMonthlyWeekDates(month:string,week:number):{from:string;to:string}|null{
 if(!monthPattern.test(month)||!Number.isInteger(week)||week<1||week>5)return null;
 const [y,m]=month.split('-').map(Number);
 const last=new Date(Date.UTC(y,m,0)).getUTCDate(),start=(week-1)*7+1;
 if(start>last)return null;
 return {from:month+'-'+String(start).padStart(2,'0'),
  to:month+'-'+String(Math.min(week*7,last)).padStart(2,'0')};
}
export function validateLocalMonthlyRule(v:Record<string,unknown>,edit:boolean):string|null{
 const scopes=v.scopes===undefined?legacyMonthlyScope(v):normalizeLocalScopes(v.scopes);
 if(typeof v.client_ref!=='string'||!uuid.test(v.client_ref)||
  typeof v.name!=='string'||v.name.trim().length<2||v.name.length>120||
  !Number.isInteger(v.week_no)||Number(v.week_no)<1||Number(v.week_no)>5||
  typeof v.active!=='boolean'||scopes===null||
  (edit?(!Number.isInteger(v.version)||Number(v.version)<1):
   (v.version!==undefined&&v.version!==0)))
  return 'Tên tuyến, tuần, phạm vi hoặc phiên bản không hợp lệ';
 return null;
}
export async function localMonthlyRoutes(
 req:Request,env:AuthEnv,actor:Actor,url:URL,
):Promise<Response|null>{
 const path='/api/v1/local-monthly-routes';
 if(url.pathname!==path&&!/^\/api\/v1\/local-monthly-routes\/[a-f0-9-]{36}$/i.test(url.pathname))
  return null;
 const match=/^\/api\/v1\/local-monthly-routes\/([a-f0-9-]{36})$/i.exec(url.pathname);
 if(match&&!uuid.test(match[1]))return fail('ID tuyến tháng không hợp lệ');
 const db=neon(env.DATABASE_URL);
 if(req.method==='GET'&&!match){
  const month=url.searchParams.get('month')??'';
  if(month&&!monthPattern.test(month))return fail('Tháng không hợp lệ');
  const rules=await db`SELECT r.* FROM public.field_local_monthly_routes r
   WHERE r.owner_sub=${actor.sub} AND public.sales_local_scopes_allowed(${actor.sub},r.scopes)
   ORDER BY r.week_no,r.scope_kind,r.scope_label,r.id LIMIT 300`;
  if(!month)return json({items:rules});
  const from=month+'-01';
  const progress=await db`SELECT r.id,
   (SELECT count(*)::int FROM public.customers c
    WHERE public.sales_customer_plannable(${actor.sub},c.id)
     AND EXISTS(SELECT 1 FROM jsonb_array_elements(r.scopes) sc
      WHERE (sc->>'scope_kind'='territory' AND c.province=sc->>'province'
        AND (sc->>'district'='' OR c.district=sc->>'district'))
       OR (sc->>'scope_kind'='customer' AND c.id::text=sc->>'scope_key')
       OR (sc->>'scope_kind'='chain' AND EXISTS(
        SELECT 1 FROM public.customer_scope_bindings b
        WHERE b.customer_id=c.id AND b.active AND b.scope_kind='chain'
          AND b.scope_key=sc->>'scope_key')))) AS customers_total,
   (SELECT count(*)::int FROM public.customers c
    WHERE public.sales_customer_plannable(${actor.sub},c.id)
     AND EXISTS(SELECT 1 FROM jsonb_array_elements(r.scopes) sc
      WHERE (sc->>'scope_kind'='territory' AND c.province=sc->>'province'
        AND (sc->>'district'='' OR c.district=sc->>'district'))
       OR (sc->>'scope_kind'='customer' AND c.id::text=sc->>'scope_key')
       OR (sc->>'scope_kind'='chain' AND EXISTS(
        SELECT 1 FROM public.customer_scope_bindings b
        WHERE b.customer_id=c.id AND b.active AND b.scope_kind='chain'
          AND b.scope_key=sc->>'scope_key')))
     AND EXISTS(SELECT 1 FROM public.field_visits v
      WHERE v.customer_id=c.id AND v.owner_sub=${actor.sub}
       AND (v.checkin_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
        BETWEEN ${from}::date+(r.week_no-1)*7
        AND LEAST(${from}::date+r.week_no*7-1,
         (${from}::date+INTERVAL '1 month - 1 day')::date))) AS customers_visited,
   (SELECT count(*)::int FROM public.field_monthly_plans p
    WHERE p.owner_sub=${actor.sub} AND p.status='planned'
     AND EXISTS(SELECT 1 FROM jsonb_array_elements(r.scopes) sc
      WHERE p.scope_kind=sc->>'scope_kind' AND p.scope_key=sc->>'scope_key')
     AND p.work_date BETWEEN ${from}::date+(r.week_no-1)*7
      AND LEAST(${from}::date+r.week_no*7-1,
       (${from}::date+INTERVAL '1 month - 1 day')::date)
   ) AS plan_count
   FROM public.field_local_monthly_routes r
   WHERE r.owner_sub=${actor.sub} AND r.active
     AND public.sales_local_scopes_allowed(${actor.sub},r.scopes)
   ORDER BY r.week_no,r.id LIMIT 300`;
  const byId=new Map(progress.map(p=>[String(p.id),p]));
  return json({month,items:rules.map(r=>({...r,progress:byId.get(String(r.id))??null}))});
 }
 if(!((req.method==='POST'&&!match)||(req.method==='PATCH'&&match)))
  return fail('Method not allowed',405);
 let body:Record<string,unknown>;
 try{
  if(!req.headers.get('Content-Type')?.includes('application/json'))throw Error();
  const raw=await req.text();if(raw.length>12000)throw Error();
  const value:unknown=JSON.parse(raw);
  if(!value||typeof value!=='object'||Array.isArray(value))throw Error();
  body=value as Record<string,unknown>;
 }catch{return fail('Dữ liệu tuyến tháng không hợp lệ');}
 const editing=!!match,invalid=validateLocalMonthlyRule(body,editing);
 if(invalid)return fail(invalid);
 const id=editing?match![1]:String(body.client_ref);
 if(!uuid.test(id)||(editing&&body.id!==undefined&&body.id!==id))
  return fail('ID tuyến tháng không hợp lệ');
 const scopes=body.scopes===undefined?legacyMonthlyScope(body):normalizeLocalScopes(body.scopes);
 if(!scopes)return fail('Phạm vi phân công không hợp lệ');
 if(editing&&body.scopes===undefined){
  const existing=await db`SELECT 1 FROM public.field_local_monthly_routes
   WHERE id=${id}::uuid AND owner_sub=${actor.sub} AND jsonb_array_length(scopes)>1`;
  if(existing.length)return fail('Vui lòng cập nhật ứng dụng để sửa tuyến nhiều phạm vi',409);
 }
 for(const area of scopes){
  if(area.scope_kind!=='territory')continue;
  const province=area.province!,district=area.district!;
  const known=(districts as Record<string,string[]>)[province];
  if(known&&(district===''||known.includes(district)))continue;
  const valid=await db`SELECT 1 FROM public.territory_catalog p
   WHERE p.active AND p.level='province' AND p.name=${province}
    AND (${district}='' OR EXISTS(SELECT 1 FROM public.territory_catalog d
     WHERE d.active AND d.level='district' AND d.parent_code=p.code
     AND d.name=${district})) LIMIT 1`;
  if(!valid.length)return fail('Có địa bàn không còn trong danh mục',400);
 }
 try{
  const saved=await db`SELECT public.sales_save_local_monthly_route_v2(
   ${actor.sub},${id}::uuid,${String(body.client_ref)}::uuid,
   ${editing?Number(body.version):0},${String(body.name)},${Number(body.week_no)}::smallint,
   ${JSON.stringify(scopes)}::jsonb,${body.active as boolean}) AS item`;
  return json({item:saved[0].item},editing?200:201);
 }catch(error){
  const message=(error as {message?:string;code?:string}).message??'';
  if(/PERMISSION|FORBIDDEN/.test(message))return fail('Ngoài phạm vi được giao',403);
  if(/STALE/.test(message)||(error as {code?:string}).code==='23505')
   return fail('Tuyến tuần đã thay đổi hoặc địa bàn bị giao trùng tuần; tải lại trước khi sửa',409);
  if(/INVALID/.test(message))return fail('Thông tin tuyến tháng không hợp lệ');
  return fail('Không lưu được tuyến tuần trong tháng',503);
 }
}
