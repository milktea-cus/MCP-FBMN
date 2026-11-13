import {neon} from '@neondatabase/serverless';
import type {AuthEnv} from './auth';

type Actor={sub:string;admin:boolean;manager:boolean};
const reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{
 status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const fail=(error:string,status=400)=>reply({error},status);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function day(v:unknown):v is string {
 return typeof v==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(v)
  &&Number.isFinite(Date.parse(v))&&new Date(v).toISOString().slice(0,10)===v;
}
async function parse(req:Request):Promise<Record<string,unknown>>{
 if(!req.headers.get('Content-Type')?.includes('application/json'))throw Error('JSON');
 const raw=await req.text();if(raw.length>20000)throw Error('size');
 const value=JSON.parse(raw) as unknown;
 if(!value||typeof value!=='object'||Array.isArray(value))throw Error('object');
 return value as Record<string,unknown>;
}
const string=(s:unknown,min:number,max:number):s is string=>
 typeof s==='string'&&s.trim().length>=min&&s.length<=max;
export function validRoute(v:Record<string,unknown>,editing:boolean):string|null{
 if(!uuid.test(String(v.client_ref??''))||!uuid.test(String(v.monthly_plan_id??''))||
 !day(v.route_date)||!string(v.purpose,2,500)||
 !string(v.note??'',0,2000)||!['ready','cancelled'].includes(String(v.status??'ready'))||
 (editing?(!Number.isInteger(v.version)||Number(v.version)<1):
  (v.version!==undefined&&v.version!==0)))return 'Dữ liệu tuyến ngày không hợp lệ';
 return null;
}
export function validRouteStop(v:Record<string,unknown>,editing:boolean):string|null{
 if(!uuid.test(String(v.client_ref??''))||!['customer','area','chain'].includes(String(v.stop_kind))||
 !Number.isInteger(v.sequence)||Number(v.sequence)<1||Number(v.sequence)>9999||
 !string(v.purpose??'',0,500)||
 (editing?(!Number.isInteger(v.version)||Number(v.version)<1):
  (v.version!==undefined&&v.version!==0)))return 'Điểm ghé hoặc thứ tự không hợp lệ';
 if(v.stop_kind==='customer'&&!uuid.test(String(v.customer_id??'')))return 'Khách hàng không hợp lệ';
 if(v.stop_kind==='chain'&&!uuid.test(String(v.chain_id??'')))return 'Chuỗi không hợp lệ';
 if(v.stop_kind==='area'&&(typeof v.province!=='string'||typeof v.district!=='string'||!v.province))return 'Địa bàn không hợp lệ';
 return null;
}
function saveError(e:unknown):Response{
 const message=(e as {message?:string;code?:string}).message??'';
 if(message.includes('permission')||message.includes('forbidden'))return fail('Phạm vi công tác đã bị thay đổi hoặc không có quyền',403);
 if(message.includes('stale')||message.includes('visited')||(e as {code?:string}).code==='23505')return fail('Tuyến hoặc điểm ghé bị trùng, đã ghé hoặc thay đổi phiên bản',409);
 return fail('Không lưu được tuyến ngày/điểm ghé',503);
}
export async function dayRouteRoutes(req:Request,env:AuthEnv,actor:Actor,url:URL):Promise<Response|null>{
 if(!url.pathname.startsWith('/api/v1/day-routes'))return null;
 const suffix=url.pathname.slice('/api/v1/day-routes'.length);
 const db=neon(env.DATABASE_URL);
 if(suffix===''&&req.method==='GET'){
  const month=url.searchParams.get('month')??'';
  if(!/^\d{4}-(0[1-9]|1[0-2])$/.test(month))return fail('Tháng không hợp lệ');
  const items=await db`SELECT r.*,p.period_ym,p.scope_kind,p.scope_key,p.province,p.district,
    (SELECT count(*) FROM public.field_route_stops s WHERE s.day_route_id=r.id)::integer AS stop_count,
    (SELECT count(*) FROM public.field_route_stops s WHERE s.day_route_id=r.id
      AND (EXISTS(SELECT 1 FROM public.field_visits v WHERE v.day_route_stop_id=s.id)
        OR EXISTS(SELECT 1 FROM public.field_area_visits a WHERE a.day_route_stop_id=s.id)))::integer AS visited_count,
    (SELECT count(DISTINCT se.day_route_stop_id) FROM public.field_survey_sessions se
      JOIN public.field_route_stops s ON s.id=se.day_route_stop_id
      WHERE s.day_route_id=r.id AND se.status='completed')::integer AS survey_count,
    (SELECT count(*)::integer FROM public.field_prospects prospect
      JOIN public.field_area_visits area ON area.id=prospect.area_visit_id
      JOIN public.field_route_stops stop ON stop.id=area.day_route_stop_id
      WHERE stop.day_route_id=r.id) AS lead_count
   FROM public.field_day_routes r JOIN public.field_monthly_plans p ON p.id=r.monthly_plan_id
   WHERE p.period_ym=${month} AND
    (r.owner_sub=${actor.sub} OR ${actor.admin} OR
     (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},r.owner_sub)))
   ORDER BY r.route_date,r.created_at,r.id LIMIT 2000`;
  return reply({items});
 }
 const path=/^\/([0-9a-f-]{36})(?:\/(stops|candidates)(?:\/([0-9a-f-]{36}))?)?$/i.exec(suffix);
 if(path&&!uuid.test(path[1])||path?.[3]&&!uuid.test(path[3]))return fail('Route UUID không hợp lệ');
 const routeId=path?.[1]??'';
 if(path&&(req.method==='GET')){
  const routes=await db`SELECT r.*,p.period_ym,p.scope_kind,p.scope_key,p.province,p.district,p.status AS plan_status
   FROM public.field_day_routes r JOIN public.field_monthly_plans p ON p.id=r.monthly_plan_id
   WHERE r.id=${routeId}::uuid AND
    (r.owner_sub=${actor.sub} OR ${actor.admin} OR
      (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},r.owner_sub))) LIMIT 1`;
  const route=routes[0];if(!route)return fail('Không tìm thấy tuyến hoặc không có quyền',404);
  if(path[2]==='candidates'){
   if(route.owner_sub!==actor.sub)return fail('Chỉ chủ tuyến xem gợi ý khách để lập lịch',403);
   const customers=await db`SELECT c.id,c.name,c.province,c.district,c.category,c.code
    FROM public.customers c
    WHERE public.sales_customer_plannable(${actor.sub},c.id)
     AND ((${route.scope_kind==='territory'} AND c.province=${route.province}
       AND (${route.district}='' OR c.district=${route.district}))
       OR (${route.scope_kind==='chain'} AND EXISTS(
         SELECT 1 FROM public.customer_scope_bindings b WHERE b.customer_id=c.id
         AND b.active AND b.scope_kind='chain' AND b.scope_key=${route.scope_key}))
        OR (${route.scope_kind==='customer'} AND c.id::text=${route.scope_key}))
    ORDER BY c.name,c.id LIMIT 1000`;
   return reply({items:customers,truncated:customers.length===1000});
  }
  const stops=await db`SELECT s.*,c.name AS customer_name,c.code AS customer_code,c.province AS customer_province,
    c.district AS customer_district,c.category AS category,c.latitude,c.longitude,
    c.location_consent,c.address_line,c.owner_sub AS customer_owner,ch.name AS chain_name,
    ((SELECT count(*) FROM public.field_visits v WHERE v.day_route_stop_id=s.id)
     +(SELECT count(*) FROM public.field_area_visits a WHERE a.day_route_stop_id=s.id))::integer AS visit_count,
    (SELECT count(*) FROM public.field_survey_sessions se WHERE se.day_route_stop_id=s.id)::integer AS session_count,
    (SELECT count(*) FROM public.field_survey_sessions se WHERE se.day_route_stop_id=s.id AND se.status='completed')::integer AS completed_sessions,
    (SELECT json_build_object(
      'client_ref',v.client_ref,'latitude',v.latitude,'longitude',v.longitude,
      'accuracy_m',v.accuracy_m,'checkin_at',v.checkin_at)
     FROM public.field_visits v WHERE v.day_route_stop_id=s.id
       AND v.owner_sub=${actor.sub} AND s.stop_kind='customer'
     ORDER BY v.checkin_at DESC,v.id DESC LIMIT 1) AS last_checkin
    FROM public.field_route_stops s LEFT JOIN public.customers c ON c.id=s.customer_id
    LEFT JOIN public.customer_chains ch ON ch.id=s.chain_id
    WHERE s.day_route_id=${routeId}::uuid ORDER BY s.sequence,s.created_at,s.id LIMIT 1000`;
  return reply({item:route,stops:stops.map(s=>({
   ...s,activity_status:Number(s.completed_sessions)>0?'survey_completed':
     Number(s.session_count)>0?'survey_started':
     Number(s.visit_count)>0?'visited':'planned'}))});
 }
 if(req.method==='POST'&&suffix==='' || req.method==='PATCH'&&path&&!path[2]){
  let v:Record<string,unknown>;try{v=await parse(req);}catch{return fail('JSON không hợp lệ');}
  const editing=req.method==='PATCH',error=validRoute(v,editing);if(error)return fail(error);
  const id=editing?routeId:String(v.client_ref);
  try{
   const rows=await db`SELECT public.sales_save_day_route(
     ${actor.sub},${id}::uuid,${String(v.client_ref)}::uuid,${editing?Number(v.version):0},
     ${String(v.monthly_plan_id)}::uuid,${String(v.route_date)}::date,
     ${String(v.purpose).trim()},${String(v.note??'')},${String(v.status??'ready')}) AS item`;
   return reply({item:rows[0].item},editing?200:201);
  }catch(e){return saveError(e);}
 }
 if(path&&path[2]==='stops'&&(req.method==='POST'||req.method==='PATCH'&&!!path[3])){
  let v:Record<string,unknown>;try{v=await parse(req);}catch{return fail('JSON không hợp lệ');}
  const editing=req.method==='PATCH',error=validRouteStop(v,editing);if(error)return fail(error);
  const id=editing?path[3]:String(v.client_ref);
  const customer=v.stop_kind==='customer'?String(v.customer_id):null;
  const chain=v.stop_kind==='chain'?String(v.chain_id):null;
  const province=v.stop_kind==='area'?String(v.province):null;
  const district=v.stop_kind==='area'?String(v.district):null;
  try{
   const rows=await db`SELECT public.sales_save_route_stop(
     ${actor.sub},${id}::uuid,${String(v.client_ref)}::uuid,${editing?Number(v.version):0},
     ${routeId}::uuid,${String(v.stop_kind)},${customer}::uuid,${chain}::uuid,
     ${province},${district},${Number(v.sequence)},${String(v.purpose??'')}) AS item`;
   return reply({item:rows[0].item},editing?200:201);
  }catch(e){return saveError(e);}
 }
 return fail('Method not allowed',405);
}
