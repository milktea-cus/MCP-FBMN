import {neon} from '@neondatabase/serverless';
type Actor={sub:string;admin:boolean};
type Obj=Record<string,unknown>;
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const validId=(v:unknown):v is string=>typeof v==='string'&&uuid.test(v);
const json=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const bad=(error:string,status=400)=>json({error},status);
export function normalizedCode(v:unknown):string|null{
 if(typeof v!=='string')return null;
 const s=v.normalize('NFKC').replace(/[\u200B-\u200D\uFEFF]/g,'').trim().toUpperCase();
 return s&&s.length<=80&&!/[\x00-\x1f\x7f]/.test(s)?s:null;
}
function clean(v:unknown,max:number):string|null{
 if(v===null||v===undefined||v==='')return null;
 if(typeof v!=='string'||v.trim().length>max||/[\x00-\x1f\x7f]/.test(v))throw Error('Văn bản không hợp lệ');
 return v.trim()||null;
}
export function parseProduct(v:Obj){
 const name=clean(v.name,240);if(!name)throw Error('Thiếu tên hàng');
 const code=normalizedCode(v.company_code);if(!code)throw Error('Mã CTY phải là văn bản, tối đa 80 ký tự');
 const raw=v.product_spec??{};
 if(!raw||typeof raw!=='object'||Array.isArray(raw))throw Error('Quy cách không hợp lệ');
 const spec:Obj={},r=raw as Obj;
 for(const k of ['pieceUnit','packUnit','paperSize','ruling','coverType','packagingNote']){
  const val=clean(r[k],k==='packagingNote'?1000:80);if(val!==null)spec[k]=val;
 }
 for(const k of ['unitsPerCarton','unitsPerPack','packsPerCarton','pages','gsm']){
  const val=r[k];if(val===null||val===undefined||val==='')continue;
  if(typeof val!=='number'||!Number.isSafeInteger(val)||val<1||val>1000000)throw Error(k+' phải là số nguyên dương');
  spec[k]=val;
 }
 const a=spec.unitsPerCarton,b=spec.unitsPerPack,c=spec.packsPerCarton;
 if(typeof a==='number'&&typeof b==='number'&&typeof c==='number'&&a!==b*c)throw Error('Quy cách mâu thuẫn: SP/lốc × lốc/thùng phải bằng SP/thùng');
 if(Object.keys(r).some(k=>!['pieceUnit','packUnit','paperSize','ruling','coverType','packagingNote','unitsPerCarton','unitsPerPack','packsPerCarton','pages','gsm'].includes(k)))throw Error('Trường quy cách không hỗ trợ');
 if(v.active!==undefined&&typeof v.active!=='boolean')throw Error('Trạng thái không hợp lệ');
 return {company_code:code,name,sku:clean(v.sku,80),brand:clean(v.brand,120),category:clean(v.category,120),unit:clean(v.unit,80),product_spec:spec,active:v.active!==false};
}
async function body(req:Request):Promise<Obj>{
 const s=await req.text();if(s.length>32000)throw Error('Dữ liệu quá lớn');
 const v=JSON.parse(s);if(!v||typeof v!=='object'||Array.isArray(v))throw Error('JSON không hợp lệ');return v;
}
export async function catalogRoutes(req:Request,env:{DATABASE_URL:string},actor:Actor,url:URL):Promise<Response|null>{
 const path=url.pathname;
 if(!path.startsWith('/api/v1/catalog'))return null;
 const db=neon(env.DATABASE_URL);
 if(path==='/api/v1/catalog/products'&&req.method==='GET'){
  const q=(url.searchParams.get('q')??'').trim().slice(0,120),after=url.searchParams.get('after')??'';
  const limit=Number(url.searchParams.get('limit')??'50');
  if(!Number.isInteger(limit)||limit<1||limit>100||after.length>80)return bad('Phân trang không hợp lệ');
  const rows=await db`SELECT * FROM catalog_products WHERE (${actor.admin} OR active) AND company_code>${after}
   AND (${!q} OR strpos(lower(company_code),lower(${q}))>0 OR strpos(lower(name),lower(${q}))>0 OR strpos(lower(coalesce(sku,'')),lower(${q}))>0 OR strpos(lower(coalesce(brand,'')),lower(${q}))>0)
   ORDER BY company_code LIMIT ${limit+1}`;
  const items=rows.slice(0,limit);return json({items,next_cursor:rows.length>limit?items[items.length-1].company_code:null,synced_at:new Date().toISOString()});
 }
 if(path==='/api/v1/catalog/edits'&&req.method==='GET'){
  if(!actor.admin)return bad('Chỉ Admin xem nhật ký',403);
  return json({items:await db`SELECT * FROM catalog_edits ORDER BY created_at DESC LIMIT 20`});
 }
 const mapping=/^\/api\/v1\/catalog\/customers\/([a-f0-9-]{36})$/i.exec(path);
 if(mapping&&validId(mapping[1])){
  const id=mapping[1];
  const c=await db`SELECT c.id FROM customers c WHERE c.id=${id}::uuid AND public.sales_can_access(${actor.sub},c.owner_sub,c.province,c.district)`;
  if(!c.length)return bad('Không tìm thấy hoặc không có quyền điểm bán',404);
  if(req.method==='GET'){const rows=await db`SELECT m.* FROM catalog_customer_mapping m JOIN customers c ON c.id=m.customer_id WHERE c.id=${id}::uuid AND public.sales_can_access(${actor.sub},c.owner_sub,c.province,c.district)`;return json({item:rows[0]??null});}
  if(req.method!=='PATCH')return bad('Method not allowed',405);
  if(!actor.admin)return bad('Chỉ Admin mapping mã khách',403);
  let v:Obj;try{v=await body(req);}catch{return bad('JSON không hợp lệ');}
  const code=normalizedCode(v.company_code),version=v.version,op=v.client_ref;
  if(!code||!validId(op)||!Number.isInteger(version)||Number(version)<0)return bad('Mã, version hoặc UUID không hợp lệ');
  const prior=await db`SELECT * FROM catalog_customer_mapping WHERE customer_id=${id}::uuid AND last_op=${op}::uuid AND updated_by=${actor.sub}`;
  if(prior.length)return prior[0].company_code===code?json({item:prior[0],idempotent:true}):bad('UUID đã dùng',409);
  const rows=await db`INSERT INTO catalog_customer_mapping(customer_id,company_code,updated_by,last_op)
   SELECT c.id,${code},${actor.sub},${op}::uuid FROM customers c WHERE c.id=${id}::uuid AND public.sales_can_access(${actor.sub},c.owner_sub,c.province,c.district) AND ${Number(version)===0}
   ON CONFLICT(customer_id) DO NOTHING RETURNING *`;
  if(rows.length)return json({item:rows[0]},201);
  const updated=await db`UPDATE catalog_customer_mapping m SET company_code=${code},version=m.version+1,updated_by=${actor.sub},last_op=${op}::uuid,updated_at=now() FROM customers c WHERE c.id=m.customer_id AND m.customer_id=${id}::uuid AND m.version=${Number(version)} AND public.sales_can_access(${actor.sub},c.owner_sub,c.province,c.district) RETURNING m.*`;
  return updated.length?json({item:updated[0]}):bad('Mapping đã thay đổi, tải lại',409);
 }
 const match=/^\/api\/v1\/catalog\/products\/([a-f0-9-]{36})$/i.exec(path);
 if(!(path==='/api/v1/catalog/products'&&req.method==='POST')&&!(match&&validId(match[1])&&req.method==='PATCH'))return bad('Endpoint không tồn tại',404);
 if(!actor.admin)return bad('Chỉ Admin quản lý danh mục',403);
 let v:Obj;let product:ReturnType<typeof parseProduct>;
 try{v=await body(req);product=parseProduct(v);}catch(e){return bad(e instanceof Error?e.message:'Dữ liệu không hợp lệ');}
 const op=v.client_ref;if(!validId(op))return bad('Thiếu UUID thao tác');
 const id=match?.[1]??op;
 const prior=await db`SELECT product_id,after_data,actor_sub,(after_data @> ${JSON.stringify(product)}::jsonb AND after_data->'product_spec'=${JSON.stringify(product.product_spec)}::jsonb) AS same_payload FROM catalog_edits WHERE op_id=${op}::uuid`;
 if(prior.length)return prior[0].product_id===id&&prior[0].actor_sub===actor.sub&&prior[0].same_payload?json({item:prior[0].after_data,idempotent:true}):bad('UUID đã dùng',409);
 const spec=JSON.stringify(product.product_spec);
 if(!match){
  const rows=await db`WITH inserted AS (
   INSERT INTO catalog_products(id,company_code,sku,name,brand,category,unit,product_spec,active)
   VALUES(${id}::uuid,${product.company_code},${product.sku},${product.name},${product.brand},${product.category},${product.unit},${spec}::jsonb,${product.active})
   ON CONFLICT DO NOTHING RETURNING *
  ), audit AS (INSERT INTO catalog_edits(op_id,actor_sub,product_id,after_data) SELECT ${op}::uuid,${actor.sub},id,to_jsonb(inserted) FROM inserted RETURNING product_id)
  SELECT inserted.* FROM inserted JOIN audit ON audit.product_id=inserted.id`;
  return rows.length?json({item:rows[0]},201):bad('Mã CTY đã tồn tại; không tạo trùng',409);
 }
 if(!Number.isInteger(v.version)||Number(v.version)<1)return bad('Thiếu phiên bản');
 const rows=await db`WITH old AS MATERIALIZED (SELECT * FROM catalog_products WHERE id=${id}::uuid AND version=${Number(v.version)} AND company_code=${product.company_code} FOR UPDATE),
 changed AS (UPDATE catalog_products p SET sku=${product.sku},name=${product.name},brand=${product.brand},category=${product.category},unit=${product.unit},product_spec=${spec}::jsonb,active=${product.active},version=p.version+1,updated_at=now() FROM old WHERE p.id=old.id RETURNING p.*),
 audit AS (INSERT INTO catalog_edits(op_id,actor_sub,product_id,before_data,after_data) SELECT ${op}::uuid,${actor.sub},changed.id,to_jsonb(old),to_jsonb(changed) FROM changed JOIN old ON old.id=changed.id RETURNING product_id)
 SELECT changed.* FROM changed JOIN audit ON audit.product_id=changed.id`;
 return rows.length?json({item:rows[0]}):bad('Mã CTY không được sửa hoặc version đã thay đổi; tải lại',409);
}
