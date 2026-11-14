import {neon} from '@neondatabase/serverless';
import type {AuthEnv} from './auth';

type Actor={sub:string;admin:boolean;manager:boolean};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const response=(data:unknown,status=200)=>new Response(JSON.stringify(data),{
 status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const fail=(code:string,error:string,status=400)=>response({code,error},status);
const hasUuid=(v:unknown):v is string=>typeof v==='string'&&uuid.test(v);
const isoTime=(v:unknown):v is string=>typeof v==='string'&&v.length>=20&&v.length<=40&&
 Number.isFinite(Date.parse(v))&&/(Z|[+-]\d{2}:\d{2})$/.test(v);
async function body(req:Request):Promise<Record<string,unknown>>{
 if(!req.headers.get('content-type')?.includes('application/json'))throw Error('JSON');
 const raw=await req.text();if(raw.length>8000)throw Error('BODY_TOO_LARGE');
 const value:unknown=JSON.parse(raw);
 if(!value||typeof value!=='object'||Array.isArray(value))throw Error('JSON');
 return value as Record<string,unknown>;
}
const errors:Record<string,[string,number]>={
 SCOPE_REVOKED:['Phạm vi công tác đã bị thu hồi hoặc không có quyền.',403],
 SESSION_CLOSED:['Phiên đã kết thúc/hủy. Chỉ xem lịch sử, không mở lại.',409],
 SESSION_ACTIVE_OTHER_ROUTE:['Anh/chị đang có phiên công tác khác. Hãy kết thúc phiên đó trước.',409],
 SESSION_STILL_ACTIVE:['Hãy kết thúc hoặc hủy phiên trước khi xóa.',409],
 SESSION_HAS_ACTIVITY:['Phiên đã có công việc thực tế; không được xóa lịch sử.',409],
 SESSION_ALREADY_STARTED:['Phiên đã bắt đầu; không được dời ngày hoặc hủy tuyến.',409],
 WORK_SESSION_VERSION_CONFLICT:['Phiên đã được cập nhật trên thiết bị khác. Tải lại dữ liệu.',409],
 WORK_SESSION_WRONG_DAY:['Chỉ bắt đầu phiên vào đúng ngày lịch đã lập.',409],
 INVALID_WORK_SESSION:['Dữ liệu hoặc thời gian phiên không hợp lệ.',400],
};
function failure(e:unknown){
 const message=(e as {message?:string})?.message??'';
 for(const [code,[text,status]] of Object.entries(errors)){
  if(message.includes(code))return fail(code,text,status);
 }
 if((e as {code?:string}).code==='23505')
  return fail('SESSION_ALREADY_ACTIVE','Phiên đã tồn tại; tải lại để tiếp tục phiên.',409);
 return fail('SESSION_SERVER_ERROR','Không ghi được phiên công tác.',503);
}
export async function workSessionRoutes(
 req:Request,env:AuthEnv,actor:Actor,url:URL
):Promise<Response|null>{
 const route=/^\/api\/v1\/day-routes\/([0-9a-f-]{36})\/work-session$/i.exec(url.pathname);
 const session=/^\/api\/v1\/work-sessions\/([0-9a-f-]{36})(?:\/(close))?$/i.exec(url.pathname);
 if(!route&&!session)return null;
 const db=neon(env.DATABASE_URL);
 if(route){
  const id=route[1];if(!uuid.test(id))return fail('INVALID_WORK_SESSION','Mã tuyến không hợp lệ.');
  if(req.method==='GET'){
   const rows=await db`SELECT s.*,r.id AS route_ref,r.owner_sub AS route_owner,
     r.route_date,p.scope_kind,p.scope_key
    FROM public.field_day_routes r
    JOIN public.field_monthly_plans p ON p.id=r.monthly_plan_id
    LEFT JOIN public.field_work_sessions s ON s.day_route_id=r.id
    WHERE r.id=${id}::uuid AND
     (r.owner_sub=${actor.sub} OR ${actor.admin} OR
      (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},r.owner_sub)))
    LIMIT 1`;
   if(!rows.length)return fail('SCOPE_REVOKED','Không tìm thấy tuyến hoặc không có quyền.',404);
   const item=rows[0];
   return response({item:item.id?item:null,
    state:item.id?item.state:'open',route_id:id});
  }
  if(req.method==='POST'){
   let v:Record<string,unknown>;try{v=await body(req);}
   catch{return fail('INVALID_WORK_SESSION','JSON phiên không hợp lệ.');}
   if(!hasUuid(v.client_ref)||!isoTime(v.captured_at))
    return fail('INVALID_WORK_SESSION','Thiếu mã thao tác hoặc thời gian.');
   try{
    const data=await db`SELECT public.sales_start_work_session(
     ${actor.sub},${v.client_ref}::uuid,${id}::uuid,
     ${v.captured_at}::timestamptz) AS item`;
    const item=data[0].item as Record<string,unknown>;
    return response({item,already_saved:item.already_saved===true},
     item.already_saved===true?200:201);
   }catch(e){return failure(e);}
  }
  return fail('INVALID_METHOD','Method not allowed',405);
 }
 const id=session![1];if(!uuid.test(id))
  return fail('INVALID_WORK_SESSION','Mã phiên không hợp lệ.');
 if(session![2]==='close'&&req.method==='POST'){
  let v:Record<string,unknown>;try{v=await body(req);}
  catch{return fail('INVALID_WORK_SESSION','JSON phiên không hợp lệ.');}
  if(!hasUuid(v.client_ref)||!isoTime(v.captured_at)||
   !Number.isInteger(v.version)||Number(v.version)<1||
   !['done','cancelled'].includes(String(v.action))||
   typeof(v.note??'')!=='string'||String(v.note??'').length>2000)
   return fail('INVALID_WORK_SESSION','Trạng thái hoặc phiên bản đóng phiên không hợp lệ.');
  try{
   const data=await db`SELECT public.sales_close_work_session(
    ${actor.sub},${id}::uuid,${v.client_ref}::uuid,
    ${Number(v.version)},${String(v.action)},
    ${v.captured_at}::timestamptz,${String(v.note??'')}) AS item`;
   const item=data[0].item as Record<string,unknown>;
   return response({item,already_saved:item.already_saved===true});
  }catch(e){return failure(e);}
 }
 if(session![2]===undefined&&req.method==='DELETE'){
  let v:Record<string,unknown>;try{v=await body(req);}
  catch{return fail('INVALID_WORK_SESSION','JSON phiên không hợp lệ.');}
  if(!hasUuid(v.client_ref)||v.confirm!=='DELETE_EMPTY'||
   !Number.isInteger(v.version)||Number(v.version)<1)
   return fail('INVALID_WORK_SESSION','Phải xác nhận xóa phiên rỗng với phiên bản hiện tại.');
  try{
   const data=await db`SELECT public.sales_delete_empty_work_session(
    ${actor.sub},${id}::uuid,${v.client_ref}::uuid,
    ${Number(v.version)},${String(v.confirm)}) AS item`;
   return response({item:data[0].item});
  }catch(e){return failure(e);}
 }
 return fail('INVALID_METHOD','Method not allowed',405);
}
