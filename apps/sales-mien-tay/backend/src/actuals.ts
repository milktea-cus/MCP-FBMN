import {neon} from '@neondatabase/serverless';
import type {userFromRequest} from './auth';
type User=Awaited<ReturnType<typeof userFromRequest>>;
type Obj=Record<string,unknown>;
const reply=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const bad=(e:string,status=400)=>reply({error:e},status);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const date=/^(20\d{2}|2100)-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/;
const text=(v:unknown,max=120)=>typeof v==='string'&&v.trim().length>0&&v.trim().length<=max?v.trim():null;
function validDate(s:unknown):s is string {
 if(typeof s!=='string'||!date.test(s))return false;
 const n=new Date(s+'T00:00:00Z');return Number.isFinite(n.getTime())&&n.toISOString().slice(0,10)===s;
}
function validMoney(n:unknown){return Number.isSafeInteger(n)&&Number(n)>=0&&Number(n)<=1000000000000;}
function validQty(n:unknown){return Number.isSafeInteger(n)&&Number(n)>=1&&Number(n)<=1000000000;}
async function body(req:Request,max=2000000):Promise<Obj>{
 if(!req.headers.get('content-type')?.toLowerCase().includes('application/json'))throw Error('json');
 const raw=await req.text();if(raw.length>max)throw Error('size');
 const doc=JSON.parse(raw) as Obj;if(!doc||typeof doc!=='object'||Array.isArray(doc))throw Error('shape');return doc;
}
async function sha(v:unknown){const bytes=new TextEncoder().encode(JSON.stringify(v));
 return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),x=>x.toString(16).padStart(2,'0')).join('');
}
function mappedError(error:unknown){
 const m=String((error as Error).message);
 if(m.includes('actual_forbidden'))return bad('Không có quyền nhân viên/khách hàng/địa bàn',403);
 if(m.includes('actual_stale')||m.includes('actual_conflict'))return bad('Dữ liệu đã đổi; tải lại trước khi sửa',409);
 if(m.includes('actual_duplicate_conflict'))return bad('Mã giao dịch và dòng đã tồn tại với dữ liệu khác; sử dụng Sửa doanh số',409);
 if(m.includes('actual_not_found'))return bad('Không tìm thấy doanh số',404);
 if(m.includes('actual_invalid'))return bad('Dữ liệu doanh số không hợp lệ');
 return null;
}
export async function actualRoutes(req:Request,env:{DATABASE_URL:string},u:User,url:URL):Promise<Response|null>{
 const path=url.pathname;
 if(!path.startsWith('/api/v1/actuals'))return null;
 const sql=neon(env.DATABASE_URL),manager=u.admin||u.manager;
 const match=/^\/api\/v1\/actuals\/([0-9a-f-]{36})\/history$/i.exec(path);
 if(match&&req.method==='GET'){
  const allowed=await sql`SELECT 1 FROM sales_actuals a JOIN customers c ON c.id=a.customer_id
   WHERE a.id=${match[1]}::uuid AND c.owner_sub=a.owner_sub AND public.sales_can_access(${u.sub},a.owner_sub,c.province,c.district)`;
  if(!allowed.length)return bad('Không có quyền',403);
  return reply({items:await sql`SELECT op_id,actor_sub,before_data,after_data,created_at FROM sales_actual_edits WHERE actual_id=${match[1]}::uuid ORDER BY created_at DESC LIMIT 100`});
 }
 if(path==='/api/v1/actuals/import/history'&&req.method==='GET'){
  if(!manager)return bad('Chỉ Admin/Manager xem nhật ký nhập',403);
  return reply({items:await sql`SELECT * FROM sales_actual_batches WHERE actor_sub=${u.sub} OR ${u.admin} ORDER BY created_at DESC LIMIT 50`});
 }
 if(path==='/api/v1/actuals/options'&&req.method==='GET'){
  const kind=url.searchParams.get('type')??'',q=(url.searchParams.get('q')??'').trim().slice(0,120),owner=url.searchParams.get('owner')||u.sub;
  const staff=await sql`SELECT user_sub AS id,employee_code AS code,full_name AS name FROM staff_members WHERE active AND public.sales_can_access(${u.sub},user_sub,NULL,NULL) ORDER BY full_name LIMIT 200`;
  if(kind==='staff')return reply({items:staff});
  if(!staff.some(s=>s.id===owner))return bad('Không có quyền nhân viên',403);
  if(kind==='customer')return reply({items:await sql`SELECT id::text AS id,code,name FROM customers
    WHERE owner_sub=${owner} AND status<>'inactive' AND
    public.sales_can_access(${u.sub},owner_sub,province,district) AND
    (name ILIKE '%'||${q}||'%' OR code ILIKE '%'||${q}||'%') ORDER BY name LIMIT 100`});
  if(kind==='product')return reply({items:await sql`SELECT id::text AS id,company_code AS code,name FROM catalog_products
   WHERE active AND (name ILIKE '%'||${q}||'%' OR company_code ILIKE '%'||${q}||'%') ORDER BY company_code LIMIT 100`});
  return bad('Loại tìm kiếm không hợp lệ');
 }
 if(path==='/api/v1/actuals/summary'&&req.method==='GET'){
  const year=Number(url.searchParams.get('year')),owner=url.searchParams.get('owner')||u.sub;
  if(!Number.isInteger(year)||year<2000||year>2100)return bad('Năm không hợp lệ');
  const results=await sql`SELECT extract(month from a.sale_date)::int AS month,sum(a.amount)::text AS amount,count(*)::int AS records
    FROM sales_actuals a JOIN customers c ON c.id=a.customer_id
    WHERE a.owner_sub=${owner} AND c.owner_sub=a.owner_sub AND a.status='active'
    AND a.sale_date>=make_date(${year},1,1) AND a.sale_date<make_date(${year+1},1,1)
    AND public.sales_can_access(${u.sub},a.owner_sub,c.province,c.district)
    GROUP BY 1 ORDER BY 1`;
  return reply({owner,year,items:results});
 }
 if(path==='/api/v1/actuals'&&req.method==='GET'){
  const month=url.searchParams.get('month')??'',owner=url.searchParams.get('owner')||u.sub;
  if(!/^(20\d{2}|2100)-(0[1-9]|1[0-2])$/.test(month))return bad('Tháng không hợp lệ');
  const items=await sql`SELECT a.id,a.version,a.sale_date,a.quantity,a.amount::text AS amount,a.source,a.external_ref,a.line_ref,a.status,
     a.owner_sub,a.customer_id::text AS customer_id,a.product_id::text AS product_id,
     s.full_name,s.employee_code,c.name AS customer_name,c.code AS customer_code,p.name AS product_name,p.company_code,
     a.updated_at
    FROM sales_actuals a JOIN staff_members s ON s.user_sub=a.owner_sub
    JOIN customers c ON c.id=a.customer_id AND c.owner_sub=a.owner_sub JOIN catalog_products p ON p.id=a.product_id
    WHERE a.sale_date>=to_date(${month}||'-01','YYYY-MM-DD') AND a.sale_date<(to_date(${month}||'-01','YYYY-MM-DD')+interval '1 month')
    AND (${owner==='all'&&manager} OR a.owner_sub=${owner})
    AND public.sales_can_access(${u.sub},a.owner_sub,c.province,c.district)
    ORDER BY a.sale_date DESC,a.created_at DESC LIMIT 500`;
  const [totals]=await sql`SELECT count(*)::int AS total_records,count(*) FILTER(WHERE a.status='active')::int AS active_records,
      coalesce(sum(a.amount) FILTER(WHERE a.status='active'),0)::text AS total_amount
    FROM sales_actuals a JOIN customers c ON c.id=a.customer_id AND c.owner_sub=a.owner_sub
    WHERE a.sale_date>=to_date(${month}||'-01','YYYY-MM-DD') AND a.sale_date<(to_date(${month}||'-01','YYYY-MM-DD')+interval '1 month')
    AND (${owner==='all'&&manager} OR a.owner_sub=${owner})
    AND public.sales_can_access(${u.sub},a.owner_sub,c.province,c.district)`;
  return reply({month,items,summary:totals,can_import:manager});
 }
 if(['/api/v1/actuals/import/preview','/api/v1/actuals/import/confirm'].includes(path)&&req.method==='POST'){
  if(!manager)return bad('Chỉ Admin/Manager nhập doanh số từ công ty',403);
  const confirm=path.endsWith('/confirm');
  let doc:Obj;try{doc=await body(req);}catch{return bad('File JSON không hợp lệ');}
  if(!text(doc.filename,180)||!String(doc.filename).toLowerCase().endsWith('.xlsx')||!text(doc.sheet,80)
   ||!Array.isArray(doc.rows)||doc.rows.length<1||doc.rows.length>1000)return bad('File/sheet hoặc số dòng không hợp lệ');
  if(confirm&&(!uuid.test(String(doc.client_ref))||!text(doc.preview_hash,64)))return bad('Thiếu UUID/hash xem trước');
  const rows=doc.rows as Obj[],errs:string[]=[],keys=new Set<string>();
  const parsed:{employee_code:string;customer_code:string;company_code:string;sale_date:string;quantity:number;amount:number;external_ref:string;line_ref:string;row_number:number}[]=[];
  for(const r of rows){
   if(!r||typeof r!=='object'||Array.isArray(r)){errs.push('Dòng không hợp lệ');continue;}
   const emp=text(r.employee_code,80),customer=text(r.customer_code,80),product=text(r.company_code,80),ext=text(r.external_ref),line=text(r.line_ref,80);
   const n=r.row_number;
   if(!emp||!customer||!product||!ext||!line||!validDate(r.sale_date)||!validQty(r.quantity)||!validMoney(r.amount)||
     !Number.isInteger(n)||Number(n)<1){errs.push('Dòng '+n+': thiếu hoặc sai ngày/mã/SL/doanh số/mã giao dịch/dòng');continue;}
   const key=JSON.stringify([ext,line]);if(keys.has(key)){errs.push('Dòng '+n+': trùng mã giao dịch và dòng trong file');continue;}keys.add(key);
   parsed.push({employee_code:emp,customer_code:customer,company_code:product,sale_date:r.sale_date as string,quantity:r.quantity as number,amount:r.amount as number,external_ref:ext,line_ref:line,row_number:n as number});
  }
  if(errs.length)return bad(errs.slice(0,25).join('; '));
  const [staff,customers,products,old]=await Promise.all([
   sql`SELECT user_sub,employee_code FROM staff_members WHERE active AND public.sales_can_access(${u.sub},user_sub,NULL,NULL) AND employee_code=ANY(${parsed.map(r=>r.employee_code)}::text[])`,
   sql`SELECT id,owner_sub,code,province,district FROM customers WHERE code=ANY(${parsed.map(r=>r.customer_code)}::text[]) AND status<>'inactive' AND public.sales_can_access(${u.sub},owner_sub,province,district) AND public.sales_can_access(owner_sub,owner_sub,province,district)`,
   sql`SELECT id,company_code FROM catalog_products WHERE company_code=ANY(${parsed.map(r=>r.company_code)}::text[]) AND active`,
   sql`SELECT id,external_ref,line_ref,owner_sub,customer_id,product_id,sale_date,quantity,amount,status FROM sales_actuals
      WHERE source='company' AND external_ref=ANY(${parsed.map(r=>r.external_ref)}::text[])`
  ]);
  const prepared:Obj[]=[],preview:Obj[]=[],seenErrors:string[]=[];
  for(const row of parsed){
   const employee=staff.find(s=>s.employee_code===row.employee_code);
   const customer=customers.find(c=>c.owner_sub===employee?.user_sub&&c.code===row.customer_code);
   const product=products.find(p=>p.company_code===row.company_code);
   if(!employee||!customer||!product){seenErrors.push('Dòng '+row.row_number+': không khớp mã nhân viên, khách thuộc nhân viên, hoặc mã CTY');continue;}

   const rec={owner_sub:employee.user_sub,customer_id:customer.id,product_id:product.id,sale_date:row.sale_date,
     quantity:row.quantity,amount:row.amount,external_ref:row.external_ref,line_ref:row.line_ref};
   const prior=old.find(o=>o.external_ref===row.external_ref&&o.line_ref===row.line_ref);
   const changed=!!prior&&!(prior.owner_sub===rec.owner_sub&&prior.customer_id===rec.customer_id&&prior.product_id===rec.product_id
     &&(prior.sale_date instanceof Date?prior.sale_date.toISOString().slice(0,10):String(prior.sale_date).slice(0,10))===rec.sale_date&&Number(prior.quantity)===rec.quantity&&Number(prior.amount)===rec.amount&&prior.status==='active');
   if(changed){seenErrors.push('Dòng '+row.row_number+': đã tồn tại với nội dung khác, dùng Sửa doanh số');continue;}
   prepared.push(rec);preview.push({...row,duplicate:!!prior,employee_name:employee.employee_code});
  }
  if(seenErrors.length)return bad(seenErrors.slice(0,25).join('; '),409);
  const hash=await sha({filename:doc.filename,sheet:doc.sheet,rows:prepared});
  if(!confirm)return reply({items:preview,preview_hash:hash,duplicate_count:preview.filter(x=>x.duplicate).length});
  if(doc.preview_hash!==hash)return bad('Nội dung đã đổi sau khi xem trước',409);
  try{
   const [r]=await sql`SELECT public.sales_actual_import_apply(${u.sub},${String(doc.client_ref)}::uuid,${String(doc.filename)},${String(doc.sheet)},${hash},${JSON.stringify(prepared)}::jsonb) AS item`;
   return reply({item:r.item});
  }catch(e){const known=mappedError(e);if(known)return known;throw e;}
 }
 const edit=/^\/api\/v1\/actuals\/([0-9a-f-]{36})$/i.exec(path);
 if((path==='/api/v1/actuals'&&req.method==='POST')||(edit&&req.method==='PATCH')){
  let doc:Obj;try{doc=await body(req,10000);}catch{return bad('Dữ liệu không hợp lệ');}
  const data=doc.item as Obj,op=doc.client_ref,version=doc.version;
  if(!uuid.test(String(op))||!data||typeof data!=='object'||Array.isArray(data)||
    !text(data.owner_sub,120)||!uuid.test(String(data.customer_id))||!uuid.test(String(data.product_id))||
    !validDate(data.sale_date)||!validQty(data.quantity)||!validMoney(data.amount)||
    !['active','void'].includes(String(data.status??'active'))||!Number.isInteger(version)||Number(version)<0)return bad('Thiếu mã thao tác hoặc trường doanh số không hợp lệ');
  try{
   const [r]=await sql`SELECT public.sales_actual_write(${u.sub},${String(op)}::uuid,${edit?.[1]??null}::uuid,${Number(version)},${JSON.stringify(data)}::jsonb) AS item`;
   return reply({item:r.item},edit?200:201);
  }catch(e){const known=mappedError(e);if(known)return known;throw e;}
 }
 return bad('Endpoint không tồn tại',404);
}
