import {neon} from '@neondatabase/serverless';
import type {AuthEnv} from './auth';
import {normalizeLocalScopes,legacyWeeklyScope} from './local_multi_scopes';
type Actor={sub:string;admin:boolean;manager:boolean};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{
 status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const fail=(error:string,status=400)=>json({error},status);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function validDay(v:unknown):v is string{
 return typeof v==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(v)&&
  !Number.isNaN(Date.parse(v))&&new Date(v).toISOString().slice(0,10)===v;
}
export function validLocalRule(v:Record<string,unknown>,edit:boolean):string|null{
 const scopes=v.scopes===undefined?legacyWeeklyScope(v):normalizeLocalScopes(v.scopes);
 if(!uuid.test(String(v.client_ref??''))||
  typeof v.name!=='string'||v.name.trim().length<2||v.name.length>120||
  !['day','week'].includes(String(v.mode))||
  scopes===null||
  !validDay(v.start_on)||typeof v.active!=='boolean'||
  !Array.isArray(v.weekdays)||v.weekdays.length<1||v.weekdays.length>7||
  v.weekdays.some(n=>!Number.isInteger(n)||n<1||n>7)||
  new Set(v.weekdays).size!==v.weekdays.length||
  (v.mode==='day'&&v.weekdays.length!==1)||
  (edit?(!Number.isInteger(v.version)||Number(v.version)<1):
   (v.version!==undefined&&v.version!==0)))
  return 'Tên, ngày lặp, địa bàn hoặc phiên bản không hợp lệ';
 return null;
}
export async function localRouteRoutes(req:Request,env:AuthEnv,actor:Actor,url:URL):Promise<Response|null>{
 const base='/api/v1/local-routes';
 if(url.pathname!==base&&!/^\/api\/v1\/local-routes\/[a-f0-9-]{36}$/i.test(url.pathname))return null;
 const match=/^\/api\/v1\/local-routes\/([a-f0-9-]{36})$/i.exec(url.pathname);
 if(match&&!uuid.test(match[1]))return fail('ID tuyến không hợp lệ');
 const db=neon(env.DATABASE_URL);
 if(req.method==='GET'&&!match){
  const items=await db`SELECT t.* FROM public.field_local_route_rules t
   WHERE t.owner_sub=${actor.sub} AND public.sales_local_scopes_allowed(${actor.sub},t.scopes)
   ORDER BY t.active DESC,t.updated_at DESC,t.id LIMIT 300`;
  return json({items});
 }
 if(!((req.method==='POST'&&!match)||(req.method==='PATCH'&&match)))
  return fail('Method not allowed',405);
 let body:Record<string,unknown>;
 try{
  if(!req.headers.get('Content-Type')?.includes('application/json'))throw Error('json');
  const raw=await req.text();if(raw.length>12000)throw Error('length');
  const v:unknown=JSON.parse(raw);if(!v||typeof v!=='object'||Array.isArray(v))throw Error('object');
  body=v as Record<string,unknown>;
 }catch{return fail('Dữ liệu tuyến cố định không hợp lệ');}
 const editing=!!match,issue=validLocalRule(body,!!match);
 if(issue)return fail(issue);
 const id=editing?match![1]:String(body.client_ref);
 if(!uuid.test(id)||(editing&&body.id!==undefined&&body.id!==id))
  return fail('ID tuyến cố định không hợp lệ');
 const scopes=body.scopes===undefined?legacyWeeklyScope(body):normalizeLocalScopes(body.scopes);
 if(!scopes)return fail('Phạm vi tuyến không hợp lệ');
 if(editing&&body.scopes===undefined){
  const existing=await db`SELECT 1 FROM public.field_local_route_rules
   WHERE id=${id}::uuid AND owner_sub=${actor.sub} AND jsonb_array_length(scopes)>1`;
  if(existing.length)return fail('Vui lòng cập nhật ứng dụng để sửa tuyến có nhiều phạm vi',409);
 }
 try{
  const rows=await db`SELECT public.sales_save_local_route_rule_v2(
   ${actor.sub},${id}::uuid,${body.client_ref as string}::uuid,
   ${editing?Number(body.version):0},${body.name as string},${body.mode as string},
   ${JSON.stringify(body.weekdays)}::jsonb,${JSON.stringify(scopes)}::jsonb,
   ${body.start_on as string}::date,${body.active as boolean}) AS item`;
  return json({item:rows[0].item},editing?200:201);
 }catch(e){
  const m=(e as {message?:string;code?:string}).message??'';
  if(/PERMISSION|FORBIDDEN/.test(m))return fail('Tuyến ngoài địa bàn được giao',403);
  if(/STALE|duplicate/i.test(m)||(e as {code?:string}).code==='23505')
   return fail('Tuyến đã được sửa từ nơi khác; cần tải lại',409);
  if(/INVALID/.test(m))return fail('Dữ liệu tuyến cố định không hợp lệ');
  return fail('Không lưu được tuyến cố định',503);
 }
}
