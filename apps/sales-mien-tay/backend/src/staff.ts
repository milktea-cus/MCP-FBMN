import { neon } from '@neondatabase/serverless';
import districts from './districts_old.json';
import type { AuthEnv } from './auth';
const areas=districts as Record<string,string[]>;
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
export async function staffRoutes(req:Request,env:AuthEnv,actor:{sub:string;admin:boolean},url:URL):Promise<Response|null>{
 if(url.pathname!=='/api/v1/admin/staff')return null;
 if(!actor.admin)return json({error:'Chỉ Admin quản lý nhân viên'},403);
 const db=neon(env.DATABASE_URL);
 if(req.method==='GET'){
  const items=await db`SELECT m.*,coalesce((SELECT jsonb_agg(jsonb_build_object('province',s.province,'district',s.district) ORDER BY s.province,s.district) FROM staff_scopes s WHERE s.user_sub=m.user_sub),'[]'::jsonb) AS scopes FROM staff_members m ORDER BY employee_code`;
  return json({items});
 }
 if(req.method!=='POST')return json({error:'Method not allowed'},405);
 let data:Record<string,unknown>;try{const raw=await req.text();if(raw.length>64000)throw Error();data=JSON.parse(raw);}catch{return json({error:'JSON không hợp lệ'},400);}
 if(!data || typeof data.user_sub!=='string'|| !/^[0-9a-f-]{36}$/i.test(data.user_sub)||typeof data.employee_code!=='string'||!data.employee_code.trim()||data.employee_code.length>80||typeof data.full_name!=='string'||!data.full_name.trim()||data.full_name.length>240||!['admin','manager','sales'].includes(String(data.role))||typeof data.active!=='boolean'||!Array.isArray(data.scopes)||data.scopes.length>134)return json({error:'Thông tin nhân viên không hợp lệ'},400);
 const scopes=new Map<string,{province:string;district:string}>();
 for(const scope of data.scopes){
  if(!scope||typeof scope.province!=='string'||typeof scope.district!=='string'||!areas[scope.province]||(scope.district!==''&&!areas[scope.province].includes(scope.district)))return json({error:'Địa bàn không hợp lệ'},400);
  scopes.set(scope.province+'|'+scope.district,{province:scope.province,district:scope.district});
 }
 const canonical=[...scopes.values()].filter(s=>s.district===''||!scopes.has(s.province+'|'));
 const manager=data.manager_sub??null;
 if(manager!==null&&(typeof manager!=='string'||manager===data.user_sub||data.role!=='sales'))return json({error:'Quản lý trực tiếp không hợp lệ'},400);
 try{
  const result=await db`SELECT public.sales_save_staff(${actor.sub},${data.user_sub},${data.employee_code.trim()},${data.full_name.trim()},${String(data.phone??'')},${String(data.role)},${data.active},${manager as string|null},${JSON.stringify(canonical)}::jsonb,${String(data.scope_revision??'0')}::bigint) AS item`;
  return json({item:result[0].item});
 }catch(e){
  const err=e as {message?:string;code?:string};
  const msg=err.message??'';
  if(msg.includes('stale revision'))return json({error:'Hồ sơ đã thay đổi. Hủy và mở lại nhân viên để lưu phiên bản mới nhất.'},409);
  if(msg.includes('last admin'))return json({error:'Không được khóa hoặc hạ quyền Admin cuối cùng.'},409);
  if(msg.includes('invalid manager'))return json({error:'Quản lý trực tiếp không hợp lệ hoặc đã bị khóa.'},400);
  if(msg.includes('provisioned identity required'))return json({error:'Tài khoản xác thực chưa tồn tại hoặc đã bị khóa.'},409);
  if(msg.includes('admin required'))return json({error:'Quyền Admin đã bị thu hồi.'},403);
  if(err.code==='23505')return json({error:'Mã nhân viên hoặc email đã tồn tại.'},409);
  if(err.code==='23514'||err.code==='23503'||err.code==='22P02')return json({error:'Thông tin nhân viên hoặc địa bàn không hợp lệ.'},400);
  return json({error:'Không lưu được hồ sơ do lỗi hệ thống. Vui lòng thử lại.'},503);
 }
}
