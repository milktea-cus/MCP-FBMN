import {neon} from '@neondatabase/serverless';
import {normalizedCode} from './catalog';
type Actor={sub:string;admin:boolean};
type Obj=Record<string,unknown>;
type Row={company_code:string;quantity:number;row_number:number;product_version:number};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const isId=(v:unknown):v is string=>typeof v==='string'&&uuid.test(v);
const json=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const bad=(error:string,status=400)=>json({error},status);
async function read(req:Request):Promise<Obj>{
 const s=await req.text();if(s.length>1000000)throw Error('Dữ liệu quá lớn');
 const v=JSON.parse(s);if(!v||typeof v!=='object'||Array.isArray(v))throw Error('JSON không hợp lệ');return v;
}
export function validateRows(v:Obj,confirm:boolean):Row[]{
 if(typeof v.filename!=='string'||v.filename.length>180||!v.filename.toLowerCase().endsWith('.xlsx')||typeof v.sheet!=='string'||!v.sheet.trim()||v.sheet.length>80)throw Error('File/sheet không hợp lệ');
 if(!Array.isArray(v.rows)||v.rows.length<1||v.rows.length>2000)throw Error('Mỗi lần nhập 1–2000 dòng');
 const seen=new Set<string>();const out:Row[]=[];
 for(const raw of v.rows){
  if(!raw||typeof raw!=='object'||Array.isArray(raw))throw Error('Dòng không hợp lệ');
  const r=raw as Obj,n=r.row_number,code=normalizedCode(r.company_code),q=r.quantity;
  if(!Number.isInteger(n)||Number(n)<1||Number(n)>1048576)throw Error('Số dòng không hợp lệ');
  if(!code)throw Error('Dòng '+n+': mã CTY phải là text');
  if(seen.has(code))throw Error('Dòng '+n+': mã trùng '+code);
  if(typeof q!=='number'||!Number.isSafeInteger(q)||q<0||q>2147483647)throw Error('Dòng '+n+': tồn phải là số nguyên không âm');
  if(confirm&&(!Number.isInteger(r.product_version)||Number(r.product_version)<0))throw Error('Thiếu phiên bản sản phẩm');
  seen.add(code);out.push({company_code:code,quantity:q,row_number:Number(n),product_version:confirm?Number(r.product_version):0});
 }return out.sort((a,b)=>a.company_code.localeCompare(b.company_code));
}
async function hash(v:unknown){return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(JSON.stringify(v)))),x=>x.toString(16).padStart(2,'0')).join('');}
export async function inventoryRoutes(req:Request,env:{DATABASE_URL:string},actor:Actor,url:URL):Promise<Response|null>{
 const path=url.pathname;if(!path.startsWith('/api/v1/inventory'))return null;
 if(!actor.admin)return bad('Chỉ Admin nhập và hoàn tác tồn kho',403);
 const db=neon(env.DATABASE_URL);
 if(path==='/api/v1/inventory/batches'&&req.method==='GET'){
  const rows=await db`SELECT id,filename,sheet,actor_sub,row_count,status,applied_at,rolled_back_at,rolled_back_by FROM inventory_batches ORDER BY applied_revision DESC LIMIT 50`;
  const [state]=await db`SELECT revision,latest_batch FROM inventory_state WHERE id=1`;return json({items:rows,state});
 }
 const detail=/^\/api\/v1\/inventory\/batches\/([a-f0-9-]{36})$/i.exec(path);
 if(detail&&isId(detail[1])&&req.method==='GET'){
  const items=await db`SELECT company_code,row_number,old_quantity,new_quantity,old_snapshot_at,created_product FROM inventory_batch_rows WHERE batch_id=${detail[1]}::uuid ORDER BY row_number`;return json({items});
 }
 if(req.method!=='POST')return bad('Endpoint không tồn tại',404);
 let v:Obj;try{v=await read(req);}catch(e){return bad(e instanceof Error?e.message:'JSON không hợp lệ');}
 try{
  if(path==='/api/v1/inventory/preview'){
   const rows=validateRows(v,false);
   const result=await db`SELECT st.revision,x.company_code,x.quantity,x.row_number,coalesce(p.version,0) AS product_version,p.name,p.unit,p.active,s.quantity AS old_quantity,s.snapshot_at AS old_snapshot_at
    FROM inventory_state st CROSS JOIN jsonb_to_recordset(${JSON.stringify(rows)}::jsonb) AS x(company_code text,quantity bigint,row_number integer)
    LEFT JOIN catalog_products p ON p.company_code=x.company_code LEFT JOIN inventory_stock s ON s.product_id=p.id WHERE st.id=1 ORDER BY x.row_number`;
   return json({revision:result[0].revision,items:result,can_confirm:result.every(x=>x.active!==false)});
  }
  if(path==='/api/v1/inventory/confirm'){
   const rows=validateRows(v,true);
   if(!isId(v.client_ref)||typeof v.revision!=='string'&&!Number.isSafeInteger(v.revision)||!/^\d+$/.test(String(v.revision)))return bad('Thiếu UUID hoặc revision');
   const digest=await hash({filename:v.filename,sheet:v.sheet,revision:String(v.revision),rows});
   const [x]=await db`SELECT public.inventory_apply(${actor.sub},${v.client_ref}::uuid,${String(v.filename)},${String(v.sheet)},${digest},${String(v.revision)}::bigint,${JSON.stringify(rows)}::jsonb) AS item`;return json({item:x.item});
  }
  if(path==='/api/v1/inventory/rollback'){
   if(!isId(v.batch_id)||!isId(v.client_ref))return bad('UUID không hợp lệ');
   const [x]=await db`SELECT public.inventory_rollback(${actor.sub},${v.batch_id}::uuid,${v.client_ref}::uuid) AS item`;return json({item:x.item});
  }
  return bad('Endpoint không tồn tại',404);
 }catch(e){const m=e instanceof Error?e.message:String(e);
  if(m.includes('inventory_forbidden'))return bad('Không có quyền Admin',403);
  if(m.includes('inventory_missing'))return bad('Không tìm thấy lần nhập',404);
  if(m.includes('inventory_edited'))return bad('Mã tạm đã được chỉnh sửa; không hoàn tác để tránh ghi đè',409);
  if(m.includes('inventory_stale')||m.includes('inventory_conflict')||m.includes('duplicate key'))return bad('Danh mục/tồn đã đổi hoặc thao tác trùng; xem trước lại',409);
  if(m.includes('inventory_invalid'))return bad('Dữ liệu nhập không hợp lệ');
  if(m.includes('Dòng ')||m.includes('File/sheet')||m.includes('Mỗi lần nhập')||m.includes('Số dòng')||m.includes('Thiếu phiên bản'))return bad(m);
  console.error('inventory operation failed');return bad('Không xử lý được nhập tồn; chưa xác nhận thành công',500);
 }
}
