import {neon, type NeonQueryFunction} from '@neondatabase/serverless';
import districts from './districts_old.json';
import {cleanJpeg} from './surveys';

export interface CustomerEnv {
  DATABASE_URL: string;
  PHOTOS_BUCKET?: R2Bucket;
}
export interface Actor { sub: string; admin: boolean; manager: boolean }
const areas = districts as Record<string, string[]>;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: {'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store'},
});
const fail = (error: string, status = 400) => response({error}, status);
type Db = NeonQueryFunction<false, false>;
type ObjectBody = Record<string, unknown>;
async function photoDigest(bytes:ArrayBuffer):Promise<string>{
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),v=>v.toString(16).padStart(2,'0')).join('');
}
function photoBase64(value:unknown,max:number):ArrayBuffer{
  if(typeof value!=='string'||value.length>Math.ceil(max/3)*4+4||!/^[A-Za-z0-9+/]+={0,2}$/.test(value))throw Error('base64');
  const bytes=Uint8Array.from(atob(value),c=>c.charCodeAt(0));
  if(!bytes.length||bytes.length>max)throw Error('size');
  return bytes.buffer;
}

function str(x: unknown, max = 240): string | null {
  if (typeof x !== 'string') return null;
  const s = x.trim();
  return s.length > 0 && s.length <= max ? s : null;
}
function optional(x: unknown, max = 240): string | null {
  if (x === null || x === undefined || x === '') return null;
  return str(x, max);
}
function point(lat: unknown, lon: unknown, accuracy?: unknown): boolean {
  return typeof lat === 'number' && Number.isFinite(lat) && lat >= -90 && lat <= 90
    && typeof lon === 'number' && Number.isFinite(lon) && lon >= -180 && lon <= 180
    && (accuracy === undefined || accuracy === null ||
      (typeof accuracy === 'number' && Number.isFinite(accuracy) && accuracy >= 0 && accuracy <= 10000));
}
function area(province: unknown, district: unknown) {
  return typeof province === 'string' && typeof district === 'string' &&
    !!areas[province]?.includes(district);
}
async function validArea(db:Db,province:unknown,district:unknown):Promise<boolean>{
  if(area(province,district))return true;
  if(typeof province!=='string'||typeof district!=='string'||!province||!district)return false;
  const rows=await db`SELECT 1 FROM public.territory_catalog p
    JOIN public.territory_catalog d ON d.parent_code=p.code
    WHERE p.level='province' AND d.level='district' AND p.active AND d.active
      AND p.name=${province} AND d.name=${district} LIMIT 1`;
  return rows.length>0;
}

async function input(req: Request): Promise<ObjectBody> {
  if (!req.headers.get('content-type')?.toLowerCase().includes('application/json')) throw Error('JSON required');
  const raw = await req.text();
  if (raw.length > 16000) throw Error('Body too large');
  const data = JSON.parse(raw) as unknown;
  if (!data || typeof data !== 'object' || Array.isArray(data)) throw Error('Invalid object');
  return data as ObjectBody;
}
async function inScope(db: Db, actor: Actor, province: string, district: string) {
  const rows = await db`SELECT public.sales_can_access(${actor.sub},${actor.sub},${province},${district}) AS allowed`;
  return rows[0]?.allowed === true;
}
async function fetchCustomer(db: Db, actor: Actor, id: string) {
  const rows = await db`SELECT c.* FROM customers c WHERE c.id=${id}::uuid AND
    public.sales_customer_allowed(${actor.sub},c.id,'view') LIMIT 1`;
  return rows[0] ?? null;
}
function dataError(data: ObjectBody) {
  if (!str(data.name) || !str(data.address_line, 500)) return 'Thiếu tên hoặc địa chỉ điểm bán';
  // Territory membership is validated against legacy and nationwide DB catalogs at the write boundary.
  if (data.client_ref !== undefined && !uuid.test(String(data.client_ref))) return 'client_ref không hợp lệ';
  if (data.code !== undefined && data.code !== null && !str(data.code, 80)) return 'Mã điểm bán không hợp lệ';
  if (data.phone !== undefined && data.phone !== null && data.phone !== '' && !/^[0-9+(). -]{8,20}$/.test(String(data.phone)))
    return 'Số điện thoại không hợp lệ';
  if (data.category !== undefined && !['tap_hoa', 'sieu_thi', 'dai_ly', 'npp', 'nha_sach', 'van_phong_pham', 'cua_hang', 'truong_hoc', 'khach_le', 'khac'].includes(String(data.category)))
    return 'Loại điểm bán không hợp lệ';
  if (data.status !== undefined && !['active', 'inactive', 'potential'].includes(String(data.status)))
    return 'Trạng thái không hợp lệ';
  if (data.location_source !== null && data.location_source !== undefined &&
    !['gps','manual','map_link'].includes(String(data.location_source)))return 'Nguồn tọa độ không hợp lệ';
  if ((data.latitude !== null && data.latitude !== undefined) || (data.longitude !== null && data.longitude !== undefined)) {
    if (!point(data.latitude, data.longitude, data.location_accuracy_m)) return 'Tọa độ không hợp lệ';
    if (data.location_consent !== true) return 'Chưa xác nhận quyền dùng vị trí';
    if(data.location_source!==null&&data.location_source!==undefined&&
       data.location_source!=='gps'&&data.location_accuracy_m!==null&&data.location_accuracy_m!==undefined)
      return 'Tọa độ nhập tay/link không được mang sai số GPS';
  } else if(data.location_source!==null&&data.location_source!==undefined) {
    return 'Nguồn vị trí cần có đủ vĩ độ và kinh độ';
  }
  return null;
}
function distanceMeters(a: number, b: number, c: number, d: number) {
  const rad = Math.PI / 180;
  const da = (c-a)*rad, db=(d-b)*rad;
  const s = Math.sin(da/2)**2 + Math.cos(a*rad)*Math.cos(c*rad)*Math.sin(db/2)**2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(s), Math.sqrt(Math.max(0,1-s)));
}

/** Authenticated routes. Return null for a non-customer path. No data is shared by default. */
export async function customerRoutes(req: Request, env: CustomerEnv, actor: Actor, url: URL): Promise<Response | null> {
  if (!url.pathname.startsWith('/api/v1/customers')) return null;
  if (!env.DATABASE_URL) return fail('Database chưa được cấu hình', 503);
  const db = neon(env.DATABASE_URL);
  if (url.pathname === '/api/v1/customers') {
    if (req.method === 'GET') {
      const limit = Math.min(100, Math.max(1, Number(url.searchParams.get('limit')||30)));
      const offset = Math.min(10000, Math.max(0, Number(url.searchParams.get('offset')||0)));
      if (!Number.isInteger(limit) || !Number.isInteger(offset)) return fail('Pagination không hợp lệ');
      const rows = await db`SELECT c.id,c.client_ref,c.owner_sub,c.name,c.code,c.field_code,c.category,
          c.contact_name,c.phone,c.address_line,c.province,c.district,c.latitude,c.longitude,
          c.location_accuracy_m,c.location_consent,c.location_source,c.location_recorded_by,c.location_recorded_at,
           c.note,c.status,c.version,c.created_at,c.updated_at,
           public.sales_customer_plannable(${actor.sub},c.id) AS can_plan
        FROM customers c WHERE public.sales_customer_allowed(${actor.sub},c.id,'view')
          AND (${!url.searchParams.get('province')} OR c.province=${url.searchParams.get('province')??''})
        ORDER BY c.updated_at DESC,c.id DESC LIMIT ${limit} OFFSET ${offset}`;
      return response({items:rows,limit,offset});
    }
    if (req.method === 'POST') {
      let data: ObjectBody; try {data=await input(req);}catch{return fail('JSON không hợp lệ');}
      const error=dataError(data); if(error)return fail(error);
      if (!uuid.test(String(data.client_ref??'')))return fail('client_ref UUID bắt buộc để chống đồng bộ trùng');
      const province=String(data.province),district=String(data.district);
      if(!await validArea(db,province,district))return fail('Tỉnh/huyện không hợp lệ');
      if (!await inScope(db,actor,province,district)) return fail('Chưa được phân địa bàn này',403);
      const name=str(data.name)!,address=str(data.address_line,500)!;
      const code=optional(data.code,80),contact=optional(data.contact_name),phone=optional(data.phone,20),note=optional(data.note,2000);
      const lat=data.latitude as number|null|undefined,lon=data.longitude as number|null|undefined,acc=data.location_accuracy_m as number|null|undefined;
      const consent=data.location_consent===true;
      const hasPoint=lat!==null&&lat!==undefined&&lon!==null&&lon!==undefined;
      const source=hasPoint?(data.location_source??(acc!==null&&acc!==undefined?'gps':null)):null;
      const rows=await db`INSERT INTO customers(client_ref,owner_sub,created_by_sub,name,code,category,contact_name,phone,
          address_line,province,district,latitude,longitude,location_accuracy_m,location_consent,
          location_source,location_recorded_by,location_recorded_at,note,status)
        SELECT ${String(data.client_ref)}::uuid,${actor.sub},${actor.sub},${name},${code},${data.category??'tap_hoa'},${contact},${phone},
          ${address},${province},${district},${lat??null},${lon??null},${acc??null},${consent},
          ${source},${hasPoint?actor.sub:null},${hasPoint?new Date().toISOString():null}::timestamptz,${note},${data.status??'active'}
        WHERE public.sales_can_access(${actor.sub},${actor.sub},${province},${district})
        ON CONFLICT(owner_sub,client_ref) DO NOTHING RETURNING *`;
      const existing=rows.length?rows:await db`SELECT * FROM customers WHERE owner_sub=${actor.sub} AND client_ref=${String(data.client_ref)}::uuid AND public.sales_customer_allowed(${actor.sub},id,'view')`;
      if(!existing.length) return fail('Không có quyền với bản ghi đã tồn tại',403);
      if(rows.length) await db`INSERT INTO field_audit_events(actor_sub,action,entity_type,entity_id) VALUES (${actor.sub},'create','customer',${rows[0].id}::uuid)`;
      return response({item:existing[0],idempotent:rows.length===0},rows.length?201:200);
    }
    return fail('Method not allowed',405);
  }
  const match=/^\/api\/v1\/customers\/([a-f0-9-]{36})(?:\/(visits|photos|media|cover)(?:\/([a-f0-9-]{36}))?)?$/i.exec(url.pathname);
  if (!match || !uuid.test(match[1])) return fail('Endpoint không tồn tại',404);
  const id=match[1];
  const current=await fetchCustomer(db,actor,id);
  if(!current) return fail('Không tìm thấy điểm bán hoặc không có quyền',404);
  if (!match[2] && req.method==='GET') return response({item:current});
  if (!match[2] && req.method==='PATCH') {
    const writePermission=await db`SELECT public.sales_customer_allowed(${actor.sub},${id}::uuid,'edit') AS allowed`;
     if(writePermission[0]?.allowed!==true)return fail('Không có quyền sửa khách hàng',403);
    let data: ObjectBody;try{data=await input(req);}catch{return fail('JSON không hợp lệ');}
    if(data.client_ref!==undefined&&!uuid.test(String(data.client_ref)))return fail('client_ref không hợp lệ');
    if(data.client_ref&&current.last_mutation_ref===data.client_ref)return response({item:current,idempotent:true});
    if (!Number.isInteger(data.version) || Number(data.version)!==Number(current.version)) return fail('Dữ liệu đã thay đổi, vui lòng tải lại',409);
    const merged:ObjectBody={...current,...data};
    const error=dataError(merged);if(error)return fail(error);
    const province=String(merged.province),district=String(merged.district);
    if(!await validArea(db,province,district))return fail('Tỉnh/huyện không hợp lệ');
    if((province!==current.province||district!==current.district)&&!await inScope(db,actor,province,district))
       return fail('Chuyển địa bàn cần quyền trên địa bàn mới',403);
    const requestedLocation=data.latitude!==undefined||data.longitude!==undefined||
      data.location_source!==undefined;
    const newSource=data.location_source===undefined?current.location_source:data.location_source;
    const locationChanged=requestedLocation&&
      (merged.latitude!==current.latitude||merged.longitude!==current.longitude||
       newSource!==current.location_source);
    if(locationChanged){
      if(!point(merged.latitude,merged.longitude,merged.location_accuracy_m)||data.location_consent!==true)
        return fail('Cần tọa độ hợp lệ và xác nhận quyền lưu vị trí',400);
      if((newSource==='manual'||newSource==='map_link')&&merged.location_accuracy_m!=null)
        return fail('Nguồn nhập tay/link không được mang sai số GPS');
      if(current.latitude!==null&&current.longitude!==null){
        if(data.location_override_confirmed!==true)
          return fail('Mốc hiện có được bảo vệ. Cần xác nhận thay đổi vị trí.',409);
        if((current.location_source===null||current.location_source==='gps')&&newSource!=='gps')
          return fail('Mốc GPS hiện có chỉ được thay bằng GPS thiết bị đã xác nhận',409);
      }
    }
    const rows=await db`UPDATE customers SET name=${str(merged.name)!},code=${optional(merged.code,80)},category=${merged.category},
        contact_name=${optional(merged.contact_name)},phone=${optional(merged.phone,20)},address_line=${str(merged.address_line,500)!},
        province=${province},district=${district},latitude=${merged.latitude??null},longitude=${merged.longitude??null},
        location_accuracy_m=${merged.location_accuracy_m??null},location_consent=${merged.location_consent===true},
        location_source=${newSource??null},
        location_recorded_by=CASE WHEN ${locationChanged} THEN ${actor.sub} ELSE location_recorded_by END,
        location_recorded_at=CASE WHEN ${locationChanged} THEN now() ELSE location_recorded_at END,
        note=${optional(merged.note,2000)},status=${merged.status},last_mutation_ref=${data.client_ref??null}::uuid,version=version+1,updated_at=now()
      WHERE id=${id}::uuid AND version=${data.version as number} AND public.sales_customer_allowed(${actor.sub},id,'edit') RETURNING *`;
    if(!rows.length)return fail('Xung đột phiên bản',409);
    await db`INSERT INTO field_audit_events(actor_sub,action,entity_type,entity_id) VALUES (${actor.sub},'update','customer',${id}::uuid)`;
    return response({item:rows[0]});
  }
  if(match[2]==='cover') {
    if(req.method!=='PATCH'||match[3])return fail('Method not allowed',405);
    const coverAllowed=await db`SELECT public.sales_customer_allowed(${actor.sub},${id}::uuid,'media') AS allowed`;
     if(coverAllowed[0]?.allowed!==true)return fail('Không có quyền quản lý ảnh',403);
    let data:ObjectBody;try{data=await input(req);}catch{return fail('JSON không hợp lệ');}
    const photoId=String(data.photo_id??'');
    if(!uuid.test(photoId))return fail('Mã ảnh không hợp lệ');
    if(current.cover_photo_id===photoId)return response({item:{id,cover_photo_id:photoId},idempotent:true});
    const rows=await db`UPDATE customers c SET cover_photo_id=${photoId}::uuid
      WHERE c.id=${id}::uuid AND public.sales_customer_allowed(${actor.sub},c.id,'media')
        AND EXISTS(SELECT 1 FROM customer_photos p WHERE p.id=${photoId}::uuid
          AND p.customer_id=c.id AND p.owner_sub=c.owner_sub)
      RETURNING c.id,c.cover_photo_id`;
    if(!rows.length)return fail('Ảnh không thuộc điểm bán hoặc không có quyền',404);
    await db`INSERT INTO field_audit_events(actor_sub,action,entity_type,entity_id)
      VALUES (${actor.sub},'set_cover','customer',${id}::uuid)`;
    return response({item:rows[0]});
  }
  if(match[2]==='media') {
    if(req.method!=='GET'||match[3])return fail('Method not allowed',405);
    // Customer profile photos only. Survey media lives inside its owning session.
    const rows=await db`SELECT p.id,'customer'::text AS source,'store'::text AS kind,
      NULL::uuid AS session_id,p.created_at AS captured_at,p.mime_type,p.bytes,
      (p.id=c.cover_photo_id) AS is_cover
      FROM customer_photos p JOIN customers c ON c.id=p.customer_id
      WHERE p.customer_id=${id}::uuid
        AND public.sales_customer_allowed(${actor.sub},c.id,'media')
      ORDER BY captured_at DESC,p.id DESC LIMIT 300`;
    return response({items:rows});
  }
  if (match[2]==='visits') {
    if (req.method==='GET') {
      const rows=await db`SELECT id,customer_id,owner_sub,checkin_at,latitude,longitude,accuracy_m,distance_m,note
        FROM field_visits WHERE customer_id=${id}::uuid AND public.sales_customer_allowed(${actor.sub},${id}::uuid,'view') ORDER BY checkin_at DESC LIMIT 100`;
      return response({items:rows});
    }
    if (req.method!=='POST' || match[3])return fail('Method not allowed',405);
    if(current.owner_sub!==actor.sub)return fail('Chỉ check-in khách hàng của mình',403);
    let data:ObjectBody;try{data=await input(req);}catch{return fail('JSON không hợp lệ');}
    if(!uuid.test(String(data.client_ref??'')))return fail('client_ref UUID bắt buộc');
    if(!point(data.latitude,data.longitude,data.accuracy_m) || typeof data.accuracy_m!=='number' || data.accuracy_m>100)
      return fail('GPS cần độ chính xác tối đa 100m');
    if(!current.location_consent || current.latitude===null || current.longitude===null)
      return fail('Điểm bán chưa có tọa độ được phép sử dụng',409);
    const distance=distanceMeters(current.latitude,current.longitude,data.latitude as number,data.longitude as number);
    if(distance>200)return fail('Vị trí check-in ngoài bán kính 200m',422);
    const captured=typeof data.captured_at==='string'?Date.parse(data.captured_at):Date.now();
    if(!Number.isFinite(captured)||captured>Date.now()+60000||captured<Date.now()-30*86400000)return fail('Thời gian ghi nhận GPS không hợp lệ',422);
    const rows=await db`INSERT INTO field_visits(customer_id,owner_sub,client_ref,latitude,longitude,accuracy_m,distance_m,note,checkin_at)
      SELECT ${id}::uuid,${actor.sub},${String(data.client_ref)}::uuid,${data.latitude as number},${data.longitude as number},
        ${data.accuracy_m},${distance},${optional(data.note,2000)},${new Date(captured).toISOString()}::timestamptz
      WHERE EXISTS(SELECT 1 FROM customers c WHERE c.id=${id}::uuid AND public.sales_customer_allowed(${actor.sub},c.id,'view'))
      ON CONFLICT(owner_sub,client_ref) DO NOTHING RETURNING *`;
    const existing=rows.length?rows:await db`SELECT * FROM field_visits WHERE owner_sub=${actor.sub} AND client_ref=${String(data.client_ref)}::uuid AND customer_id=${id}::uuid`;
    if(!existing.length)return fail('client_ref đã dùng cho điểm bán khác',409);
    if(rows.length)await db`INSERT INTO field_audit_events(actor_sub,action,entity_type,entity_id) VALUES (${actor.sub},'checkin','visit',${rows[0].id}::uuid)`;
    return response({item:existing[0],idempotent:rows.length===0},rows.length?201:200);
  }
  if(match[2]==='photos') {
    if(req.method==='GET' && !match[3]) {
      const rows=await db`SELECT id,mime_type,bytes,created_at FROM customer_photos
        WHERE customer_id=${id}::uuid AND public.sales_customer_allowed(${actor.sub},${id}::uuid,'media') ORDER BY created_at DESC LIMIT 100`;
      return response({items:rows});
    }
    if(req.method==='GET' && match[3] && uuid.test(match[3])) {
      if(!env.PHOTOS_BUCKET)return fail('Kho ảnh chưa được cấu hình',503);
      const rows=await db`SELECT object_key,mime_type FROM customer_photos WHERE id=${match[3]}::uuid AND customer_id=${id}::uuid AND public.sales_customer_allowed(${actor.sub},${id}::uuid,'media') LIMIT 1`;
      if(!rows.length)return fail('Không tìm thấy ảnh',404);
      const thumb=url.searchParams.get('thumbnail')==='1'
        ?await env.PHOTOS_BUCKET.get(rows[0].object_key+'/thumbnail'):null;
      const blob=thumb??await env.PHOTOS_BUCKET.get(rows[0].object_key);
      if(!blob)return fail('Ảnh không còn trên kho',404);
      return new Response(blob.body,{headers:{'Content-Type':thumb?'image/jpeg':rows[0].mime_type,'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'}});
    }
    if(req.method==='POST' && !match[3]) {
      const uploadAllowed=await db`SELECT public.sales_customer_allowed(${actor.sub},${id}::uuid,'media') AS allowed`;
      if(uploadAllowed[0]?.allowed!==true)return fail('Không có quyền thêm ảnh',403);
      if(!env.PHOTOS_BUCKET)return fail('Kho ảnh chưa được cấu hình',503);
      const uploadId=req.headers.get('X-Upload-Id');
      if(!uploadId || !uuid.test(uploadId))return fail('Thiếu X-Upload-Id UUID');
      const headerMime=req.headers.get('content-type')?.toLowerCase()??'';
      const modern=headerMime==='application/json';
      const mime=modern?'image/jpeg':headerMime;
      if(!['image/jpeg','image/png','image/webp'].includes(mime))return fail('Chỉ nhận JPG/PNG/WebP',415);
      let bytes:ArrayBuffer,thumbnail:ArrayBuffer|null=null,sha:string,thumbHash:string|null=null;
      if(modern){
        try {
          if(Number(req.headers.get('content-length')??0)>3200000)return fail('Ảnh quá giới hạn',413);
          const body=await req.text();if(body.length>3200000)return fail('Ảnh quá giới hạn',413);
          const data=JSON.parse(body);
          bytes=photoBase64(data.image,2097152);thumbnail=photoBase64(data.thumbnail,153600);
          if(!cleanJpeg(new Uint8Array(bytes),1600)||!cleanJpeg(new Uint8Array(thumbnail),320))
            return fail('JPEG có metadata hoặc kích thước không hợp lệ',415);
          sha=await photoDigest(bytes);thumbHash=await photoDigest(thumbnail);
          if(data.sha256!==sha||data.thumbnail_sha256!==thumbHash)return fail('Checksum không khớp',422);
        }catch{return fail('Dữ liệu ảnh không hợp lệ',422);}
      }else{
        bytes=await req.arrayBuffer();
        if(bytes.byteLength<1||bytes.byteLength>5*1024*1024)return fail('Ảnh cần nhỏ hơn 5MB',413);
        const binary=new Uint8Array(bytes);
        const isJpeg=mime==='image/jpeg'&&binary[0]===0xff&&binary[1]===0xd8;
        const isPng=mime==='image/png'&&binary[0]===0x89&&binary[1]===0x50&&binary[2]===0x4e&&binary[3]===0x47;
        const isWebp=mime==='image/webp'&&String.fromCharCode(...binary.slice(0,4))==='RIFF'&&String.fromCharCode(...binary.slice(8,12))==='WEBP';
        if(!isJpeg&&!isPng&&!isWebp)return fail('Nội dung ảnh không đúng định dạng',415);
        sha=await photoDigest(bytes);
      }
      const prior=await db`SELECT id,mime_type,bytes,object_key FROM customer_photos WHERE id=${uploadId}::uuid AND customer_id=${id}::uuid LIMIT 1`;
      if(prior.length){
        const existing=await env.PHOTOS_BUCKET.head(prior[0].object_key);
        if(modern&&existing?.customMetadata?.sha256!==sha)return fail('UUID ảnh đã sử dụng với nội dung khác',409);
        return response({item:prior[0],idempotent:true});
      }
      const key=`customers/${id}/${uploadId}`;
      await env.PHOTOS_BUCKET.put(key,bytes,{onlyIf:{etagDoesNotMatch:'*'},httpMetadata:{contentType:mime},customMetadata:{sha256:sha}});
      const head=await env.PHOTOS_BUCKET.head(key);
      if(!head||head.size!==bytes.byteLength||head.customMetadata?.sha256!==sha)return fail('Kho ảnh chưa xác nhận; thử lại',503);
      if(thumbnail&&thumbHash){
        await env.PHOTOS_BUCKET.put(key+'/thumbnail',thumbnail,{onlyIf:{etagDoesNotMatch:'*'},httpMetadata:{contentType:'image/jpeg'},customMetadata:{sha256:thumbHash}});
        const h=await env.PHOTOS_BUCKET.head(key+'/thumbnail');
        if(!h||h.size!==thumbnail.byteLength||h.customMetadata?.sha256!==thumbHash)return fail('Thumbnail chưa xác nhận; thử lại',503);
      }
      try {
        const rows=await db`INSERT INTO customer_photos(id,customer_id,owner_sub,object_key,mime_type,bytes)
          SELECT ${uploadId}::uuid,${id}::uuid,${current.owner_sub},${key},${mime},${bytes.byteLength} WHERE EXISTS(SELECT 1 FROM customers c WHERE c.id=${id}::uuid AND public.sales_customer_allowed(${actor.sub},c.id,'media')) ON CONFLICT(id) DO NOTHING RETURNING id,mime_type,bytes,created_at`;
        if(!rows.length){const existing=await db`SELECT id,mime_type,bytes FROM customer_photos WHERE id=${uploadId}::uuid AND customer_id=${id}::uuid AND owner_sub=${current.owner_sub}`;if(existing.length)return response({item:existing[0],idempotent:true});return fail('Không thể lưu ảnh',409);}
        await db`INSERT INTO field_audit_events(actor_sub,action,entity_type,entity_id) VALUES (${actor.sub},'upload','photo',${uploadId}::uuid)`;
        return response({item:rows[0]},201);
      }catch(e){throw e;}
    }
  }
  return fail('Method not allowed',405);
}