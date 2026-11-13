import {neon} from '@neondatabase/serverless';
import type {AuthEnv} from './auth';
import {cleanJpeg} from './surveys';
type Actor={sub:string;admin:boolean;manager:boolean};
type MediaEnv=AuthEnv&{PHOTOS_BUCKET?:R2Bucket};
const json=(value:unknown,status=200)=>new Response(JSON.stringify(value),{
 status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const bad=(message:string,status=400)=>json({error:message},status);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
async function digest(bytes:ArrayBuffer):Promise<string>{
 return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),
  n=>n.toString(16).padStart(2,'0')).join('');
}
function photoBytes(value:unknown,max:number):ArrayBuffer{
 if(typeof value!=='string'||value.length>Math.ceil(max/3)*4+4||
  !/^[A-Za-z0-9+/]+={0,2}$/.test(value))throw Error('photo base64');
 const decoded=Uint8Array.from(atob(value),c=>c.charCodeAt(0));
 if(decoded.length<100||decoded.length>max)throw Error('photo size');
 return decoded.buffer;
}
function time(value:unknown):string|null{
 if(typeof value!=='string'||value.length>40)return null;
 const n=Date.parse(value);
 if(!Number.isFinite(n)||n>Date.now()+60000||n<Date.now()-30*86400000)return null;
 return new Date(n).toISOString();
}
export async function areaVisitMediaRoutes(req:Request,env:MediaEnv,actor:Actor,url:URL):Promise<Response|null>{
 const match=/^\/api\/v1\/area-visits\/([0-9a-f-]{36})\/photos(?:\/([0-9a-f-]{36}))?$/i.exec(url.pathname);
 if(!match)return null;
 const visitId=match[1],photoId=match[2];
 if(!uuid.test(visitId)||(photoId&&!uuid.test(photoId)))return bad('UUID không hợp lệ');
 const db=neon(env.DATABASE_URL);
 if(req.method==='GET'){
  if(photoId){
   if(!env.PHOTOS_BUCKET)return bad('Kho ảnh chưa cấu hình',503);
   const rows=await db`SELECT p.object_key,p.thumbnail_key,p.mime_type
    FROM public.field_area_visit_photos p
    JOIN public.field_area_visits v ON v.id=p.area_visit_id
    WHERE p.id=${photoId}::uuid AND p.area_visit_id=${visitId}::uuid
     AND p.status='ready' AND (
      v.owner_sub=${actor.sub} OR ${actor.admin} OR
      (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},v.owner_sub)))
    LIMIT 1`;
   if(!rows.length)return bad('Không có ảnh hoặc quyền đã thay đổi',404);
   const thumb=url.searchParams.get('thumbnail')==='1';
   const object=await env.PHOTOS_BUCKET.get(thumb?rows[0].thumbnail_key:rows[0].object_key);
   if(!object)return bad('Ảnh không còn trên kho',404);
   return new Response(object.body,{headers:{'Content-Type':'image/jpeg',
    'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'}});
  }
  const rows=await db`SELECT p.id,p.kind,p.bytes,p.sha256,p.captured_at,p.status,
    p.thumbnail_bytes,p.thumbnail_sha256
   FROM public.field_area_visit_photos p
   JOIN public.field_area_visits v ON v.id=p.area_visit_id
   WHERE v.id=${visitId}::uuid AND p.status='ready' AND
    (v.owner_sub=${actor.sub} OR ${actor.admin} OR
     (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},v.owner_sub)))
   ORDER BY p.captured_at,p.id LIMIT 12`;
  return json({items:rows});
 }
 if(req.method!=='POST'||photoId)return bad('Method not allowed',405);
 if(!env.PHOTOS_BUCKET)return bad('Kho ảnh chưa cấu hình',503);
 const id=req.headers.get('X-Upload-Id')??'',
  kind=req.headers.get('X-Photo-Kind')??'',
  taken=time(req.headers.get('X-Captured-At'));
 if(!uuid.test(id)||!['front','shelf','goods','other'].includes(kind)||!taken)
  return bad('UUID, loại hoặc thời gian ảnh không hợp lệ');
 const ctype=req.headers.get('Content-Type')??'';
 if(!ctype.includes('application/json'))return bad('Ảnh phải ở định dạng JPEG sạch',415);
 const body=await req.text();
 if(body.length>3200000)return bad('Ảnh quá lớn',413);
 let original:ArrayBuffer,thumbnail:ArrayBuffer,sha:string,tsha:string;
 try{
  const data=JSON.parse(body) as Record<string,unknown>;
  original=photoBytes(data.image,2097152);
  thumbnail=photoBytes(data.thumbnail,153600);
  if(!cleanJpeg(new Uint8Array(original),1600)||!cleanJpeg(new Uint8Array(thumbnail),320))
   return bad('Ảnh JPEG chứa metadata hoặc quá kích thước',415);
  sha=await digest(original);tsha=await digest(thumbnail);
  if(sha!==data.sha256||tsha!==data.thumbnail_sha256)return bad('Checksum ảnh không khớp',422);
 }catch{return bad('Ảnh nén không hợp lệ',422);}
 let stored:Record<string,unknown>;
 try{
  const result=await db`SELECT public.sales_reserve_area_photo(
   ${actor.sub},${visitId}::uuid,${id}::uuid,${kind},${taken}::timestamptz,
   ${original.byteLength},${sha},${thumbnail.byteLength},${tsha}) AS item`;
  stored=result[0].item as Record<string,unknown>;
 }catch(e){
  const message=(e as Error).message??'';
  if(message.includes('permission'))return bad('Không được giao điểm công tác',403);
  if(message.includes('conflict')||message.includes('limit'))return bad('Ảnh trùng UUID hoặc quá 12 ảnh',409);
  if(message.includes('invalid'))return bad('Thông tin ảnh không hợp lệ');
  return bad('Không tạo được bằng chứng ảnh',503);
 }
 if(stored.status==='ready')return json({item:{id,kind,sha256:sha},idempotent:true});
 const key=String(stored.object_key),thumbKey=String(stored.thumbnail_key);
 try{
  await env.PHOTOS_BUCKET.put(key,original,{onlyIf:{etagDoesNotMatch:'*'},
   httpMetadata:{contentType:'image/jpeg'},customMetadata:{sha256:sha}});
  const evidence=await env.PHOTOS_BUCKET.head(key);
  if(!evidence||evidence.size!==original.byteLength||evidence.customMetadata?.sha256!==sha)
   return bad('R2 chưa xác nhận ảnh; đồng bộ lại',503);
  await env.PHOTOS_BUCKET.put(thumbKey,thumbnail,{onlyIf:{etagDoesNotMatch:'*'},
   httpMetadata:{contentType:'image/jpeg'},customMetadata:{sha256:tsha}});
  const check=await env.PHOTOS_BUCKET.head(thumbKey);
  if(!check||check.size!==thumbnail.byteLength||check.customMetadata?.sha256!==tsha)
   return bad('R2 chưa xác nhận thumbnail; đồng bộ lại',503);
  await db`SELECT public.sales_finalize_area_photo(${actor.sub},${id}::uuid,${sha}) AS item`;
  return json({item:{id,kind,sha256:sha}},201);
 }catch(e){
  if((e as Error).message?.includes('permission'))return bad('Quyền công tác đã thu hồi',403);
  return bad('Ảnh chưa xác nhận trên R2; hãy đồng bộ lại',503);
 }
}
