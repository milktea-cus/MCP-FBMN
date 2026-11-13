import {neon} from '@neondatabase/serverless';
import type {AuthEnv} from './auth';

// Every scope mutation is authorized a second time by the database function.
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const fail=(message:string,status=400)=>json({error:message},status);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const kinds=['territory','team','chain','staff','customer'];
export const orgGrantActions=['view','create','edit','transfer','approve','target','actuals','report','export','media','staff_manage'] as const;
const bindingKinds=['territory','team','chain','staff'];
function validString(x:unknown,max=240):x is string{return typeof x==='string'&&x.trim().length>0&&x.trim().length<=max;}
async function body(req:Request){
 if(!req.headers.get('content-type')?.includes('application/json'))throw Error('json');
 const raw=await req.text();if(raw.length>8000)throw Error('size');
 const value=JSON.parse(raw) as unknown;
 if(!value||typeof value!=='object'||Array.isArray(value))throw Error('object');
 return value as Record<string,unknown>;
}
function errorFromDb(e:unknown):Response{
 const msg=(e as {message?:string;code?:string})?.message??'';
 if(msg.includes('admin required'))return fail('Quyền quản trị đã bị thu hồi',403);
 if(msg.includes('invalid')||msg.includes('customer not found'))return fail('Phạm vi hoặc đối tượng không hợp lệ',400);
 if((e as {code?:string})?.code==='23505')return fail('Dữ liệu đã tồn tại',409);
 return fail('Không cập nhật được phân quyền. Vui lòng thử lại.',503);
}
export async function orgRoutes(req:Request,env:AuthEnv,actor:{sub:string;admin:boolean},url:URL):Promise<Response|null>{
 if(!url.pathname.startsWith('/api/v1/admin/org'))return null;
 if(!actor.admin)return fail('Chỉ Admin có quyền cấu hình tổ chức',403);
 const suffix=url.pathname.slice('/api/v1/admin/org'.length);
 const db=neon(env.DATABASE_URL);
 if(req.method==='GET'&&suffix===''){
  const [staff,grants,teams,chains,teamMembers]=await Promise.all([
   db`SELECT user_sub,employee_code,full_name,role,active,manager_sub,scope_revision,job_title FROM public.staff_members ORDER BY employee_code LIMIT 5000`,
   db`SELECT id,grantee_sub,scope_kind,scope_key,action,active,granted_at,updated_at FROM public.scope_grants ORDER BY updated_at DESC LIMIT 2000`,
   db`SELECT id,name FROM public.org_teams ORDER BY name LIMIT 500`,
   db`SELECT id,name FROM public.customer_chains ORDER BY name LIMIT 500`,
   db`SELECT team_id,user_sub FROM public.org_team_members LIMIT 5000`
  ]);
  return json({staff,grants,teams,chains,team_members:teamMembers});
 }
 if(req.method==='GET'&&suffix==='/territories'){
  const items=await db`SELECT t.name,t.level,p.name AS province FROM public.territory_catalog t
   LEFT JOIN public.territory_catalog p ON p.code=t.parent_code
   WHERE t.active ORDER BY t.level DESC,t.name LIMIT 6000`;
  return json({items});
 }
 if(req.method==='GET'&&suffix==='/customers'){
  const query=(url.searchParams.get('q')??'').trim();if(query.length>80)return fail('Từ khóa quá dài');
  const limit=50;
  const rows=await db`SELECT c.id,c.name,c.code,c.owner_sub,c.created_by_sub,c.province,c.district,
   coalesce((SELECT jsonb_agg(jsonb_build_object('scope_kind',b.scope_kind,'scope_key',b.scope_key,'active',b.active))
    FROM public.customer_scope_bindings b WHERE b.customer_id=c.id),'[]'::jsonb) AS bindings
   FROM public.customers c WHERE (${!query} OR c.name ILIKE '%'||${query}||'%' OR c.code ILIKE '%'||${query}||'%')
   ORDER BY c.name,c.id LIMIT ${limit}`;
  return json({items:rows,limit});
 }
 if(req.method==='GET'&&suffix==='/preview'){
  const kind=url.searchParams.get('scope_kind')??'',key=url.searchParams.get('scope_key')??'';
  if(!kinds.includes(kind)||!validString(key))return fail('Phạm vi không hợp lệ');
  const rows=await db`SELECT c.id,c.name,c.province,c.district,c.owner_sub
   FROM public.customers c WHERE
    (${kind==='customer'} AND c.id::text=${key})
    OR (${kind==='staff'} AND (public.sales_staff_in_subtree(${key},c.owner_sub)
     OR EXISTS(SELECT 1 FROM public.customer_scope_bindings b WHERE b.customer_id=c.id AND b.active AND b.scope_kind='staff' AND b.scope_key=${key})))
    OR (${kind==='territory'||kind==='team'||kind==='chain'} AND EXISTS(
     SELECT 1 FROM public.customer_scope_bindings b WHERE b.customer_id=c.id AND b.active AND b.scope_kind=${kind} AND b.scope_key=${key}
       AND (${kind!=='territory'} OR b.scope_key IN (c.province||'|',c.province||'|'||c.district))))
    ORDER BY c.name,c.id LIMIT 101`;
  return json({items:rows.slice(0,100),has_more:rows.length>100});
 }
 if(req.method!=='POST')return fail('Method not allowed',405);
 let data:Record<string,unknown>;try{data=await body(req);}catch{return fail('JSON không hợp lệ');}
 try{
  if(suffix==='/territories'){
   if(!['province','district'].includes(String(data.level))||
      !validString(data.name,100)||typeof data.name!=='string'||data.name.includes('|')||
      (data.level==='province'&&data.province!==undefined)||
      (data.level==='district'&&!validString(data.province,100)))
      return fail('Tỉnh/huyện không hợp lệ');
   const result=await db`SELECT public.sales_add_territory(${actor.sub},
     ${data.level as string},${(data.name as string).trim()},
     ${data.level==='province'?null:(data.province as string).trim()}) AS item`;
   return json({item:result[0].item},201);
  }
  if(suffix==='/units'){
   if(!['team','chain'].includes(String(data.kind))||!validString(data.name,160))return fail('Tên nhóm/chuỗi không hợp lệ');
   const result=await db`SELECT public.sales_create_org_unit(${actor.sub},${data.kind as string},${(data.name as string).trim()}) AS item`;
   return json({item:result[0].item},201);
  }
  if(suffix==='/grants'){
   if(!validString(data.grantee_sub,150)||!kinds.includes(String(data.scope_kind))||
      !validString(data.scope_key)||!orgGrantActions.includes(data.action as typeof orgGrantActions[number])||
      typeof data.active!=='boolean')return fail('Quyền không hợp lệ');
   if(data.scope_kind==='customer'&&!uuid.test(data.scope_key as string))return fail('Mã khách không hợp lệ');
   if((data.scope_kind==='team'||data.scope_kind==='chain')&&!uuid.test(data.scope_key as string))return fail('Mã nhóm/chuỗi không hợp lệ');
   const result=await db`SELECT public.sales_set_scope_grant(${actor.sub},${data.grantee_sub as string},${data.scope_kind as string},${data.scope_key as string},${data.action as string},${data.active}) AS item`;
   return json({item:result[0].item});
  }
  if(suffix==='/bindings'){
   if(!uuid.test(String(data.customer_id))||!bindingKinds.includes(String(data.scope_kind))||
      !validString(data.scope_key)||typeof data.active!=='boolean')return fail('Phân công khách không hợp lệ');
   if((data.scope_kind==='team'||data.scope_kind==='chain')&&!uuid.test(data.scope_key as string))return fail('Mã nhóm/chuỗi không hợp lệ');
   const result=await db`SELECT public.sales_set_customer_binding(${actor.sub},${data.customer_id as string}::uuid,${data.scope_kind as string},${data.scope_key as string},${data.active}) AS item`;
   return json({item:result[0].item});
  }
  if(suffix==='/members'){
   if(!uuid.test(String(data.team_id))||!validString(data.user_sub,150)||typeof data.active!=='boolean')return fail('Thành viên không hợp lệ');
   const result=await db`SELECT public.sales_set_team_member(${actor.sub},${data.team_id as string}::uuid,${data.user_sub as string},${data.active}) AS item`;
   return json({item:result[0].item});
  }
  return fail('Endpoint không tồn tại',404);
 }catch(e){return errorFromDb(e);}
}
