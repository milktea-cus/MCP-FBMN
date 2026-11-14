import {neon} from '@neondatabase/serverless';
import type {AuthEnv} from './auth';
type Actor={sub:string;admin:boolean;manager:boolean};
type Body=Record<string,unknown>;
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const isUuid=(x:unknown):x is string=>typeof x==='string'&&uuid.test(x);
const isDay=(x:unknown):x is string=>typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&Number.isFinite(Date.parse(x))&&new Date(x).toISOString().slice(0,10)===x;
const days=(a:string,b:string)=>Math.round((Date.parse(b)-Date.parse(a))/86400000);
const isTime=(x:unknown):x is string=>typeof x==='string'&&x.length<=40&&x.length>=20&&Number.isFinite(Date.parse(x))&&/(Z|[+-]\d{2}:\d{2})$/.test(x);
const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const fail=(code:string,error:string,status=400)=>reply({code,error},status);
async function body(req:Request):Promise<Body>{
 if(!req.headers.get('content-type')?.includes('application/json'))throw Error('JSON');
 const raw=await req.text();if(raw.length>20000)throw Error('SIZE');
 const v:unknown=JSON.parse(raw);if(!v||typeof v!=='object'||Array.isArray(v))throw Error('JSON');
 return v as Body;
}
type Scope={scope_kind:'territory'|'chain'|'customer';scope_key:string;province:string|null;district:string|null};
export function normalizeTripScopes(input:unknown):Scope[]|null{
 if(!Array.isArray(input)||input.length<1||input.length>50)return null;
 const out:Scope[]=[],seen=new Set<string>();
 for(const value of input){
  if(!value||typeof value!=='object'||Array.isArray(value))return null;
  const o=value as Body,k=o.scope_kind,key=o.scope_key;
  if(!['territory','chain','customer'].includes(String(k))||typeof key!=='string'||!key||key.length>240)return null;
  const province=k==='territory'?o.province:null,district=k==='territory'?o.district:null;
  if(k==='territory'&&(typeof province!=='string'||!province||typeof district!=='string'||key!==province+'|'+district))return null;
  if(k!=='territory'&&(!isUuid(key)||o.province!=null||o.district!=null))return null;
  const pair=k+':'+key;if(seen.has(pair))return null;seen.add(pair);
  out.push({scope_kind:k as Scope['scope_kind'],scope_key:key,province:province as string|null,district:district as string|null});
 }
 return out.sort((a,b)=>(a.scope_kind+':'+a.scope_key).localeCompare(b.scope_kind+':'+b.scope_key,'en'));
}
export function normalizeTripPriorities(v:unknown):string[]|null{
 if(v==null)return [];
 if(!Array.isArray(v)||v.length>500||v.some(x=>!isUuid(x))||new Set(v).size!==v.length)return null;
 return (v as string[]).slice().sort();
}
export function validateTripCreate(v:Body):string|null{
 if(!isUuid(v.client_ref)||!isUuid(v.mutation_ref)||!isUuid(v.day_route_id)
  ||!isDay(v.start_date)||!isDay(v.end_date)||days(v.start_date as string,v.end_date as string)<0
  ||days(v.start_date as string,v.end_date as string)>90
  ||typeof v.purpose!=='string'||v.purpose.trim().length<2||v.purpose.length>500
  ||typeof(v.note??'')!=='string'||String(v.note??'').length>2000
  ||!normalizeTripScopes(v.scopes)||!normalizeTripPriorities(v.priorities))return 'Chuyến, ngày hoặc phạm vi không hợp lệ';
 return null;
}
export function validateTripMutation(v:Body,action:'extend'|'close'):string|null{
 if(!isUuid(v.client_ref)||!Number.isInteger(v.version)||Number(v.version)<1
  ||!isTime(v.captured_at)||typeof(v.note??'')!=='string'||String(v.note??'').length>2000
  ||(action==='extend'&&!isDay(v.end_date))||(action==='close'&&v.end_date!=null))
  return 'Thay đổi chuyến không hợp lệ';
 return null;
}
function failure(e:unknown){
 const message=(e as {message?:string})?.message??'';
 const map:Record<string,[number,string]>={
  TRIP_INVALID:[400,'Dữ liệu chuyến không hợp lệ.'],
  TRIP_ROUTE_INVALID:[403,'Tuyến gốc đã hết quyền hoặc không hợp lệ.'],
  TRIP_SCOPE_REVOKED:[403,'Phạm vi khách hoặc ngày chuyến không còn hợp lệ.'],
  TRIP_FORBIDDEN:[403,'Không có quyền sửa chuyến.'],
  TRIP_PRIORITY_FORBIDDEN:[403,'Khách ưu tiên ngoài quyền được giao.'],
  TRIP_VERSION_CONFLICT:[409,'Chuyến đã thay đổi trên thiết bị khác. Giữ bản chờ để đối chiếu.'],
  TRIP_MUTATION_REPLAY_MISMATCH:[409,'Mã thao tác trùng nhưng nội dung khác. Giữ bản chờ để đối chiếu.'],
  TRIP_CLOSED:[409,'Chuyến đã kết thúc. Chỉ xem lịch sử.'],
  TRIP_DATES_OVERLAP:[409,'Ngày chuyến trùng chuyến khác.'],
  TRIP_ROUTE_IN_USE:[409,'Tuyến gốc đã thuộc chuyến khác.'],
  TRIP_ALREADY_EXISTS:[409,'Mã chuyến đã tồn tại.'],
  TRIP_SCOPE_DUPLICATE:[409,'Phạm vi chuyến trùng.'],
  TRIP_PRIMARY_SCOPE_REQUIRED:[400,'Phạm vi gốc không nằm trong chuyến.'],
  TRIP_PRIORITY_DUPLICATE:[409,'Khách ưu tiên trùng.'],
  TRIP_INVALID_EXTENSION:[400,'Ngày gia hạn phải sau ngày cũ, không quá 90 ngày.'],
 };
 for(const [k,[status,detail]] of Object.entries(map))if(message.includes(k))return fail(k,detail,status);
 return fail('TRIP_SAVE_FAILED','Lỗi lưu chuyến; giữ nguyên hàng đợi offline.',503);
}
export async function tripRoutes(req:Request,env:AuthEnv,actor:Actor,url:URL):Promise<Response|null>{
 if(!url.pathname.startsWith('/api/v1/trips'))return null;
 const suffix=url.pathname.slice('/api/v1/trips'.length),db=neon(env.DATABASE_URL);
 if(suffix===''&&req.method==='GET'){
  const from=url.searchParams.get('from'),to=url.searchParams.get('to');
  if((from!==null&&!isDay(from))||(to!==null&&!isDay(to))||(from&&to&&(from>to||days(from,to)>400)))
   return fail('TRIP_INVALID','Khoảng ngày không hợp lệ');
  const rows=await db`SELECT t.*,r.status AS route_status,p.scope_kind,p.scope_key,p.province,p.district,
   (SELECT coalesce(jsonb_agg(jsonb_build_object('scope_kind',s.scope_kind,'scope_key',s.scope_key,
     'province',s.province,'district',s.district) ORDER BY s.scope_kind,s.scope_key),'[]'::jsonb)
    FROM public.field_trip_scopes s WHERE s.trip_id=t.id) AS scopes,
   (SELECT count(*)::integer FROM public.field_route_stops st WHERE st.day_route_id=t.day_route_id AND NOT st.is_unplanned) AS stop_count,
   (SELECT count(DISTINCT st.customer_id)::integer FROM public.field_route_stops st JOIN public.field_customer_work_actions a ON a.route_stop_id=st.id WHERE st.day_route_id=t.day_route_id) AS visited_count,
   (SELECT count(*)::integer FROM public.field_survey_sessions se JOIN public.field_route_stops st ON st.id=se.day_route_stop_id WHERE st.day_route_id=t.day_route_id AND se.status='completed') AS survey_count,
   (SELECT count(*)::integer FROM public.field_area_visits av WHERE av.day_route_id=t.day_route_id) AS market_visit_count,
   CASE WHEN t.closed_at IS NOT NULL THEN 'closed' WHEN t.start_date>(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date THEN 'upcoming'
        WHEN t.end_date<(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date THEN 'overdue' ELSE 'active' END AS trip_state
   FROM public.field_trips t JOIN public.field_day_routes r ON r.id=t.day_route_id
   JOIN public.field_monthly_plans p ON p.id=r.monthly_plan_id
   WHERE (${from}::date IS NULL OR t.end_date>=${from}::date)
     AND (${to}::date IS NULL OR t.start_date<=${to}::date)
     AND (t.owner_sub=${actor.sub} OR ${actor.admin} OR
       (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},t.owner_sub)))
   ORDER BY t.start_date,t.id LIMIT 500`;
  return reply({items:rows});
 }
 if(suffix===''&&req.method==='POST'){
  let v:Body;try{v=await body(req);}catch{return fail('TRIP_INVALID','JSON không hợp lệ');}
  const message=validateTripCreate(v);if(message)return fail('TRIP_INVALID',message);
  try{
   const r=await db`SELECT public.sales_create_trip(${actor.sub},${v.client_ref as string}::uuid,
     ${v.day_route_id as string}::uuid,${v.start_date as string}::date,${v.end_date as string}::date,
     ${String(v.purpose).trim()},${String(v.note??'')},${JSON.stringify(normalizeTripScopes(v.scopes))}::jsonb,
     ${JSON.stringify(normalizeTripPriorities(v.priorities))}::jsonb,${v.mutation_ref as string}::uuid) AS item`;
   const item=r[0].item as Body;
   return reply({item,already_saved:item.already_saved===true},item.already_saved?200:201);
  }catch(e){return failure(e);}
 }
 const m=/^\/([0-9a-f-]{36})(?:\/(extend|close))?$/i.exec(suffix);
 if(!m||!isUuid(m[1]))return fail('TRIP_NOT_FOUND','Không thấy chuyến',404);
 const id=m[1];
 if(!m[2]&&req.method==='GET'){
  const rows=await db`SELECT t.*,
   (SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.scope_kind,s.scope_key),'[]'::jsonb) FROM public.field_trip_scopes s WHERE s.trip_id=t.id) AS scopes,
   (SELECT coalesce(jsonb_agg(jsonb_build_object('kind',a.kind,'customer_id',a.customer_id,'captured_at',a.captured_at,'id',a.id) ORDER BY a.captured_at),'[]'::jsonb) FROM public.field_customer_work_actions a WHERE a.day_route_id=t.day_route_id) AS activities,
   (SELECT coalesce(jsonb_agg(jsonb_build_object('id',v.id,'customer_id',v.customer_id,'checkin_at',v.checkin_at) ORDER BY v.checkin_at),'[]'::jsonb) FROM public.field_visits v JOIN public.field_route_stops st ON st.id=v.day_route_stop_id WHERE st.day_route_id=t.day_route_id) AS gps_history
   FROM public.field_trips t WHERE t.id=${id}::uuid
     AND (t.owner_sub=${actor.sub} OR ${actor.admin} OR
       (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},t.owner_sub))) LIMIT 1`;
  return rows.length?reply({item:rows[0]}):fail('TRIP_NOT_FOUND','Không thấy chuyến hoặc không có quyền',404);
 }
 if(m[2]&&req.method==='POST'){
  let v:Body;try{v=await body(req);}catch{return fail('TRIP_INVALID','JSON không hợp lệ');}
  const action=m[2] as 'extend'|'close',message=validateTripMutation(v,action);
  if(message)return fail('TRIP_INVALID',message);
  try{
   const r=await db`SELECT public.sales_mutate_trip(${actor.sub},${id}::uuid,
     ${v.client_ref as string}::uuid,${Number(v.version)},${action},
     ${action==='extend'?String(v.end_date):null}::date,
     ${String(v.note??'')},${v.captured_at as string}::timestamptz) AS item`;
   return reply({item:r[0].item});
  }catch(e){return failure(e);}
 }
 return fail('TRIP_INVALID_METHOD','Method not allowed',405);
}

