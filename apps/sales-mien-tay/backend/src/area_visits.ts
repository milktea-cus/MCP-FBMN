import {neon} from '@neondatabase/serverless';
import type {AuthEnv} from './auth';
type Actor={sub:string;admin:boolean;manager:boolean};
const json=(v:unknown,status=200)=>new Response(JSON.stringify(v),{
 status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const bad=(error:string,status=400)=>json({error},status);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
async function input(req:Request){
 if(!req.headers.get('Content-Type')?.includes('application/json'))throw Error('Content-Type');
 const raw=await req.text();if(raw.length>12000)throw Error('Body too large');
 const obj=JSON.parse(raw) as unknown;
 if(!obj||Array.isArray(obj)||typeof obj!=='object')throw Error('Body');
 return obj as Record<string,unknown>;
}
function captured(value:unknown):string|null{
 if(typeof value!=='string'||value.length>40||!Number.isFinite(Date.parse(value)))return null;
 const t=Date.parse(value);
 if(t>Date.now()+60000||t<Date.now()-30*86400000)return null;
 return new Date(t).toISOString();
}
export async function areaVisitRoutes(req:Request,env:AuthEnv,actor:Actor,url:URL):Promise<Response|null>{
 const convert=/^\/api\/v1\/prospects\/([a-f0-9-]{36})\/convert$/i.exec(url.pathname);
 if(url.pathname!=='/api/v1/area-visits'&&url.pathname!=='/api/v1/prospects'&&!convert)return null;
 const db=neon(env.DATABASE_URL);
 if(convert){
  if(req.method!=='POST')return bad('Method not allowed',405);
  if(!uuid.test(convert[1]))return bad('Lead UUID không hợp lệ');
  let b:Record<string,unknown>;
  try{b=await input(req);}catch{return bad('JSON không hợp lệ');}
  if(typeof b.customer_id!=='string'||!uuid.test(b.customer_id))
   return bad('Chọn khách hàng đã tạo và xác minh');
  try{
   const rows=await db`SELECT public.sales_convert_prospect(
    ${actor.sub},${convert[1]}::uuid,${b.customer_id}::uuid) AS item`;
   return json({item:rows[0].item});
  }catch(e){
   const m=(e as Error).message??'';
   if(m.includes('permission'))return bad('Không có quyền hoặc khách không thuộc phạm vi lead',403);
   if(m.includes('conflict'))return bad('Lead đã chuyển hoặc đóng bằng hồ sơ khác',409);
   return bad('Không liên kết được lead với khách',503);
  }
 }
 if(url.pathname==='/api/v1/prospects'&&req.method==='GET'){
  const filter=url.searchParams.get('stop_id')??'';
  const routeId=url.searchParams.get('route_id')??'';
  if((filter&&!uuid.test(filter))||(routeId&&!uuid.test(routeId))||
    (filter!==''&&routeId!==''))return bad('Bộ lọc công tác không hợp lệ');
  const rows=await db`SELECT p.*,v.day_route_stop_id,v.checkin_at,
   s.stop_kind,s.province,s.district,r.route_date FROM public.field_prospects p
   JOIN public.field_area_visits v ON v.id=p.area_visit_id
   LEFT JOIN public.field_route_stops s ON s.id=v.day_route_stop_id
   JOIN public.field_day_routes r ON r.id=coalesce(v.day_route_id,s.day_route_id)
   WHERE (${filter}='' OR v.day_route_stop_id=${filter||null}::uuid)
     AND (${routeId}='' OR v.day_route_id=${routeId||null}::uuid) AND
    (p.owner_sub=${actor.sub} OR ${actor.admin}
    OR (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},p.owner_sub)))
   ORDER BY p.created_at DESC,p.id LIMIT 1000`;
  return json({items:rows});
 }
 if(url.pathname==='/api/v1/area-visits'&&req.method==='GET'){
  const stop=url.searchParams.get('stop_id')??'';
  const routeId=url.searchParams.get('route_id')??'';
  if((!stop&&!routeId)||(stop&&routeId)||
   (stop&&!uuid.test(stop))||(routeId&&!uuid.test(routeId)))
   return bad('Thiếu hoặc trùng UUID phạm vi công tác');
  const items=await db`SELECT v.*,(SELECT count(*) FROM public.field_area_visit_photos f WHERE f.area_visit_id=v.id AND f.status='ready')::int AS photo_count,
   p.id AS prospect_id,p.name AS prospect_name,
   p.address_line AS prospect_address,p.status AS prospect_status
   FROM public.field_area_visits v LEFT JOIN public.field_prospects p ON p.area_visit_id=v.id
   LEFT JOIN public.field_route_stops s ON s.id=v.day_route_stop_id
   WHERE ((${stop}<>'' AND v.day_route_stop_id=${stop||null}::uuid)
      OR (${routeId}<>'' AND v.day_route_id=${routeId||null}::uuid))
    AND (v.owner_sub=${actor.sub} OR ${actor.admin}
      OR (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},v.owner_sub)))
   ORDER BY v.checkin_at DESC,v.id LIMIT 200`;
  return json({items});
 }
 if(url.pathname!=='/api/v1/area-visits'||req.method!=='POST')return bad('Method not allowed',405);
 let v:Record<string,unknown>;
 try{v=await input(req);}catch{return bad('JSON không hợp lệ');}
 const ref=v.client_ref,stop=v.day_route_stop_id,route=v.day_route_id,at=captured(v.captured_at);
 const scoped=(typeof stop==='string'&&uuid.test(stop)) !==
  (typeof route==='string'&&uuid.test(route));
 if(typeof ref!=='string'||!uuid.test(ref)||!scoped||!at||
   (stop!=null&&(typeof stop!=='string'||!uuid.test(stop)))||
   (route!=null&&(typeof route!=='string'||!uuid.test(route))))
  return bad('UUID tuyến/điểm ghé hoặc ngày GPS không hợp lệ');
 if(typeof v.latitude!=='number'||!Number.isFinite(v.latitude)||Math.abs(v.latitude)>90
   ||typeof v.longitude!=='number'||!Number.isFinite(v.longitude)||Math.abs(v.longitude)>180
   ||typeof v.accuracy_m!=='number'||!Number.isFinite(v.accuracy_m)||v.accuracy_m<0||v.accuracy_m>100)
   return bad('GPS không hợp lệ (yêu cầu sai số tối đa 100 m)');
 if(v.note!=null&&(typeof v.note!=='string'||v.note.length>2000))return bad('Ghi chú quá dài');
 const p=v.prospect;
 if(p!=null&&(typeof p!=='object'||Array.isArray(p)||typeof (p as Record<string,unknown>).name!=='string'
 ||(p as Record<string,unknown>).name!.toString().trim().length<2
 ||(p as Record<string,unknown>).name!.toString().length>240
 ||typeof (p as Record<string,unknown>).address_line!=='string'
 ||(p as Record<string,unknown>).address_line!.toString().trim().length<3
 ||(p as Record<string,unknown>).address_line!.toString().length>500))
 return bad('Lead phải có tên và địa chỉ điểm bán thực tế');
 const prospect=p as {name:string;address_line:string}|null|undefined;
 if(typeof route==='string'){
  // Only an ongoing, owner-scoped work session can collect NEW market data.
  const active=await db`SELECT w.id FROM public.field_work_sessions w
   JOIN public.field_day_routes r ON r.id=w.day_route_id
   JOIN public.field_monthly_plans m ON m.id=r.monthly_plan_id
   WHERE w.day_route_id=${route}::uuid AND w.owner_sub=${actor.sub}
    AND w.state='ongoing' AND
    public.sales_monthly_plan_scope_allowed(
      ${actor.sub},m.scope_kind,m.scope_key,m.province,m.district)
   LIMIT 1`;
  if(!active.length)return json({
    code:'WORK_SESSION_NOT_ACTIVE',
    error:'Phiên chưa bắt đầu hoặc đã kết thúc. Không ghi GPS mới ngoài phiên.'},409);
 }
 try{
  const values=typeof route==='string'
   ?await db`SELECT public.sales_save_route_market_visit(
    ${actor.sub},${ref}::uuid,${route}::uuid,${at}::timestamptz,
    ${v.latitude as number},${v.longitude as number},${v.accuracy_m as number},
    ${String(v.note??'')},${prospect?.name??null},${prospect?.address_line??null}) AS item`
   :await db`SELECT public.sales_save_area_visit(
    ${actor.sub},${ref}::uuid,${stop}::uuid,${at}::timestamptz,
    ${v.latitude as number},${v.longitude as number},${v.accuracy_m as number},
    ${String(v.note??'')},${prospect?.name??null},${prospect?.address_line??null}) AS item`;
  return json({item:values[0].item},201);
 }catch(e){
  const message=(e as {message?:string;code?:string}).message??'';
  if(message.includes('permission'))return bad('Chưa được giao tuyến hoặc quyền đã thu hồi',403);
  if(message.includes('conflict'))return bad('UUID check-in đã dùng cho nội dung khác',409);
  if(message.includes('invalid'))return bad('Dữ liệu check-in không hợp lệ');
  return bad('Không ghi nhận được GPS công tác',503);
 }
}
