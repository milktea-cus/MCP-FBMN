import {neon} from '@neondatabase/serverless';
export interface AssortmentActor {sub:string;admin:boolean;manager:boolean;}
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const isUuid=(v:unknown):v is string=>typeof v==='string'&&uuid.test(v);
const response=(v:unknown,status=200)=>new Response(JSON.stringify(v),{
 status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'},
});
const bad=(error:string,status=400)=>response({error},status);
function errorResponse(e:unknown){
 const message=String((e as Error).message);
 if(message.includes('assortment_forbidden'))return bad('Không có quyền xác minh SKU khách hàng',403);
 if(message.includes('assortment_product'))return bad('Sản phẩm không tồn tại hoặc đã ngừng kinh doanh',409);
 if(message.includes('assortment_stale')||message.includes('assortment_conflict'))
  return bad('Danh mục khách đã thay đổi hoặc yêu cầu bị trùng. Tải lại trước khi sửa',409);
 if(message.includes('assortment_invalid'))return bad('Dữ liệu xác minh SKU không hợp lệ',400);
 return null;
}
/** Customer-SKU evidence is read from live orders, not mutable order copies.
 * Cancellation/replacement therefore has no stale projection to reconcile. */
export async function assortmentRoutes(
 req:Request,env:{DATABASE_URL:string},actor:AssortmentActor,url:URL,
):Promise<Response|null>{
 const brandPath=/^\/api\/v1\/customers\/([a-f0-9-]{36})\/brands(?:\/(audit))?$/i.exec(url.pathname);
 if(brandPath){
  const cid=brandPath[1];
  if(!isUuid(cid))return bad('Mã khách hàng không hợp lệ');
  const sql=neon(env.DATABASE_URL);
  const allowed=await sql`SELECT c.id FROM public.customers c
   JOIN public.staff_members owner ON owner.user_sub=c.owner_sub AND owner.active
   WHERE c.id=${cid}::uuid AND public.sales_customer_allowed(${actor.sub},c.id,'view') LIMIT 1`;
  if(!allowed.length)return bad('Không tìm thấy khách hoặc không có quyền',404);
  if(req.method==='GET'){
   if(brandPath[2]==='audit'){
    const items=await sql`SELECT a.actor_sub,a.action,a.reason,a.created_at,b.name AS brand_name
     FROM public.customer_brand_verification_audit a
     JOIN public.catalog_brands b ON b.id=a.brand_id
     WHERE a.customer_id=${cid}::uuid ORDER BY a.created_at DESC,a.id DESC LIMIT 50`;
    return response({items});
   }
   const items=await sql`WITH sku AS (
     SELECT p.brand_id,
       bool_or(a.ordered_orders>0) AS ordered,
       bool_or(a.imported_orders>0) AS imported,
       bool_or(a.is_trading) AS sku_trading
     FROM public.customer_product_assortment a
     JOIN public.catalog_products p ON p.id=a.product_id
     WHERE a.customer_id=${cid}::uuid AND p.brand_id IS NOT NULL
     GROUP BY p.brand_id
   )
   SELECT b.id::text AS brand_id,b.name,b.active,
     coalesce(sku.ordered,false) AS ordered,
     coalesce(sku.imported,false) AS imported,
     coalesce(sku.sku_trading,false) AS sku_trading,
     coalesce(v.is_trading,false) AS manual_trading,
     (coalesce(sku.sku_trading,false) OR coalesce(v.is_trading,false)) AS is_trading,
     CASE WHEN coalesce(sku.sku_trading,false) OR coalesce(v.is_trading,false)
      THEN 'trading' WHEN coalesce(sku.imported,false) THEN 'imported'
      WHEN coalesce(sku.ordered,false) THEN 'ordered' ELSE 'unknown' END AS status,
     coalesce(v.version,0) AS manual_version,
     v.verification_note,v.verified_at,v.verified_by
   FROM public.catalog_brands b
   LEFT JOIN sku ON sku.brand_id=b.id
   LEFT JOIN public.customer_brand_verifications v
    ON v.brand_id=b.id AND v.customer_id=${cid}::uuid
   WHERE b.active
   ORDER BY b.name,b.id LIMIT 500`;
   return response({items,source_semantics:{
     ordered:'Đơn đã xuất',imported:'Đã nhập công ty',
     trading:'Xác minh thủ công ở nhãn hoặc SKU, không suy ra từ đơn/khảo sát'}});
  }
  if(req.method!=='POST'||brandPath[2])return bad('Phương thức không được hỗ trợ',405);
  const permission=await sql`SELECT public.sales_customer_allowed(${actor.sub},${cid}::uuid,'edit') AS allowed`;
  if(permission[0]?.allowed!==true)return bad('Không có quyền xác minh nhãn hàng',403);
  let v:Record<string,unknown>;
  try{
   const raw=await req.text();
   if(raw.length>2000)throw Error('body');
   const parsed:unknown=JSON.parse(raw);
   if(!parsed||typeof parsed!=='object'||Array.isArray(parsed))throw Error('json');
   v=parsed as Record<string,unknown>;
  }catch{return bad('JSON xác minh nhãn không hợp lệ',400);}
  if(!isUuid(v.client_ref)||!isUuid(v.brand_id)||
     !Number.isInteger(v.expected_version)||Number(v.expected_version)<0||
     !['verify','unverify'].includes(String(v.action))||
     typeof v.reason!=='string'||v.reason.trim().length<8||v.reason.trim().length>500)
    return bad('Cần nhãn, UUID, version và lý do 8–500 ký tự',400);
  try{
    const rows=await sql`SELECT public.sales_customer_brand_apply(
     ${actor.sub},${v.client_ref}::uuid,${cid}::uuid,${v.brand_id}::uuid,
     ${Number(v.expected_version)},${v.action},${v.reason.trim()}) AS item`;
    return response({item:rows[0].item},201);
  }catch(e){
   const reason=String((e as Error).message??'');
   if(reason.includes('brand_customer_forbidden'))return bad('Không có quyền',403);
   if(reason.includes('brand_customer_invalid'))return bad('Dữ liệu xác minh không hợp lệ',400);
   if(reason.includes('brand_customer_inactive')||reason.includes('brand_customer_stale')||
      reason.includes('brand_customer_conflict'))
    return bad('Nhãn hoặc phiên bản đã thay đổi; tải lại',409);
   throw e;
  }
 }
 const match=/^\/api\/v1\/customers\/([a-f0-9-]{36})\/products(?:\/(catalog|audit))?$/i.exec(url.pathname);
 if(!match)return null;
 const customerId=match[1],kind=match[2]??'';
 if(!isUuid(customerId))return bad('Mã khách hàng không hợp lệ');
 const sql=neon(env.DATABASE_URL);
 const eligible=await sql`SELECT c.owner_sub
   FROM public.customers c JOIN public.staff_members owner
    ON owner.user_sub=c.owner_sub AND owner.active
   WHERE c.id=${customerId}::uuid
     AND public.sales_customer_allowed(${actor.sub},c.id,'view')
   LIMIT 1`;
 if(!eligible.length)return bad('Không tìm thấy khách hàng hoặc không có quyền',404);
 if(req.method==='GET'){
  const q=(url.searchParams.get('q')??'').trim();
  const status=url.searchParams.get('status')??'';
  const after=url.searchParams.get('after')??'';
  const limit=Number(url.searchParams.get('limit')??'40');
  if(q.length>120||after.length>120||!Number.isInteger(limit)||limit<1||limit>100||
    !['','ordered','imported','trading'].includes(status))
   return bad('Bộ lọc SKU không hợp lệ',400);
  if(kind==='audit'){
   const items=await sql`SELECT op_id,product_id::text AS product_id,
     actor_sub,request_data->>'action' AS action,
     request_data->>'reason' AS reason,created_at,before_data,after_data
    FROM public.customer_product_ops WHERE customer_id=${customerId}::uuid
    ORDER BY created_at DESC LIMIT ${Math.min(50,limit)}`;
   return response({items});
  }
  if(kind==='catalog'){
   // Selection exposes version even for previously unverified manual rows.
   const items=await sql`SELECT p.id::text AS product_id,p.company_code,
      p.sku,p.name,p.brand,p.unit,p.category,cp.version AS manual_version,
      coalesce(cp.verified,false) AS manual_verified,
      a.status AS evidence_status
     FROM public.catalog_products p
     LEFT JOIN public.customer_products cp ON cp.product_id=p.id
      AND cp.customer_id=${customerId}::uuid
     LEFT JOIN public.customer_product_assortment a ON a.customer_id=${customerId}::uuid
      AND a.product_id=p.id
     WHERE p.active AND p.company_code>${after}
      AND (${q}='' OR p.name ILIKE '%'||${q}||'%'
       OR p.company_code ILIKE '%'||${q}||'%'
       OR p.sku ILIKE '%'||${q}||'%'
       OR p.brand ILIKE '%'||${q}||'%')
     ORDER BY p.company_code ASC LIMIT ${limit+1}`;
   const more=items.length>limit,page=items.slice(0,limit);
   return response({items:page,next_cursor:more?page[page.length-1]?.company_code:null});
  }
  const items=await sql`SELECT a.product_id::text AS product_id,
     a.company_code,a.sku,a.name,a.brand,a.unit,a.category,
     a.status,a.is_trading,a.ordered_orders,a.imported_orders,
     a.manual_version,a.verification_note,a.verified_at,a.verified_by,
     a.last_ordered_at,a.last_imported_at,a.evidence_at
    FROM public.customer_product_assortment a
    WHERE a.customer_id=${customerId}::uuid AND a.company_code>${after}
     AND (${status}='' OR (${status}='trading' AND a.is_trading)
      OR (${status}='imported' AND a.imported_orders>0)
      OR (${status}='ordered' AND a.ordered_orders>0))
     AND (${q}='' OR a.name ILIKE '%'||${q}||'%'
      OR a.company_code ILIKE '%'||${q}||'%'
      OR a.sku ILIKE '%'||${q}||'%'
      OR a.brand ILIKE '%'||${q}||'%')
    ORDER BY a.company_code ASC LIMIT ${limit+1}`;
  const more=items.length>limit,page=items.slice(0,limit);
  return response({items:page,next_cursor:more?page[page.length-1]?.company_code:null,
   source_semantics:{
    ordered:'Đơn đã xuất còn hiệu lực (không tính đơn hủy/thay thế)',
    imported:'Admin xác nhận đã nhập vào công ty',
    trading:'Nhân viên xác minh thực tế; không suy ra từ doanh số',
   }});
 }
 if(req.method==='POST'&&!kind){
  const permission=await sql`SELECT public.sales_customer_allowed(${actor.sub},${customerId}::uuid,'edit') AS allowed`;
   if(permission[0]?.allowed!==true)return bad('Không có quyền sửa danh mục khách',403);
  let data:Record<string,unknown>;
  try{
   const raw=await req.text();
   if(raw.length>2000)throw Error('body');
   const json=JSON.parse(raw) as unknown;
   if(!json||typeof json!=='object'||Array.isArray(json))throw Error('json');
   data=json as Record<string,unknown>;
  }catch{return bad('JSON xác minh không hợp lệ',400);}
  const {client_ref,product_id,expected_version,action,reason}=data;
  if(!isUuid(client_ref)||!isUuid(product_id)||!Number.isInteger(expected_version)||
     Number(expected_version)<0||Number(expected_version)>2147483646||
     !['verify','unverify'].includes(String(action))||
     typeof reason!=='string'||reason.trim().length<8||reason.trim().length>500)
   return bad('Cần SKU, UUID, version và lý do xác minh (8–500 ký tự)',400);
  try{
   const rows=await sql`SELECT public.customer_product_apply(
    ${actor.sub},${client_ref}::uuid,${customerId}::uuid,
    ${product_id}::uuid,${Number(expected_version)},${String(action)},${reason.trim()}
   ) AS result`;
   return response(rows[0].result);
  }catch(e){const known=errorResponse(e);if(known)return known;throw e;}
 }
 return bad('Phương thức không được hỗ trợ',405);
}
