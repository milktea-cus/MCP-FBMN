import {neon} from '@neondatabase/serverless';
import type {AuthEnv} from './auth';
type Actor={sub:string;admin:boolean;manager:boolean};
const json=(v:unknown,status=200)=>new Response(JSON.stringify(v),{
 status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const fail=(error:string,status=400)=>json({error},status);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export async function routeTemplateRoutes(req:Request,env:AuthEnv,actor:Actor,url:URL):Promise<Response|null>{
 if(url.pathname!=='/api/v1/route-templates'&&
  !/^\/api\/v1\/route-templates\/[a-f0-9-]{36}$/i.test(url.pathname))return null;
 const match=/^\/api\/v1\/route-templates\/([a-f0-9-]{36})$/i.exec(url.pathname);
 if(match&&!uuid.test(match[1]))return fail('UUID mẫu tuyến không hợp lệ');
 const db=neon(env.DATABASE_URL);
 if(req.method==='GET'&&!match){
  const items=await db`SELECT t.* FROM public.field_route_templates t
   WHERE (t.owner_sub=${actor.sub} AND public.sales_monthly_plan_scope_allowed(
      ${actor.sub},t.scope_kind,t.scope_key,t.province,t.district))
    OR ${actor.admin}
    OR (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},t.owner_sub))
   ORDER BY t.updated_at DESC,t.id LIMIT 300`;
  return json({items});
 }
 if(!((req.method==='POST'&&!match)||(req.method==='PATCH'&&match)))
  return fail('Method not allowed',405);
 let body:Record<string,unknown>;
 try{
  if(!req.headers.get('Content-Type')?.includes('application/json'))throw Error('content type');
  const raw=await req.text();if(raw.length>90000)throw Error('size');
  const parsed=JSON.parse(raw) as unknown;
  if(!parsed||typeof parsed!=='object'||Array.isArray(parsed))throw Error('object');
  body=parsed as Record<string,unknown>;
 }catch{return fail('Dữ liệu mẫu tuyến không hợp lệ');}
 const update=!!match;
 const id=update?match[1]:String(body.client_ref);
 if(!uuid.test(id)||!uuid.test(String(body.client_ref??''))||
  typeof body.name!=='string'||body.name.trim().length<2||body.name.length>120||
  !['territory','chain'].includes(String(body.scope_kind))||
  typeof body.scope_key!=='string'||body.scope_key.length>160||
  !Array.isArray(body.stops)||body.stops.length<1||body.stops.length>100||
  (update?(!Number.isInteger(body.version)||Number(body.version)<1):
   (body.version!==undefined&&body.version!==0)))return fail('Tên, điểm ghé hoặc phiên bản mẫu không hợp lệ');
 try{
  const x=await db`SELECT public.sales_save_route_template(
   ${actor.sub},${id}::uuid,${body.client_ref as string}::uuid,
   ${update?Number(body.version):0},${body.name as string},
   ${body.scope_kind as string},${body.scope_key as string},
   ${body.scope_kind==='territory'?String(body.province??''):null},
   ${body.scope_kind==='territory'?String(body.district??''):null},
   ${JSON.stringify(body.stops)}::jsonb) AS item`;
  return json({item:x[0].item},update?200:201);
 }catch(e){
  const msg=(e as Error).message??'';
  if(msg.includes('permission'))return fail('Mẫu ngoài phạm vi kinh doanh trực tiếp',403);
  if(msg.includes('stale')||msg.includes('duplicate')||(e as {code?:string}).code==='23505')
   return fail('Mẫu thay đổi, thứ tự trùng hoặc UUID đã dùng',409);
  if(msg.includes('invalid'))return fail('Mẫu tuyến có điểm ghé không hợp lệ');
  return fail('Không lưu được mẫu tuyến',503);
 }
}
