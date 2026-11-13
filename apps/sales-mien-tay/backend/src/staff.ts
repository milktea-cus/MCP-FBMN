import { neon } from '@neondatabase/serverless';
import districts from './districts_old.json';
import {AuthError,changeStaffEmail,type AuthEnv} from './auth';
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
 if(typeof data?.job_title!=='string'||data.job_title.trim().length>120)return json({error:'Chức danh không hợp lệ (tối đa 120 ký tự).'},400);
 if(!data || typeof data.user_sub!=='string'|| !/^[0-9a-f-]{36}$/i.test(data.user_sub)||typeof data.employee_code!=='string'||!data.employee_code.trim()||data.employee_code.length>80||typeof data.full_name!=='string'||!data.full_name.trim()||data.full_name.length>240||!['admin','manager','sales'].includes(String(data.role))||typeof data.active!=='boolean'||!Array.isArray(data.scopes)||data.scopes.length>1000)return json({error:'Thông tin nhân viên không hợp lệ'},400);
 const configured=await db`SELECT t.name,t.level,p.name AS province FROM public.territory_catalog t
   LEFT JOIN public.territory_catalog p ON p.code=t.parent_code WHERE t.active`;
 const extended=new Map<string,Set<string>>();
 for(const row of configured)if(row.level==='province')extended.set(String(row.name),new Set());
 for(const row of configured)if(row.level==='district'&&row.province)
   extended.get(String(row.province))?.add(String(row.name));
 const scopes=new Map<string,{province:string;district:string}>();
 for(const scope of data.scopes){
  if(!scope||typeof scope.province!=='string'||typeof scope.district!=='string'||(!areas[scope.province]&&!extended.has(scope.province))||(scope.district!==''&&!areas[scope.province]?.includes(scope.district)&&!extended.get(scope.province)?.has(scope.district)))return json({error:'Địa bàn không hợp lệ'},400);
  scopes.set(scope.province+'|'+scope.district,{province:scope.province,district:scope.district});
 }
 const canonical=[...scopes.values()].filter(s=>s.district===''||!scopes.has(s.province+'|'));
 const manager=data.manager_sub??null;
 if(manager!==null&&(typeof manager!=='string'||manager===data.user_sub||!['sales','manager'].includes(String(data.role))))return json({error:'Quản lý trực tiếp không hợp lệ'},400);
 try{
  const email=typeof data.email==='string'?data.email.trim().toLowerCase():null;
  if(email!==null&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))return json({error:'Email không hợp lệ'},400);
  const old=(await db`SELECT email,scope_revision,role,active FROM staff_members WHERE user_sub=${data.user_sub}`)[0];
  if(old&&email&&email!==String(old.email).toLowerCase()){
   if(actor.sub===data.user_sub)return json({error:'Không đổi email của chính Admin đang đăng nhập tại đây. Dùng một Admin khác để đổi an toàn.'},409);
   if(String(old.scope_revision)!==String(data.scope_revision??'0'))return json({error:'Hồ sơ đã thay đổi, mở lại trước khi lưu.'},409);
   if((await db`SELECT 1 FROM staff_members WHERE lower(email)=${email} AND user_sub<>${data.user_sub}`).length)return json({error:'Email đã được sử dụng.'},409);
   if((await db`SELECT 1 FROM staff_members WHERE employee_code=${data.employee_code.trim()} AND user_sub<>${data.user_sub}`).length)return json({error:'Mã nhân viên đã tồn tại.'},409);
   if(manager!==null&&!(await db`SELECT 1 FROM staff_members WHERE user_sub=${manager as string} AND role='manager' AND active`).length)return json({error:'Quản lý trực tiếp không hợp lệ.'},400);
   if(old.role==='admin'&&old.active&&(!data.active||data.role!=='admin')&&!(await db`SELECT 1 FROM staff_members WHERE role='admin' AND active AND user_sub<>${data.user_sub}`).length)return json({error:'Không được khóa hoặc hạ quyền Admin cuối cùng.'},409);
   await changeStaffEmail(req,data.user_sub,email);
  }
  const result=await db`SELECT public.sales_save_staff(${actor.sub},${data.user_sub},${data.employee_code.trim()},${data.full_name.trim()},${String(data.phone??'')},${String(data.role)},${data.active},${manager as string|null},${JSON.stringify(canonical)}::jsonb,${String(data.scope_revision??'0')}::bigint,${(data.job_title as string).trim()}) AS item`;
  if(email&&String(result[0].item?.staff?.email??'').toLowerCase()!==email)return json({error:'Email xác thực chưa đồng bộ. Mở lại hồ sơ và thử lại.'},409);
  return json({item:result[0].item});
 }catch(e){
  if(e instanceof AuthError)return json({error:e.message},e.status);
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
