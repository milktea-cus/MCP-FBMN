import {neon} from '@neondatabase/serverless';
import type {AuthEnv} from './auth';
import districts from './districts_old.json';

type Actor={sub:string;admin:boolean;manager:boolean};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const fail=(error:string,status=400)=>json({error},status);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const validMonth=(s:string)=>/^\d{4}-(0[1-9]|1[0-2])$/.test(s);
const validDay=(s:string)=>/^\d{4}-\d{2}-\d{2}$/.test(s)&&Number.isFinite(Date.parse(s))&&new Date(s).toISOString().slice(0,10)===s;
const areas=districts as Record<string,string[]>;
async function parseBody(req:Request):Promise<Record<string,unknown>>{
 if(!req.headers.get('Content-Type')?.includes('application/json'))throw Error('JSON required');
 const raw=await req.text();if(raw.length>16000)throw Error('Body too large');
 const value=JSON.parse(raw) as unknown;
 if(!value||typeof value!=='object'||Array.isArray(value))throw Error('Object required');
 return value as Record<string,unknown>;
}
export function validateMonthPlan(v:Record<string,unknown>,editing:boolean):string|null{
 const month=v.period_ym,date=v.work_date,kind=v.scope_kind,key=v.scope_key;
 if(typeof month!=='string'||!validMonth(month)||typeof date!=='string'||!validDay(date)||date.slice(0,7)!==month)return 'Ngày phải nằm trong tháng kế hoạch';
 if((kind!=='territory'&&kind!=='chain'&&kind!=='customer')||typeof key!=='string'||!key||key.length>240)return 'Phạm vi không hợp lệ';
 if(kind==='territory'&&(typeof v.province!=='string'||!v.province||typeof v.district!=='string'||key!==v.province+'|'+v.district))return 'Địa bàn không hợp lệ';
 if((kind==='chain'||kind==='customer')&&(v.province!=null||v.district!=null||!uuid.test(key)))return 'Chuỗi hoặc khách hàng không hợp lệ';
 if(typeof v.purpose!=='string'||v.purpose.trim().length<2||v.purpose.length>500)return 'Mục đích phải có 2–500 ký tự';
 if(typeof v.target_new_customers!=='number'||!Number.isInteger(v.target_new_customers)||v.target_new_customers<0||v.target_new_customers>9999)return 'Chỉ tiêu khách mới không hợp lệ';
 if(v.note!=null&&(typeof v.note!=='string'||v.note.length>2000))return 'Ghi chú quá dài';
 if(v.status!=null&&!['planned','cancelled'].includes(String(v.status)))return 'Trạng thái không hợp lệ';
 if(typeof v.client_ref!=='string'||!uuid.test(v.client_ref))return 'UUID thao tác không hợp lệ';
 if(editing?(!Number.isInteger(v.version)||Number(v.version)<1):(v.version!==undefined&&v.version!==0))return 'Phiên bản kế hoạch không hợp lệ';
 return null;
}
export async function monthlyPlanRoutes(req:Request,env:AuthEnv,actor:Actor,url:URL):Promise<Response|null>{
 if(!url.pathname.startsWith('/api/v1/monthly-plans'))return null;
 const suffix=url.pathname.slice('/api/v1/monthly-plans'.length);
 const db=neon(env.DATABASE_URL);
 if(suffix==='/options'&&req.method==='GET'){
  const [owned,chains,configured,customers]=await Promise.all([
   actor.admin?Promise.resolve([]):db`SELECT province,district FROM public.staff_scopes WHERE user_sub=${actor.sub} ORDER BY province,district`,
   db`SELECT c.id::text AS key,c.name AS label FROM public.customer_chains c
    WHERE ${actor.admin} OR EXISTS(SELECT 1 FROM public.staff_business_assignments a
      WHERE a.user_sub=${actor.sub} AND a.scope_kind='chain' AND a.scope_key=c.id::text AND a.active)
    ORDER BY c.name LIMIT 1000`,
   db`SELECT t.name,t.level,p.name AS province FROM public.territory_catalog t
     LEFT JOIN public.territory_catalog p ON p.code=t.parent_code
     WHERE t.active AND t.level IN ('province','district') LIMIT 7000`,
   db`SELECT c.id::text AS key,c.name AS label,c.province,c.district
    FROM public.customers c WHERE public.sales_customer_plannable(${actor.sub},c.id)
    ORDER BY c.name,c.id LIMIT 2000`
  ]);
  const scopes=new Map<string,{scope_kind:string;scope_key:string;province:string;district:string;label:string}>();
  const add=(province:string,district:string)=>{
   if(!province||province.includes('|')||district.includes('|'))return;
   const key=province+'|'+district;
   scopes.set(key,{scope_kind:'territory',scope_key:key,province,district,label:district?district+' · '+province:'Toàn tỉnh · '+province});
  };
  if(actor.admin){
   for(const [p,ds] of Object.entries(areas)){add(p,'');for(const d of ds)add(p,d);}
   for(const t of configured){if(t.level==='province')add(String(t.name),'');else if(t.province)add(String(t.province),String(t.name));}
  }else for(const s of owned){
   const p=String(s.province),district=String(s.district);add(p,district);
   // Province-wide responsibility allows planning individual districts too.
   if(district===''){
    for(const name of areas[p]??[])add(p,name);
    for(const t of configured)if(t.level==='district'&&t.province===p)add(p,String(t.name));
   }
  }
  return json({scopes:[...scopes.values(),...chains.map(c=>({scope_kind:'chain',scope_key:String(c.key),province:null,district:null,label:'Chuỗi · '+String(c.label)})),
   ...customers.map(c=>({scope_kind:'customer',scope_key:String(c.key),province:null,district:null,
     label:'Khách · '+String(c.label)+' · '+String(c.district)+', '+String(c.province)}))]});
 }
 if(suffix==='/candidates'&&req.method==='GET'){
  const kind=url.searchParams.get('scope_kind')??'',key=url.searchParams.get('scope_key')??'';
  if(!['territory','chain','customer'].includes(kind)||!key||key.length>240 ||
     (kind!=='territory'&&!uuid.test(key))||(kind==='territory'&&!key.includes('|')))
    return fail('Phạm vi không hợp lệ');
  const split=key.indexOf('|'),province=kind==='territory'?key.slice(0,split):null;
  const district=kind==='territory'?key.slice(split+1):null;
  const access=await db`SELECT public.sales_monthly_plan_scope_allowed(
    ${actor.sub},${kind},${key},${province},${district}) AS allowed`;
  if(access[0]?.allowed!==true)return fail('Ngoài phạm vi được phân công',403);
  const rows=await db`SELECT c.id,c.name,c.code,c.category,c.province,c.district
   FROM public.customers c
   WHERE public.sales_customer_plannable(${actor.sub},c.id)
     AND ((${kind}='territory' AND c.province=${province}
            AND (${district}='' OR c.district=${district}))
       OR (${kind}='chain' AND EXISTS(SELECT 1 FROM public.customer_scope_bindings b
          WHERE b.customer_id=c.id AND b.active AND b.scope_kind='chain' AND b.scope_key=${key}))
       OR (${kind}='customer' AND c.id::text=${key}))
   ORDER BY c.name,c.id LIMIT 1001`;
  return json({items:rows.slice(0,1000),truncated:rows.length>1000});
 }
 if(suffix===''&&req.method==='GET'){
  const month=url.searchParams.get('month')??'';
  if(!validMonth(month))return fail('Tháng không hợp lệ');
  const items=await db`SELECT p.* FROM public.field_monthly_plans p
   WHERE p.period_ym=${month} AND
     (p.owner_sub=${actor.sub} OR ${actor.admin} OR
      (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},p.owner_sub)))
   ORDER BY p.work_date,p.created_at,p.id LIMIT 3000`;
  return json({items});
 }
 const match=/^\/([0-9a-f-]{36})$/i.exec(suffix);
 if(match&&req.method==='DELETE'){
  if(!uuid.test(match[1]))return fail('ID lịch không hợp lệ');
  const version=Number(url.searchParams.get('version'));
  if(!Number.isInteger(version)||version<1)return fail('Thiếu phiên bản lịch cần xóa');
  try{
   const rows=await db`SELECT public.sales_archive_monthly_plan(
    ${actor.sub},${match[1]}::uuid,${version}) AS result`;
   return json(rows[0].result);
  }catch(e){
   const message=(e as {message?:string}).message??'';
   if(message.includes('archive_forbidden'))return fail('Chỉ người phụ trách có quyền xóa lịch này',403);
   if(message.includes('archive_not_found'))return fail('Không tìm thấy lịch đã chọn',404);
   if(message.includes('archive_stale'))return fail('Lịch đã thay đổi; tải lại trước khi xóa',409);
   return fail('Không xóa được lịch; dữ liệu cũ vẫn được giữ nguyên',503);
  }
 }
 if(!((suffix===''&&req.method==='POST')||(match&&req.method==='PATCH')))return fail('Method not allowed',405);
 let v:Record<string,unknown>;try{v=await parseBody(req);}catch{return fail('JSON không hợp lệ');}
 const editing=!!match;
 const invalid=validateMonthPlan(v,editing);if(invalid)return fail(invalid);
 const id=editing?match![1]:String(v.client_ref);
 if(editing&&(!uuid.test(id)||(v.id!==undefined&&v.id!==id)))return fail('ID kế hoạch không hợp lệ');
 const province=v.scope_kind==='territory'?String(v.province):null;
 const district=v.scope_kind==='territory'?String(v.district):null;
 if(v.scope_kind==='territory'){
  const p=province!,d=district!;
  const listed=areas[p]?.includes(d)||(d===''&&p in areas);
  if(!listed){
   const catalog=await db`SELECT 1 FROM public.territory_catalog p WHERE p.name=${p}
    AND p.level='province' AND p.active AND
    (${d}='' OR EXISTS(SELECT 1 FROM public.territory_catalog t
      WHERE t.parent_code=p.code AND t.name=${d} AND t.level='district' AND t.active)) LIMIT 1`;
   if(!catalog.length)return fail('Địa bàn không có trong danh mục');
  }
 }
 try{
  const rows=await db`SELECT public.sales_save_monthly_plan(
   ${actor.sub},${id}::uuid,${String(v.client_ref)}::uuid,${editing?Number(v.version):0},
   ${String(v.period_ym)},${String(v.scope_kind)},${String(v.scope_key)},
   ${province},${district},${String(v.work_date)}::date,${String(v.purpose).trim()},
   ${Number(v.target_new_customers)},${String(v.note??'')},${String(v.status??'planned')}) AS item`;
  return json({item:rows[0].item},editing?200:201);
 }catch(e){
  const message=(e as {message?:string;code?:string}).message??'';
  if(message.includes('scope')||message.includes('forbidden'))return fail('Ngoài phạm vi kinh doanh được giao trực tiếp',403);
  if(message.includes('stale')||(e as {code?:string}).code==='23505')return fail('Kế hoạch đã thay đổi hoặc trùng ngày/phạm vi',409);
  return fail('Không lưu được kế hoạch tháng',503);
 }
}
