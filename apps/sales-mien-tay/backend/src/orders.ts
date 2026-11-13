import {neon} from '@neondatabase/serverless';
import type {userFromRequest} from './auth';
type User=Awaited<ReturnType<typeof userFromRequest>>;
type Json=Record<string,unknown>;
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const respond=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const bad=(error:string,status=400)=>respond({error},status);
const isUuid=(v:unknown):v is string=>typeof v==='string'&&uuid.test(v);
function validateRequest(x:Json){
 if(!isUuid(x.id)||!isUuid(x.client_ref)||!isUuid(x.customer_id)||
  typeof x.owner_sub!=='string'||x.owner_sub.length<1||x.owner_sub.length>150||
  !Number.isInteger(x.version)||Number(x.version)<0||Number(x.version)>2147483646||
  !['save','export','imported'].includes(String(x.action))||
  !Array.isArray(x.lines)||x.lines.length>100||
  typeof x.note!=='string'||x.note.length>500||typeof x.accept_stale!=='boolean'||
  (x.import_reference!==null&&x.import_reference!==undefined&&
    (typeof x.import_reference!=='string'||x.import_reference.length>120)))return false;
 const seenProducts=new Set<string>(),seenLines=new Set<string>();
 for(const row of x.lines){
  if(!row||typeof row!=='object'||Array.isArray(row))return false;
  const r=row as Json;
  if(!isUuid(r.line_id)||!isUuid(r.product_id)||typeof r.unit!=='string'||!r.unit.trim()||r.unit.length>80||
    !Number.isSafeInteger(r.quantity)||Number(r.quantity)<1||Number(r.quantity)>100000000||
    seenProducts.has(r.product_id)||seenLines.has(r.line_id))return false;
  seenProducts.add(r.product_id);seenLines.add(r.line_id);
 }
 return true;
}
function mapError(err:unknown):Response|null {
 const message=String((err as Error).message);
 if(message.includes('order_forbidden'))return bad('Không có quyền đặt đơn cho khách/nhân viên',403);
 if(message.includes('order_state'))return bad('Trạng thái đơn không cho phép sửa hoặc xuất; tải lại đơn',409);
 if(message.includes('order_stale')||message.includes('order_conflict'))return bad('Đơn đã được sửa hoặc UUID đã dùng; tải lại trước khi thao tác',409);
 if(message.includes('order_customer_code'))return bad('Khách chưa có mã khách công ty; cập nhật tại danh mục khách trước khi xuất',409);
 if(message.includes('order_stock_missing'))return bad('Chưa có tồn cho một số sản phẩm, không được xuất',409);
 if(message.includes('order_stock_short'))return bad('Tồn theo snapshot không đủ số lượng; chỉnh lại giỏ trước khi xuất',409);
 if(message.includes('order_stock_stale'))return bad('Bản tồn quá 24 giờ; phải xác nhận dùng tồn cũ trước khi xuất',409);
 if(message.includes('order_stock_expired'))return bad('Tồn đã quá 7 ngày; phải cập nhật file tồn mới trước khi xuất',409);
 if(message.includes('order_invalid_unit'))return bad('Đơn vị tính không khớp tồn kho hoặc mã sản phẩm đã ngừng bán',409);
 if(message.includes('order_missing'))return bad('Không tìm thấy đơn hàng',404);
 if(message.includes('order_invalid'))return bad('Đơn hàng hoặc lý do không hợp lệ',400);
 return null;
}
export async function orderRoutes(req:Request,env:{DATABASE_URL:string},u:User,url:URL):Promise<Response|null>{
 const path=url.pathname;
 if(!path.startsWith('/api/v1/orders'))return null;
 const sql=neon(env.DATABASE_URL),manager=u.admin||u.manager;
 if(req.method==='GET'){
  if(path==='/api/v1/orders/customers'){
   const q=(url.searchParams.get('q')??'').trim().slice(0,120);
   const items=await sql`SELECT c.id::text AS id,c.owner_sub,c.name,c.code AS customer_code,c.field_code,
    c.province,c.district,m.company_code AS mapping_code,
    coalesce(nullif(btrim(m.company_code),''),nullif(btrim(c.code),'')) AS export_code
    FROM customers c LEFT JOIN catalog_customer_mapping m ON m.customer_id=c.id
    WHERE c.status<>'inactive' AND public.sales_customer_allowed(${u.sub},c.id,'view')
      AND (c.name ILIKE '%'||${q}||'%' OR c.field_code ILIKE '%'||${q}||'%' OR c.code ILIKE '%'||${q}||'%'
       OR m.company_code ILIKE '%'||${q}||'%')
    ORDER BY c.name LIMIT 100`;
   return respond({items});
  }
  if(path==='/api/v1/orders/products'){
   const q=(url.searchParams.get('q')??'').trim().slice(0,120);
   const after=url.searchParams.get('after')??'';
   const parsedLimit=Number(url.searchParams.get('limit')??'60');
   if(after.length>80||!Number.isInteger(parsedLimit)||parsedLimit<1||parsedLimit>100)
    return bad('Tham số phân trang không hợp lệ');
   const limit=parsedLimit+1;
   const items=await sql`SELECT p.id::text AS id,p.company_code,p.sku,p.name,p.brand,p.category,p.unit,
    p.product_spec
    FROM catalog_products p
    WHERE p.active AND p.company_code>${after}
      AND (p.name ILIKE '%'||${q}||'%' OR p.company_code ILIKE '%'||${q}||'%'
       OR p.sku ILIKE '%'||${q}||'%' OR p.brand ILIKE '%'||${q}||'%'
       OR p.category ILIKE '%'||${q}||'%')
    ORDER BY p.company_code ASC LIMIT ${limit}`;
   const hasMore=items.length>parsedLimit;
   const page=items.slice(0,parsedLimit);
   return respond({items:page,next_cursor:hasMore?page[page.length-1].company_code:null,
    sales_request_only:true,does_not_reserve_stock:true});
  }
  const detail=/^\/api\/v1\/orders\/([a-f0-9-]{36})(\/export|\/audit)?$/i.exec(path);
  if(path==='/api/v1/orders'){
   const q=(url.searchParams.get('q')??'').trim();
   const status=url.searchParams.get('status')??'';
   const from=url.searchParams.get('from')??'';
   const to=url.searchParams.get('to')??'';
   if(q.length>120||!['','local','draft','exported','imported','cancelled','superseded'].includes(status)
     ||(from!==''&&!/^\d{4}-\d{2}-\d{2}$/.test(from))
     ||(to!==''&&!/^\d{4}-\d{2}-\d{2}$/.test(to))
     ||(from!==''&&to!==''&&from>to)){
    return bad('Bộ lọc đơn hàng không hợp lệ',400);
   }
   const fromDate=from||null,toDate=to||null;
   const items=await sql`SELECT o.id::text AS id,o.owner_sub,o.customer_id::text AS customer_id,
    o.status,o.version,o.note,o.import_reference,o.created_at,o.updated_at,o.exported_at,
    o.cancel_reason,o.cancelled_at,o.replaces_order_id::text AS replaces_order_id,
    o.replacement_reason,o.superseded_at,
    (SELECT successor.id::text FROM field_orders successor
      WHERE successor.replaces_order_id=o.id) AS replaced_by_id,
    c.name AS customer_name,c.field_code AS customer_field_code,c.province,c.district,
    coalesce(nullif(btrim(m.company_code),''),nullif(btrim(c.code),'')) AS customer_code,
    coalesce((SELECT jsonb_agg(jsonb_build_object('line_id',l.line_id,'product_id',l.product_id,
       'company_code',p.company_code,'name',p.name,'unit',l.unit,'quantity',l.quantity,
       'available',NULL::text,'snapshot_at',NULL::timestamptz)
       ORDER BY l.line_position,p.company_code) FROM field_order_lines l JOIN catalog_products p ON p.id=l.product_id
       WHERE l.order_id=o.id),'[]'::jsonb) AS lines
    FROM field_orders o JOIN customers c ON c.id=o.customer_id AND c.owner_sub=o.owner_sub
    LEFT JOIN catalog_customer_mapping m ON m.customer_id=c.id
    WHERE public.sales_customer_allowed(${u.sub},c.id,'view')
      AND (${status}='' OR o.status=${status})
      AND (${q}='' OR c.name ILIKE '%'||${q}||'%'
       OR c.field_code ILIKE '%'||${q}||'%'
       OR c.code ILIKE '%'||${q}||'%'
       OR m.company_code ILIKE '%'||${q}||'%'
       OR o.id::text ILIKE '%'||${q}||'%')
      AND (${fromDate}::date IS NULL OR o.created_at>=${fromDate}::date)
      AND (${toDate}::date IS NULL OR o.created_at<(${toDate}::date+interval '1 day'))
    ORDER BY o.updated_at DESC LIMIT 100`;
   return respond({items,can_mark_imported:u.admin});
  }
  if(detail&&isUuid(detail[1])){
   const id=detail[1];
   const rows=await sql`SELECT o.id::text AS id,o.owner_sub,o.customer_id::text AS customer_id,
    o.status,o.version,o.note,o.import_reference,o.created_at,o.exported_at,o.updated_at,
    o.cancel_reason,o.cancelled_at,o.replaces_order_id::text AS replaces_order_id,
    o.replacement_reason,o.superseded_at,
    (SELECT successor.id::text FROM field_orders successor
      WHERE successor.replaces_order_id=o.id) AS replaced_by_id,
    c.name AS customer_name,c.field_code AS customer_field_code,c.province,c.district,
    coalesce(nullif(btrim(m.company_code),''),nullif(btrim(c.code),'')) AS customer_code,
    coalesce((SELECT jsonb_agg(jsonb_build_object('line_id',l.line_id,'product_id',l.product_id,
       'company_code',p.company_code,'name',p.name,'unit',l.unit,'quantity',l.quantity,
       'available',NULL::text,'snapshot_at',NULL::timestamptz)
      ORDER BY l.line_position,p.company_code) FROM field_order_lines l JOIN catalog_products p ON p.id=l.product_id
 WHERE l.order_id=o.id),'[]'::jsonb) AS lines
    FROM field_orders o JOIN customers c ON c.id=o.customer_id AND c.owner_sub=o.owner_sub
    LEFT JOIN catalog_customer_mapping m ON m.customer_id=c.id
    WHERE o.id=${id}::uuid AND public.sales_customer_allowed(${u.sub},c.id,'view')`;
   if(rows.length===0)return bad('Không có quyền hoặc không tìm thấy đơn',404);
   if(detail[2]==='/audit'){
    return respond({item:rows[0],events:await sql`SELECT op_id,actor_sub,
     request_data->>'action' AS action,before_data,after_data,created_at
     FROM field_order_ops WHERE order_id=${id}::uuid ORDER BY created_at DESC LIMIT 100`});
   }
   if(detail[2]==='/export'){
     const allowed=await sql`SELECT public.sales_customer_allowed(${u.sub},${rows[0].customer_id}::uuid,'export') AS ok`;
     if(allowed[0]?.ok!==true)return bad('Không có quyền xuất đơn',403);
    if(rows[0].status!=='exported'&&rows[0].status!=='imported')return bad('Đơn chưa xác nhận xuất',409);
    return respond({item:rows[0],format:'FIELD_WORK_RETAIL_PREP_V1',
     import_certified:false,warning:'Mẫu Excel chuẩn bị nhập; chưa được xác minh với file import app công ty.',
     fields:['Mã đơn','Mã khách CTY','Mã CTY','ĐVT','Số lượng','Ghi chú']});
   }
   return respond({item:rows[0]});
  }
  return bad('Endpoint không tồn tại',404);
 }
 if(path==='/api/v1/orders/lifecycle'&&req.method==='POST'){
  let data:Json;
  try{
   const raw=await req.text();
   if(raw.length>3000)throw Error('large');
   data=JSON.parse(raw) as Json;
   if(!data||typeof data!=='object'||Array.isArray(data))throw Error('invalid');
  }catch{return bad('JSON vòng đời đơn không hợp lệ');}
  const mode=data.action, reason=data.reason;
  const target=data.order_id, ref=data.client_ref;
  const replacement=data.replacement_id;
  const version=data.expected_version;
  if(!isUuid(target)||!isUuid(ref)||
    (mode!=='cancel'&&mode!=='replace')||
    !Number.isInteger(version)||Number(version)<1||
    typeof reason!=='string'||reason.trim().length<8||reason.trim().length>300||
    (mode==='cancel'&&replacement!==null&&replacement!==undefined)||
    (mode==='replace'&&(!isUuid(replacement)||replacement===target))){
   return bad('Thiếu mã đơn, phiên bản, lý do (8–300 ký tự) hoặc mã thay thế',400);
  }
  if(mode==='replace'&&!u.admin)return bad('Chỉ Admin tạo đơn điều chỉnh hoặc thay thế',403);
  try{
   const [row]=await sql`SELECT public.field_order_lifecycle(
      ${u.sub},${ref}::uuid,${target}::uuid,${Number(version)},
      ${mode},${reason.trim()},${mode==='replace'?String(replacement):null}::uuid
     ) AS result`;
   return respond(row.result);
  }catch(e){const known=mapError(e);if(known)return known;throw e;}
 }
 if(path!=='/api/v1/orders'||req.method!=='POST')return bad('Endpoint không tồn tại',404);
 let doc:Json;
 try{const raw=await req.text();if(raw.length>35000)throw Error('large');
  doc=JSON.parse(raw) as Json;if(!doc||typeof doc!=='object'||Array.isArray(doc))throw Error('invalid');
 }catch{return bad('JSON không hợp lệ');}
 if(!validateRequest(doc))return bad('Thiếu UUID, trường đơn hoặc dòng số lượng hợp lệ');
 if(doc.action!=='save'&&(doc.lines as unknown[]).length>0)return bad('Hãy lưu giỏ trước khi xuất; không được đổi giỏ khi xác nhận');
 if(doc.action==='imported'&&!u.admin)return bad('Chỉ Admin xác nhận đã nhập app công ty',403);
 try{
  const [row]=await sql`SELECT public.field_order_apply(${u.sub},${String(doc.client_ref)}::uuid,
     ${String(doc.id)}::uuid,${Number(doc.version)},${String(doc.owner_sub)},
     ${String(doc.customer_id)}::uuid,${String(doc.action)},
     ${JSON.stringify(doc.lines)}::jsonb,${String(doc.note)},${doc.accept_stale as boolean},
     ${typeof doc.import_reference==='string'?doc.import_reference:null}) AS item`;
  return respond({item:row.item},doc.action==='save'&&doc.version===0?201:200);
 }catch(e){const known=mapError(e);if(known)return known;throw e;}
}
