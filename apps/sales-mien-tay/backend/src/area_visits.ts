import {neon} from '@neondatabase/serverless';
import type {AuthEnv} from './auth';
type Actor={sub:string;admin:boolean;manager:boolean};
const json=(v:unknown,status=200)=>new Response(JSON.stringify(v),{
 status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const bad=(error:string,status=400)=>json({error},status);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[89ab][0-9a-f]{12}$/i;
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
 if(url.pathname!=='/api/v1/area-visits'&&url.pathname!=='/api/v1/prospects')return null;
 const db=neon(env.DATABASE_URL);
 if(url.pathname==='/api/v1/prospects'&&req.method==='GET'){
  const rows=await db`SELECT p.*,v.day_route_stop_id,v.checkin_at,
   s.stop_kind,s.province,s.district,r.route_date FROM public.field_prospects p
   JOIN public.field_area_visits v ON v.id=p.area_visit_id
   JOIN public.field_route_stops s ON s.id=v.day_route_stop_id
   JOIN public.field_day_routes r ON r.id=s.day_route_id
   WHERE p.owner_sub=${actor.sub} OR ${actor.admin}
    OR (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},p.owner_sub))
   ORDER BY p.created_at DESC,p.id LIMIT 1000`;
  return json({items:rows});
 }
 if(url.pathname==='/api/v1/area-visits'&&req.method==='GET'){
  const stop=url.searchParams.get('stop_id')??'';
  if(!uuid.test(stop))return bad('Thiếu UUID điểm công tác');
  const items=await db`SELECT v.*,p.id AS prospect_id,p.name AS prospect_name,
   p.address_line AS prospect_address,p.status AS prospect_status
   FROM public.field_area_visits v LEFT JOIN public.field_prospects p ON p.area_visit_id=v.id
   JOIN public.field_route_stops s ON s.id=v.day_route_stop_id
   WHERE v.day_route_stop_id=${stop}::uuid
    AND (v.owner_sub=${actor.sub} OR ${actor.admin}
      OR (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},v.owner_sub)))
   ORDER BY v.checkin_at DESC,v.id LIMIT 200`;
  return json({items});
 }
 if(url.pathname!=='/api/v1/area-visits'||req.method!=='POST')return bad('Method not allowed',405);
 let v:Record<string,unknown>;
 try{v=await input(req);}catch{return bad('JSON không hợp lệ');}
 const ref=v.client_ref,stop=v.day_route_stop_id,at=captured(v.captured_at);
 if(typeof ref!=='string'||!uuid.test(ref)||typeof stop!=='string'||!uuid.test(stop)||!at)
  return bad('UUID và ngày GPS không hợp lệ');
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
 try{
  const rows=await db`SELECT public.sales_save_area_visit(
   ${actor.sub},${ref}::uuid,${stop}::uuid,${at}::timestamptz,
   ${v.latitude as number},${v.longitude as number},${v.accuracy_m as number},
   ${String(v.note??'')},${prospect?.name??null},${prospect?.address_line??null}) AS item`;
  return json({item:rows[0].item},201);
 }catch(e){
  const message=(e as {message?:string;code?:string}).message??'';
  if(message.includes('permission'))return bad('Chưa được giao tuyến hoặc quyền đã thu hồi',403);
  if(message.includes('conflict'))return bad('UUID check-in đã dùng cho nội dung khác',409);
  if(message.includes('invalid'))return bad('Dữ liệu check-in không hợp lệ');
  return bad('Không ghi nhận được GPS công tác',503);
 }
}
