import {neon,type NeonQueryFunction} from '@neondatabase/serverless';
import districts from './districts_old.json';

type Db=NeonQueryFunction<false,false>;
type Env={DATABASE_URL:string;PHOTOS_BUCKET?:R2Bucket};
type Actor={sub:string;admin:boolean;manager:boolean};
type Question={id:string;label:string;type:'text'|'number'|'boolean'|'choice';required:boolean;options?:string[]};
type Body=Record<string,unknown>;
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const areas=districts as Record<string,string[]>;
const photoKinds=['front','shelf','goods','other'];
const json=(value:unknown,status=200)=>new Response(JSON.stringify(value),{status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const bad=(error:string,status=400)=>json({error},status);
const isUuid=(v:unknown):v is string=>typeof v==='string'&&uuid.test(v);
function date(value:unknown):string|null{
 if(typeof value!=='string')return null;const t=Date.parse(value);
 return Number.isFinite(t)?new Date(t).toISOString():null;
}
function dayKey(value:unknown):string|null{
 if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value))return null;
 const d=date(value);return d?.slice(0,10)===value?value:null;
}
function captureTime(v:unknown):string|null{
 const d=date(v);if(!d)return null;const t=Date.parse(d);
 return t<=Date.now()+60000&&t>=Date.now()-30*86400000?d:null;
}
function vnDay(d:string){return new Date(Date.parse(d)+7*3600000).toISOString().slice(0,10);}
async function body(req:Request):Promise<Body>{
 if(!req.headers.get('content-type')?.includes('application/json'))throw Error('JSON required');
 const raw=await req.text();if(raw.length>64000)throw Error('large body');
 const v=JSON.parse(raw);if(!v||typeof v!=='object'||Array.isArray(v))throw Error('object required');return v;
}
function point(a:unknown,b:unknown,c:unknown):boolean{
 return typeof a==='number'&&Number.isFinite(a)&&a>=-90&&a<=90&&typeof b==='number'&&Number.isFinite(b)&&b>=-180&&b<=180&&typeof c==='number'&&Number.isFinite(c)&&c>=0&&c<=100;
}
function meters(a:number,b:number,c:number,d:number){
 const rad=Math.PI/180;const s=Math.sin((c-a)*rad/2)**2+Math.cos(a*rad)*Math.cos(c*rad)*Math.sin((d-b)*rad/2)**2;
 return 6371000*2*Math.atan2(Math.sqrt(s),Math.sqrt(Math.max(0,1-s)));
}
function questions(value:unknown):Question[]|null{
 if(!Array.isArray(value)||value.length<1||value.length>50)return null;
 const out:Question[]=[];const seen=new Set<string>();
 for(const q of value){
  if(!q||typeof q!=='object'||typeof q.id!=='string'||!/^([a-z][a-z0-9_]{0,39})$/.test(q.id)||seen.has(q.id)||typeof q.label!=='string'||!q.label.trim()||q.label.length>160||!['text','number','boolean','choice'].includes(q.type)||typeof q.required!=='boolean')return null;
  let options:string[]|undefined;
  if(q.type==='choice'){if(!Array.isArray(q.options)||q.options.length<2||q.options.length>50||q.options.some((v:unknown)=>typeof v!=='string'||!v.trim()||v.length>120)||new Set(q.options).size!==q.options.length)return null;options=q.options;}
  seen.add(q.id);out.push({id:q.id,label:q.label.trim(),type:q.type,required:q.required,...(options?{options}:{})});
 }
 return out;
}
export function validateSurveyAnswers(template:Question[],value:unknown):string|null{
 if(!value||typeof value!=='object'||Array.isArray(value))return 'Checklist không hợp lệ';
 const answers=value as Body, ids=new Set(template.map(q=>q.id));
 if(Object.keys(answers).some(k=>!ids.has(k)))return 'Checklist có câu hỏi không thuộc mẫu';
 for(const q of template){
  const v=answers[q.id];
  if(v===undefined||v===null||v===''){if(q.required)return 'Thiếu: '+q.label;continue;}
  if(q.type==='text'&&(typeof v!=='string'||!v.trim()||v.length>2000)||q.type==='number'&&(typeof v!=='number'||!Number.isFinite(v)||v<0)||q.type==='boolean'&&typeof v!=='boolean'||q.type==='choice'&&(typeof v!=='string'||!q.options?.includes(v)))return 'Câu trả lời không hợp lệ: '+q.label;
 }
 return null;
}
async function getSession(db:Db,actor:Actor,id:string){
 const rows=await db`SELECT s.*,c.name AS customer_name,t.version AS template_version,t.questions
 FROM field_survey_sessions s JOIN customers c ON c.id=s.customer_id JOIN field_survey_templates t ON t.id=s.template_id
 WHERE s.id=${id}::uuid AND public.sales_can_access(${actor.sub},s.owner_sub,s.province,s.district) AND public.sales_can_access(${actor.sub},c.owner_sub,c.province,c.district)`;
 return rows[0]??null;
}
async function sessionPhotos(db:Db,id:string){
 return db`SELECT id,kind,mime_type,bytes,sha256,captured_at,created_by,status FROM field_survey_photos WHERE session_id=${id}::uuid ORDER BY captured_at,id`;
}
function signature(mime:string,b:Uint8Array){
 return mime==='image/jpeg'&&b[0]===255&&b[1]===216&&b[b.length-2]===255&&b[b.length-1]===217||
 mime==='image/png'&&b[0]===137&&b[1]===80&&b[2]===78&&b[3]===71||
 mime==='image/webp'&&String.fromCharCode(...b.slice(0,4))==='RIFF'&&String.fromCharCode(...b.slice(8,12))==='WEBP';
}
async function digest(b:ArrayBuffer){return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',b)),v=>v.toString(16).padStart(2,'0')).join('');}
export async function surveyRoutes(req:Request,env:Env,actor:Actor,url:URL):Promise<Response|null>{
 const path=url.pathname;
 if(path!=='/api/v1/survey-templates'&&path!=='/api/v1/sessions'&&!path.startsWith('/api/v1/sessions/'))return null;
 const db=neon(env.DATABASE_URL);
 if(path==='/api/v1/survey-templates'){
  if(req.method==='GET'){
   const province=url.searchParams.get('province')??'';
   if(province&&!areas[province])return bad('Tỉnh không hợp lệ');
   const rows=await db`SELECT DISTINCT ON (province) id,province,version,questions,created_at FROM field_survey_templates
   WHERE (${!province} OR province=${province}) AND (${actor.admin} OR EXISTS(SELECT 1 FROM staff_scopes sc WHERE sc.user_sub=${actor.sub} AND sc.province=field_survey_templates.province))
   ORDER BY province,version DESC`;
   return json({items:rows});
  }
  if(req.method!=='POST')return bad('Method not allowed',405);
  if(!actor.admin)return bad('Chỉ Admin thiết lập mẫu',403);
  let v:Body;try{v=await body(req);}catch{return bad('JSON không hợp lệ');}
  const province=String(v.province??''),qs=questions(v.questions);
  if(!areas[province]||!qs||!isUuid(v.client_ref)||!Number.isInteger(v.expected_version)||Number(v.expected_version)<0)return bad('Mẫu, tỉnh hoặc phiên bản không hợp lệ');
  const prior=await db`SELECT * FROM field_survey_templates WHERE id=${v.client_ref}::uuid AND province=${province}`;
  if(prior.length)return json({item:prior[0],idempotent:true});
  const rows=await db`INSERT INTO field_survey_templates(id,province,version,questions,created_by)
   SELECT ${v.client_ref}::uuid,${province},${Number(v.expected_version)+1},${JSON.stringify(qs)}::jsonb,${actor.sub}
   WHERE coalesce((SELECT max(version) FROM field_survey_templates WHERE province=${province}),0)=${Number(v.expected_version)}
   ON CONFLICT DO NOTHING RETURNING *`;
  return rows.length?json({item:rows[0]},201):bad('Mẫu đã thay đổi; tải lại trước khi lưu',409);
 }
 if(path==='/api/v1/sessions'&&req.method==='GET'){
  const province=url.searchParams.get('province')??'',customer=url.searchParams.get('customer_id')??'';
  const day=url.searchParams.get('day')??'',period=url.searchParams.get('period')??'day';
  if(province&&!areas[province]||customer&&!isUuid(customer)||day&&!dayKey(day)||!['day','week','month'].includes(period))return bad('Bộ lọc không hợp lệ');
  let start=day,end=day;
  if(day&&period==='week'){const d=new Date(day+'T00:00:00Z');d.setUTCDate(d.getUTCDate()-(d.getUTCDay()+6)%7);start=d.toISOString().slice(0,10);d.setUTCDate(d.getUTCDate()+6);end=d.toISOString().slice(0,10);}
  if(day&&period==='month'){const d=new Date(day+'T00:00:00Z');start=day.slice(0,7)+'-01';end=new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth()+1,0)).toISOString().slice(0,10);}
  const rows=await db`SELECT s.*,c.name AS customer_name,t.version AS template_version,t.questions FROM field_survey_sessions s
   JOIN customers c ON c.id=s.customer_id JOIN field_survey_templates t ON t.id=s.template_id
   WHERE public.sales_can_access(${actor.sub},s.owner_sub,s.province,s.district) AND public.sales_can_access(${actor.sub},c.owner_sub,c.province,c.district)
   AND (${!province} OR s.province=${province}) AND (${!customer} OR s.customer_id::text=${customer})
   AND (${!day} OR (s.started_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN ${start||'2000-01-01'}::date AND ${end||'2100-01-01'}::date)
   ORDER BY s.started_at DESC,s.id LIMIT 501`;
  return json({items:rows.slice(0,500),truncated:rows.length>500});
 }
 if(path==='/api/v1/sessions'&&req.method==='POST'){
  let v:Body;try{v=await body(req);}catch{return bad('JSON không hợp lệ');}
  const id=v.client_ref,cid=v.customer_id,tid=v.template_id,rid=v.route_stop_id??null,started=captureTime(v.started_at);
  if(!isUuid(id)||!isUuid(cid)||!isUuid(tid)||(rid!==null&&!isUuid(rid))||!started||!point(v.latitude,v.longitude,v.accuracy_m))return bad('Phiên hoặc GPS không hợp lệ (độ chính xác tối đa 100m)');
  const prior=await getSession(db,actor,id);
  if(prior)return prior.owner_sub===actor.sub&&prior.customer_id===cid&&prior.template_id===tid&&(prior.route_stop_id??null)===rid?json({item:prior,idempotent:true}):bad('UUID phiên đã được sử dụng',409);
  const customers=await db`SELECT c.* FROM customers c WHERE c.id=${cid}::uuid AND c.owner_sub=${actor.sub} AND public.sales_can_access(${actor.sub},c.owner_sub,c.province,c.district)`;
  const c=customers[0];if(!c)return bad('Không có quyền điểm bán',403);
  if(!c.location_consent||c.latitude===null||c.longitude===null)return bad('Điểm bán chưa có tọa độ được phép dùng',409);
  const distance=meters(c.latitude,c.longitude,v.latitude as number,v.longitude as number);
  if(distance>200)return bad('GPS ngoài bán kính 200m',422);
  const template=await db`SELECT id FROM field_survey_templates WHERE id=${tid}::uuid AND province=${c.province}`;
  if(!template.length)return bad('Mẫu không thuộc tỉnh điểm bán',409);
  if(rid){const stops=await db`SELECT id FROM sales_records WHERE id=${rid}::uuid AND kind='visit' AND owner_sub=${actor.sub} AND data->>'customerId'=${cid} AND data->>'plannedDate'=${vnDay(started)} AND public.sales_can_access(${actor.sub},owner_sub,province,district)`;if(!stops.length)return bad('Điểm ghé không thuộc tuyến/ngày thực tế',409);}
  // One transaction: verified GPS history and parent session share the stable client UUID.
  const rows=await db`WITH created AS (
   INSERT INTO field_survey_sessions(id,customer_id,owner_sub,province,district,route_stop_id,template_id,started_at,latitude,longitude,accuracy_m,distance_m)
   SELECT ${id}::uuid,c.id,${actor.sub},c.province,c.district,${rid}::uuid,${tid}::uuid,${started}::timestamptz,${v.latitude as number},${v.longitude as number},${v.accuracy_m as number},${distance}
   FROM customers c WHERE c.id=${cid}::uuid AND c.owner_sub=${actor.sub} AND c.province=${c.province} AND c.district=${c.district}
   AND public.sales_can_access(${actor.sub},c.owner_sub,c.province,c.district)
   AND (${rid===null} OR EXISTS(SELECT 1 FROM sales_records r WHERE r.id=${rid}::uuid AND r.kind='visit' AND r.owner_sub=${actor.sub} AND r.data->>'customerId'=${cid} AND r.data->>'plannedDate'=${vnDay(started)}))
   ON CONFLICT(id) DO NOTHING RETURNING *
  ), gps AS (
   INSERT INTO field_visits(customer_id,owner_sub,client_ref,checkin_at,latitude,longitude,accuracy_m,distance_m,note)
   SELECT customer_id,owner_sub,id,started_at,latitude,longitude,accuracy_m,distance_m,'Phiên khảo sát' FROM created RETURNING id
  ) SELECT created.* FROM created JOIN gps ON true`;
  const item=await getSession(db,actor,id);
  if(!item||item.owner_sub!==actor.sub||item.customer_id!==cid||item.template_id!==tid||(item.route_stop_id??null)!==rid)return bad('Xung đột phiên hoặc quyền',409);
  return json({item,idempotent:!rows.length},rows.length?201:200);
 }
 const m=/^\/api\/v1\/sessions\/([a-f0-9-]{36})(?:\/(photos)(?:\/([a-f0-9-]{36}))?)?$/i.exec(path);
 if(!m||!isUuid(m[1])||m[3]&&!isUuid(m[3]))return bad('Endpoint không tồn tại',404);
 const id=m[1],s=await getSession(db,actor,id);
 if(!s)return bad('Không tìm thấy phiên hoặc không có quyền',404);
 if(!m[2]&&req.method==='GET')return json({item:s,photos:await sessionPhotos(db,id)});
 if(!m[2]&&req.method==='PATCH'){
  if(s.owner_sub!==actor.sub)return bad('Chỉ chủ phiên được sửa',403);
  let v:Body;try{v=await body(req);}catch{return bad('JSON không hợp lệ');}
  const end=captureTime(v.ended_at);
  if(!isUuid(v.client_ref)||!Number.isInteger(v.version)||!end||Date.parse(end)<Date.parse(s.started_at)||typeof v.note!=='string'||v.note.length>4000)return bad('Thời gian hoặc phiên bản không hợp lệ');
  if(s.last_mutation_ref===v.client_ref)return json({item:s,idempotent:true});
  if(s.status!=='in_progress'||Number(s.version)!==v.version)return bad('Phiên đã thay đổi hoặc đã hoàn thành',409);
  const err=validateSurveyAnswers(s.questions as Question[],v.answers);if(err)return bad(err);
  const [,rows]=await db.transaction([
   db`SELECT id FROM field_survey_sessions WHERE id=${id}::uuid FOR UPDATE`,
   db`UPDATE field_survey_sessions s SET answers=${JSON.stringify(v.answers)}::jsonb,note=${v.note},ended_at=${end}::timestamptz,status='completed',version=version+1,last_mutation_ref=${v.client_ref}::uuid
    WHERE s.id=${id}::uuid AND s.owner_sub=${actor.sub} AND s.version=${v.version as number} AND s.status='in_progress'
    AND public.sales_can_access(${actor.sub},s.owner_sub,s.province,s.district)
    AND EXISTS(SELECT 1 FROM customers c WHERE c.id=s.customer_id AND public.sales_can_access(${actor.sub},c.owner_sub,c.province,c.district))
    AND NOT EXISTS(SELECT 1 FROM field_survey_photos p WHERE p.session_id=s.id AND p.status<>'ready')
    AND (SELECT count(DISTINCT p.kind) FROM field_survey_photos p WHERE p.session_id=s.id AND p.status='ready' AND p.kind IN ('front','shelf','goods'))=3 RETURNING *`
  ]);
  if(!rows.length)return bad('Chưa đủ ảnh mặt tiền/quầy kệ/hàng hóa, hoặc phiên/quyền đã thay đổi',409);
  return json({item:rows[0]});
 }
 if(m[2]==='photos'){
  if(req.method==='GET'&&!m[3])return json({items:await sessionPhotos(db,id)});
  if(req.method==='GET'&&m[3]){
   if(!env.PHOTOS_BUCKET)return bad('Kho ảnh chưa cấu hình',503);
   const rows=await db`SELECT object_key,mime_type FROM field_survey_photos WHERE id=${m[3]}::uuid AND session_id=${id}::uuid AND status='ready'`;
   if(!rows.length)return bad('Không tìm thấy ảnh',404);
   const blob=await env.PHOTOS_BUCKET.get(rows[0].object_key);if(!blob)return bad('Ảnh không còn trên kho',404);
   return new Response(blob.body,{headers:{'Content-Type':rows[0].mime_type,'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'}});
  }
  if(req.method!=='POST'||m[3])return bad('Method not allowed',405);
  if(s.owner_sub!==actor.sub)return bad('Chỉ chủ phiên thêm ảnh',403);
  if(!env.PHOTOS_BUCKET)return bad('Kho ảnh chưa cấu hình',503);
  const photoId=req.headers.get('X-Upload-Id'),kind=req.headers.get('X-Photo-Kind')??'',captured=captureTime(req.headers.get('X-Captured-At')),mime=req.headers.get('content-type')??'';
  if(!isUuid(photoId)||!photoKinds.includes(kind)||!captured||Date.parse(captured)<Date.parse(s.started_at)-60000||!['image/jpeg','image/png','image/webp'].includes(mime))return bad('Metadata ảnh không hợp lệ');
  if(Number(req.headers.get('content-length')??0)>5242880)return bad('Ảnh quá 5MB',413);
  const raw=await req.arrayBuffer();if(raw.byteLength<4||raw.byteLength>5242880)return bad('Ảnh quá giới hạn',413);
  if(!signature(mime,new Uint8Array(raw)))return bad('Nội dung ảnh sai định dạng',415);
  const sha=await digest(raw),key='sessions/'+id+'/'+photoId+'/'+sha;
  // Reserve a DB row first. Serialize reserve/complete on the session row; never delete an object on retry.
  const [,reserved,existing]=await db.transaction([
   db`SELECT id FROM field_survey_sessions WHERE id=${id}::uuid FOR UPDATE`,
   db`INSERT INTO field_survey_photos(id,session_id,kind,mime_type,bytes,sha256,object_key,captured_at,created_by)
   SELECT ${photoId}::uuid,s.id,${kind},${mime},${raw.byteLength},${sha},${key},${captured}::timestamptz,${actor.sub}
   FROM field_survey_sessions s JOIN customers c ON c.id=s.customer_id WHERE s.id=${id}::uuid AND s.owner_sub=${actor.sub} AND s.status='in_progress'
   AND public.sales_can_access(${actor.sub},s.owner_sub,s.province,s.district) AND public.sales_can_access(${actor.sub},c.owner_sub,c.province,c.district)
   AND (SELECT count(*) FROM field_survey_photos p WHERE p.session_id=s.id)<12 ON CONFLICT(id) DO NOTHING RETURNING *`,
   db`SELECT * FROM field_survey_photos WHERE id=${photoId}::uuid AND session_id=${id}::uuid AND created_by=${actor.sub}`
  ]);
  const row=reserved[0]??existing[0];
  if(!row||row.sha256!==sha||row.kind!==kind||row.mime_type!==mime)return bad('Ảnh trùng UUID khác nội dung, phiên đã đóng hoặc quá 12 ảnh',409);
  if(row.status==='ready')return json({item:{id:photoId,kind,sha256:sha},idempotent:true});
  await env.PHOTOS_BUCKET.put(key,raw,{onlyIf:{etagDoesNotMatch:'*'},httpMetadata:{contentType:mime},customMetadata:{sha256:sha}});
  const head=await env.PHOTOS_BUCKET.head(key);
  if(!head||head.size!==raw.byteLength||head.customMetadata?.sha256!==sha)return bad('Kho ảnh chưa xác nhận; thử lại',503);
  const ready=await db`UPDATE field_survey_photos p SET status='ready' WHERE p.id=${photoId}::uuid AND p.session_id=${id}::uuid AND p.sha256=${sha}
   AND EXISTS(SELECT 1 FROM field_survey_sessions s JOIN customers c ON c.id=s.customer_id WHERE s.id=p.session_id AND s.owner_sub=${actor.sub} AND public.sales_can_access(${actor.sub},s.owner_sub,s.province,s.district) AND public.sales_can_access(${actor.sub},c.owner_sub,c.province,c.district)) RETURNING id,kind,sha256`;
  return ready.length?json({item:ready[0]},201):bad('Quyền đã thay đổi',403);
 }
 return bad('Method not allowed',405);
}
