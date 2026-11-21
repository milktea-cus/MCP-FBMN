import {neon} from '@neondatabase/serverless';
import {cleanJpeg} from './surveys';
import type {AuthEnv} from './auth';

type Actor={sub:string;admin:boolean;manager:boolean};
type Env=AuthEnv&{PHOTOS_BUCKET?:R2Bucket};
const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[1-8][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i;
const json=(value:unknown,status=200)=>new Response(JSON.stringify(value),{status,
 headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const bad=(error:string,status=400)=>json({error},status);
async function hash(bytes:ArrayBuffer):Promise<string>{
 return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),
  n=>n.toString(16).padStart(2,'0')).join('');
}
function photo(raw:unknown,max:number):ArrayBuffer{
 if(typeof raw!=='string'||raw.length>Math.ceil(max/3)*4+4||
  !/^[A-Za-z0-9+/]+={0,2}$/.test(raw))throw Error('photo format');
 const bytes=Uint8Array.from(atob(raw),c=>c.charCodeAt(0));
 if(bytes.length<100||bytes.length>max)throw Error('photo size');
 return bytes.buffer;
}
export async function marketProspectMediaRoutes(req:Request,env:Env,actor:Actor,url:URL):Promise<Response|null>{
 const match=/^\/api\/v1\/market-prospects\/([a-f0-9-]{36})\/photos(?:\/([a-f0-9-]{36}))?$/i.exec(url.pathname);
 if(!match)return null;
 const lead=match[1],id=match[2];
 if(!uuid.test(lead)||(id&&!uuid.test(id)))return bad('Mã ảnh/điểm bán không hợp lệ');
 const db=neon(env.DATABASE_URL);
 if(req.method==='GET'){
  if(id){
   if(!env.PHOTOS_BUCKET)return bad('Kho R2 chưa cấu hình',503);
   const rows=await db`SELECT f.object_key,f.thumbnail_key FROM public.field_market_prospect_photos f
     JOIN public.field_prospects p ON p.id=f.prospect_id
     WHERE f.id=${id}::uuid AND f.prospect_id=${lead}::uuid AND f.status='ready'
      AND p.province IS NOT NULL
      AND (${actor.admin} OR p.owner_sub=${actor.sub} OR
       (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},p.owner_sub)))
      AND public.sales_can_access(${actor.sub},p.owner_sub,p.province,p.district) LIMIT 1`;
   if(!rows.length)return bad('Không có ảnh hoặc không có quyền',404);
   const key=url.searchParams.get('thumbnail')==='1'?rows[0].thumbnail_key:rows[0].object_key;
   const file=await env.PHOTOS_BUCKET.get(key);
   if(!file)return bad('Ảnh không còn trên R2',404);
   return new Response(file.body,{headers:{'Content-Type':'image/jpeg','Cache-Control':'private, no-store',
    'X-Content-Type-Options':'nosniff'}});
  }
  const rows=await db`SELECT f.id,f.kind,f.bytes,f.captured_at FROM public.field_market_prospect_photos f
    JOIN public.field_prospects p ON p.id=f.prospect_id
    WHERE p.id=${lead}::uuid AND f.status='ready' AND p.province IS NOT NULL
     AND (${actor.admin} OR p.owner_sub=${actor.sub} OR
       (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},p.owner_sub)))
     AND public.sales_can_access(${actor.sub},p.owner_sub,p.province,p.district)
    ORDER BY f.captured_at DESC LIMIT 12`;
  return json({items:rows});
 }
 if(req.method!=='POST'||id)return bad('Method not allowed',405);
 if(!env.PHOTOS_BUCKET)return bad('Kho R2 chưa cấu hình',503);
 const imageId=req.headers.get('X-Upload-Id')??'',kind=req.headers.get('X-Photo-Kind')??'';
 const rawDate=req.headers.get('X-Captured-At')??'';
 const stamp=Date.parse(rawDate);
 if(!uuid.test(imageId)||!['front','shelf','goods','other'].includes(kind)||
  !Number.isFinite(stamp)||stamp>Date.now()+60000||stamp<Date.now()-30*86400000)
  return bad('Mã, loại hoặc thời gian ảnh không hợp lệ');
 if(!req.headers.get('Content-Type')?.includes('application/json'))
  return bad('Chỉ chấp nhận JPEG đã nén',415);
 const raw=await req.text();
 if(raw.length>3200000)return bad('Ảnh quá lớn',413);
 let bytes:ArrayBuffer,thumb:ArrayBuffer,sha:string,thumbSha:string;
 try{
  const x=JSON.parse(raw) as Record<string,unknown>;
  bytes=photo(x.image,2097152);thumb=photo(x.thumbnail,153600);
  if(!cleanJpeg(new Uint8Array(bytes),1600)||!cleanJpeg(new Uint8Array(thumb),320))
   return bad('JPEG chứa metadata hoặc vượt kích thước',415);
  sha=await hash(bytes);thumbSha=await hash(thumb);
  if(x.sha256!==sha||x.thumbnail_sha256!==thumbSha)return bad('Sai checksum',422);
 }catch{return bad('Ảnh nén không hợp lệ',422);}
 let row:Record<string,unknown>;
 try{
  const result=await db`SELECT public.sales_market_prospect_reserve_photo(
   ${actor.sub},${lead}::uuid,${imageId}::uuid,${kind},
   ${new Date(stamp).toISOString()}::timestamptz,${bytes.byteLength},${sha},
   ${thumb.byteLength},${thumbSha}) AS item`;
  row=result[0].item as Record<string,unknown>;
 }catch(e){
  const m=(e as Error).message??'';
  if(m.includes('forbidden'))return bad('Không có quyền với điểm bán',403);
  if(m.includes('conflict')||m.includes('limit'))return bad('Ảnh trùng hoặc quá số lượng cho phép',409);
  if(m.includes('invalid'))return bad('Ảnh không hợp lệ');
  return bad('Không đăng ký được ảnh',503);
 }
 if(row.status==='ready')return json({item:{id:imageId,kind},idempotent:true});
 try{
  for(const [key,buffer,expected] of [
   [String(row.object_key),bytes,sha],[String(row.thumbnail_key),thumb,thumbSha],
  ] as [string,ArrayBuffer,string][]){
   await env.PHOTOS_BUCKET.put(key,buffer,{onlyIf:{etagDoesNotMatch:'*'},
    httpMetadata:{contentType:'image/jpeg'},customMetadata:{sha256:expected}});
   const head=await env.PHOTOS_BUCKET.head(key);
   if(!head||head.size!==buffer.byteLength||head.customMetadata?.sha256!==expected)
    return bad('Ảnh chưa xác nhận trên R2; thử đồng bộ lại',503);
  }
  await db`SELECT public.sales_market_prospect_finalize_photo(
   ${actor.sub},${imageId}::uuid,${sha}) AS item`;
  return json({item:{id:imageId,kind}},201);
 }catch(e){
  if((e as Error).message?.includes('forbidden'))return bad('Quyền điểm bán đã thay đổi',403);
  return bad('R2 chưa hoàn tất, thử đồng bộ lại',503);
 }
}
