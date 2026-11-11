import {neon} from '@neondatabase/serverless';
import {normalizedCode,parseProduct} from './catalog';
type Obj=Record<string,unknown>;
const fields=['name','sku','brand','category','unit'];
const specs=['pieceUnit','packUnit','paperSize','ruling','coverType','packagingNote','unitsPerCarton','unitsPerPack','packsPerCarton','pages','gsm'];
const response=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const bad=(error:string,status=400)=>response({error},status);
export async function catalogImportRoutes(req:Request,env:{DATABASE_URL:string},actor:{sub:string;admin:boolean},url:URL):Promise<Response|null>{
 const path=url.pathname;if(!path.startsWith('/api/v1/catalog/import/'))return null;
 if(!actor.admin)return bad('Chỉ Admin nhập danh mục',403);
 const db=neon(env.DATABASE_URL);
 if(path.endsWith('/history')&&req.method==='GET')return response({items:await db`SELECT id,filename,sheet,row_count,created_at,actor_sub FROM catalog_import_batches ORDER BY created_at DESC LIMIT 50`});
 if(req.method!=='POST'||!['/api/v1/catalog/import/preview','/api/v1/catalog/import/confirm'].includes(path))return bad('Endpoint không tồn tại',404);
 const confirm=path.endsWith('/confirm');
 try{
  const raw=await req.text();if(raw.length>2000000)return bad('Dữ liệu quá lớn');
  const v=JSON.parse(raw) as Obj;
  if(typeof v.filename!=='string'||v.filename.length>180||!v.filename.toLowerCase().endsWith('.xlsx')||typeof v.sheet!=='string'||!v.sheet.trim()||v.sheet.length>80||!Array.isArray(v.rows)||v.rows.length<1||v.rows.length>2000)return bad('File/sheet hoặc số dòng không hợp lệ');
  const seen=new Set<string>(),inputs:{company_code:string;row_number:number;patch:Obj;version:number}[]=[];
  for(const x of v.rows){
   if(!x||typeof x!=='object'||Array.isArray(x))throw Error('Dòng không hợp lệ');
   const code=normalizedCode(x.company_code),n=x.row_number,patch=x.patch;
   if(!code||seen.has(code)||!Number.isInteger(n)||n<1||!patch||typeof patch!=='object'||Array.isArray(patch)||Object.keys(patch).length===0||Object.keys(patch).some(k=>![...fields,...specs].includes(k)))throw Error('Dòng '+n+': mã trùng hoặc mapping không hợp lệ');
   if(Object.values(patch).some(val=>val===null||val===undefined||val===''))throw Error('Dòng '+n+': ô trống phải bỏ qua');
   if(confirm&&(!Number.isInteger(x.version)||x.version<0))throw Error('Dòng '+n+': thiếu version');
   seen.add(code);inputs.push({company_code:code,row_number:n,patch,version:confirm?x.version:0});
  }
  const digest=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(JSON.stringify({filename:v.filename,sheet:v.sheet,rows:inputs})))),x=>x.toString(16).padStart(2,'0')).join('');
  if(confirm){
   if(typeof v.client_ref!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v.client_ref))return bad('Thiếu UUID');
   const prior=await db`SELECT * FROM catalog_import_batches WHERE id=${v.client_ref}::uuid`;
   if(prior.length)return prior[0].actor_sub===actor.sub&&prior[0].request_hash===digest?response({item:prior[0]}):bad('UUID đã dùng',409);
  }
  const existing=await db`SELECT * FROM catalog_products WHERE company_code=ANY(${inputs.map(x=>x.company_code)}::text[])`;
  const byCode=new Map(existing.map(x=>[x.company_code,x]));
  const prepared=[],preview=[];
  for(const x of inputs){
   const old=byCode.get(x.company_code);
   if(confirm&&x.version!==(old?.version??0))return bad('Danh mục đã đổi; xem trước lại',409);
   const merged:Obj={...old,company_code:x.company_code,product_spec:{...(old?.product_spec??{})}};
   for(const [k,value] of Object.entries(x.patch)){if(fields.includes(k))merged[k]=value;else (merged.product_spec as Obj)[k]=value;}
   let product;try{product=parseProduct(merged);}catch(e){throw Error('Dòng '+x.row_number+': '+(e instanceof Error?e.message:'Dữ liệu sai'));}
   const version=old?.version??0;
   const preservedSpec={...(old?.product_spec??{})};
   for(const k of specs)if(k in x.patch)preservedSpec[k]=product.product_spec[k];
   prepared.push({...product,...Object.fromEntries(fields.filter(k=>old&&!(k in x.patch)).map(k=>[k,old![k]])),product_spec:preservedSpec,version});
   preview.push({...x,version,name:product.name,changes:Object.entries(x.patch).map(([k,value])=>({field:k,before:fields.includes(k)?old?.[k]??null:old?.product_spec?.[k]??null,after:value})),is_new:!old});
  }
  if(!confirm)return response({items:preview});
  const [res]=await db`SELECT public.catalog_import_apply(${actor.sub},${String(v.client_ref)}::uuid,${v.filename},${v.sheet},${digest},${JSON.stringify(prepared)}::jsonb) AS item`;
  return response({item:res.item});
 }catch(e){const m=e instanceof Error?e.message:String(e);if(m.includes('catalog_stale')||m.includes('catalog_conflict')||m.includes('duplicate key'))return bad('Danh mục đã đổi; xem trước lại',409);if(m.includes('catalog_forbidden'))return bad('Không có quyền',403);if(m.startsWith('Dòng '))return bad(m);return bad('Không xử lý được file danh mục',400);}
}
