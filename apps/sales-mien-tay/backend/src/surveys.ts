import {neon,type NeonQueryFunction} from '@neondatabase/serverless';
import districts from './districts_old.json';

type Db=NeonQueryFunction<false,false>;
type Env={DATABASE_URL:string;PHOTOS_BUCKET?:R2Bucket};
type Actor={sub:string;admin:boolean;manager:boolean};
type Question={id:string;label:string;type:'text'|'number'|'boolean'|'choice'|'multi_choice';required:boolean;options?:string[];catalog_source?:'brands'};
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
  if(!q||typeof q!=='object'||typeof q.id!=='string'||!/^([a-z][a-z0-9_]{0,39})$/.test(q.id)||seen.has(q.id)||typeof q.label!=='string'||!q.label.trim()||q.label.length>160||!['text','number','boolean','choice','multi_choice'].includes(q.type)||typeof q.required!=='boolean')return null;
  let options:string[]|undefined;
  if(q.type==='choice'||q.type==='multi_choice'){if(!Array.isArray(q.options)||q.options.length<2||q.options.length>50||q.options.some((v:unknown)=>typeof v!=='string'||!v.trim()||v.length>120)||new Set(q.options).size!==q.options.length)return null;options=q.options;}
  if(q.catalog_source!==undefined&&(q.catalog_source!=='brands'||!['choice','multi_choice'].includes(q.type)))return null;
  seen.add(q.id);out.push({id:q.id,label:q.label.trim(),type:q.type,required:q.required,...(options?{options}:{}),...(q.catalog_source?{catalog_source:'brands' as const}:{})});
 }
 return out;
}
/** Old offline clients only provide a comma-separated 'brands' checklist answer.
 * Preserve compatibility, while explicit market_brands:null means skip updates. */
export function marketBrandsFromLegacyAnswers(value:unknown):string[]|null{
 if(!value||typeof value!=='object'||Array.isArray(value))return null;
 const entry=(value as Body).brands;
 if(typeof entry!=='string'&&!Array.isArray(entry))return null;
 const text=typeof entry==='string'?entry:entry.join(',');
 if(!text.trim())return null;
 const excluded=new Set(['khác','không có','không','chưa có','chưa rõ','không rõ','không xác định','none']);
 const names:string[]=[];const known=new Set<string>();
 for(const item of text.split(/[,;\\n/]+|\\s+hoặc\\s+/i)){
  const brand=item.trim().replace(/\\s+/g,' ');
  if(!brand||brand.length>100||excluded.has(brand.toLowerCase()))continue;
  const key=brand.toLocaleLowerCase('vi');
  if(!known.has(key)){known.add(key);names.push(brand);}
  if(names.length===50)break;
 }
 return names;
}
export function validateSurveyAnswers(template:Question[],value:unknown):string|null{
 if(!value||typeof value!=='object'||Array.isArray(value))return 'Checklist không hợp lệ';
 const answers=value as Body, ids=new Set(template.map(q=>q.id));
 if(Object.keys(answers).some(k=>!ids.has(k)))return 'Checklist có câu hỏi không thuộc mẫu';
 for(const q of template){
  const v=answers[q.id];
  if(v===undefined||v===null||v===''||q.type==='multi_choice'&&Array.isArray(v)&&v.length===0){if(q.required)return 'Thiếu: '+q.label;continue;}
  if(q.type==='text'&&(typeof v!=='string'||!v.trim()||v.length>2000)||q.type==='number'&&(typeof v!=='number'||!Number.isFinite(v)||v<0)||q.type==='boolean'&&typeof v!=='boolean'||q.type==='choice'&&(typeof v!=='string'||!q.options?.includes(v))||q.type==='multi_choice'&&(!Array.isArray(v)||v.length>50||new Set(v).size!==v.length||v.some(x=>typeof x!=='string'||!q.options?.includes(x))))return 'Câu trả lời không hợp lệ: '+q.label;
 }
 return null;
}
async function getSession(db:Db,actor:Actor,id:string){
 const rows=await db`SELECT s.*,c.name AS customer_name,t.version AS template_version,t.questions
 FROM field_survey_sessions s JOIN customers c ON c.id=s.customer_id JOIN field_survey_templates t ON t.id=s.template_id
 WHERE s.id=${id}::uuid AND public.sales_customer_allowed(${actor.sub},c.id,'view')`;
 return rows[0]??null;
}
async function sessionPhotos(db:Db,id:string,actor:Actor){
 return db`SELECT p.id,p.kind,p.mime_type,p.bytes,p.sha256,p.thumbnail_bytes,p.thumbnail_sha256,p.captured_at,p.created_by,p.status FROM field_survey_photos p JOIN field_survey_sessions s ON s.id=p.session_id JOIN customers c ON c.id=s.customer_id WHERE p.session_id=${id}::uuid AND (s.owner_sub=${actor.sub} AND public.sales_customer_fieldwork_allowed(${actor.sub},c.id) OR public.sales_customer_allowed(${actor.sub},c.id,'media')) ORDER BY p.captured_at,p.id`;
}
// Inspect JPEG marker segments before SOS; reject metadata and oversized dimensions.
export function cleanJpeg(b:Uint8Array,max:number):boolean{
 if(b.length<12||b[0]!==255||b[1]!==216||b[b.length-2]!==255||b[b.length-1]!==217)return false;
 let i=2,dimensions=false;
 while(i+3<b.length){
  if(b[i++]!==255)return false;while(b[i]===255)i++;
  const m=b[i++];if(m===0xda)return dimensions;
  if(m===0xd9||m===0x00||m===0xe1||m===0xed||m===0xfe)return false;
  if(i+2>b.length)return false;const n=(b[i]<<8)|b[i+1];if(n<2||i+n>b.length)return false;
  if([0xc0,0xc1,0xc2].includes(m)){if(n<8)return false;const h=(b[i+3]<<8)|b[i+4],w=(b[i+5]<<8)|b[i+6];if(!w||!h||w>max||h>max)return false;dimensions=true;}
  i+=n;
 }return false;
}
function base64(v:unknown,max:number):ArrayBuffer{
 if(typeof v!=='string'||v.length>Math.ceil(max/3)*4||!/^[A-Za-z0-9+/]+={0,2}$/.test(v))throw Error('base64');
 const bytes=Uint8Array.from(atob(v),c=>c.charCodeAt(0));if(!bytes.length||bytes.length>max)throw Error('size');return bytes.buffer;
}
function signature(mime:string,b:Uint8Array){
 return mime==='image/jpeg'&&b[0]===255&&b[1]===216&&b[b.length-2]===255&&b[b.length-1]===217||
 mime==='image/png'&&b[0]===137&&b[1]===80&&b[2]===78&&b[3]===71||
 mime==='image/webp'&&String.fromCharCode(...b.slice(0,4))==='RIFF'&&String.fromCharCode(...b.slice(8,12))==='WEBP';
}
async function digest(b:ArrayBuffer){return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',b)),v=>v.toString(16).padStart(2,'0')).join('');}
export async function surveyRoutes(req:Request,env:Env,actor:Actor,url:URL):Promise<Response|null>{
 const path=url.pathname;
 if(path==='/api/v1/admin/media-usage'){
  if(req.method!=='GET')return bad('Method not allowed',405);
  if(!actor.admin)return bad('Chỉ Admin xem kho ảnh',403);
  if(!env.PHOTOS_BUCKET)return bad('Kho ảnh chưa cấu hình',503);
  let cursor:string|undefined,used=0,photo=0,apk=0,other=0,objects=0,complete=false;
  for(let n=0;n<30;n++){const page=await env.PHOTOS_BUCKET.list({limit:1000,cursor});for(const o of page.objects){used+=o.size;objects++;if(/^(apk|releases)\//.test(o.key)||o.key.endsWith('.apk'))apk+=o.size;else if(/^(sessions|customers)\//.test(o.key))photo+=o.size;else other+=o.size;}
   if(!page.truncated){complete=true;break;}cursor=page.cursor;
  }
  const budget=10000000000,percent=used/budget*100;
  return json({used_bytes:used,photo_bytes:photo,apk_bytes:apk,other_bytes:other,objects,budget_bytes:budget,percent,complete,warning:percent>=95?95:percent>=85?85:percent>=70?70:0,retention:'manual approval only'});
 }
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
  // A catalog-backed question snapshots official names in the published version;
  // unchecked free text and expired aliases must never enter a canonical survey.
  if(qs.some(q=>q.catalog_source==='brands')){
   const rows=await db`SELECT name FROM public.market_brands ORDER BY name`;
   const accepted=new Set(rows.map(row=>String(row.name)));
   if(qs.some(q=>q.catalog_source==='brands'&&q.options?.some(name=>!accepted.has(name))))
     return bad('Lựa chọn nhãn hàng đã thay đổi; tải lại danh mục chuẩn',409);
  }
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
   WHERE public.sales_customer_allowed(${actor.sub},c.id,'view')
   AND (${!province} OR s.province=${province}) AND (${!customer} OR s.customer_id::text=${customer})
   AND (${!day} OR (s.started_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN ${start||'2000-01-01'}::date AND ${end||'2100-01-01'}::date)
   ORDER BY s.started_at DESC,s.id LIMIT 501`;
  return json({items:rows.slice(0,500),truncated:rows.length>500});
 }
 if(path==='/api/v1/sessions'&&req.method==='POST'){
  let v:Body;try{v=await body(req);}catch{return bad('JSON không hợp lệ');}
  const id=v.client_ref,cid=v.customer_id,tid=v.template_id,rid=v.route_stop_id??null,drid=v.day_route_stop_id??null,started=captureTime(v.started_at);
  if(!isUuid(id)||!isUuid(cid)||!isUuid(tid)||(rid!==null&&!isUuid(rid))||(drid!==null&&!isUuid(drid))||(rid!==null&&drid!==null)||!started||!point(v.latitude,v.longitude,v.accuracy_m))return bad('Phiên hoặc GPS không hợp lệ (độ chính xác tối đa 100m)');
  // A verified GPS check-in on this exact scheduled stop can be reused for
  // the survey. Reuse is owned, same-day, recent, and coordinates are immutable.
  const visitRef=v.visit_ref??null;
  if(visitRef!==null){
   if(!isUuid(visitRef)||drid===null)return bad('GPS tham chiếu không hợp lệ',400);
   const checkin=await db`SELECT v.client_ref,v.latitude,v.longitude,v.accuracy_m,v.checkin_at
    FROM public.field_visits v
    JOIN public.field_route_stops st ON st.id=v.day_route_stop_id
    WHERE v.client_ref=${visitRef}::uuid AND v.owner_sub=${actor.sub}
      AND v.customer_id=${cid}::uuid AND st.id=${drid}::uuid
      AND st.owner_sub=${actor.sub} AND st.customer_id=${cid}::uuid
      AND (v.checkin_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=${vnDay(started!)}::date
      AND v.checkin_at<=${started!}::timestamptz
      AND v.checkin_at >= (${started!}::timestamptz-interval '12 hours')
    LIMIT 1`;
   if(!checkin.length)return bad('Check-in đã hết hạn hoặc không thuộc điểm ghé',409);
   const existing=checkin[0];
   if(Math.abs(Number(existing.latitude)-Number(v.latitude))>0.0000001
     ||Math.abs(Number(existing.longitude)-Number(v.longitude))>0.0000001
     ||Math.abs(Number(existing.accuracy_m)-Number(v.accuracy_m))>0.000001)
    return bad('GPS không khớp lượt check-in đã xác minh',409);
  }
  const prior=await getSession(db,actor,id);
  if(prior)return prior.owner_sub===actor.sub&&prior.customer_id===cid&&prior.template_id===tid&&(prior.route_stop_id??null)===rid&&(prior.day_route_stop_id??null)===drid?json({item:prior,idempotent:true}):bad('UUID phiên đã được sử dụng',409);
  const customers=await db`SELECT c.* FROM customers c WHERE c.id=${cid}::uuid AND public.sales_customer_fieldwork_allowed(${actor.sub},c.id)`;
  const c=customers[0];if(!c)return bad('Không có quyền điểm bán',403);
  const first=c.latitude===null&&c.longitude===null;
  const initializeCustomer=first&&c.owner_sub===actor.sub;
  if(first&&visitRef!==null)return bad('Mốc GPS đầu tiên chưa được xác nhận',409);
  if(first&&v.initialize_location!==true)return bad('Điểm bán chưa có tọa độ. Cần xác nhận ghi nhận vị trí lần đầu tại điểm bán.',409);
  if(!first&&(!c.location_consent||c.latitude===null||c.longitude===null))return bad('Tọa độ điểm bán chưa được phép sử dụng',409);
  const distance=first?0:meters(c.latitude,c.longitude,v.latitude as number,v.longitude as number);
  if(distance>200)return bad('GPS cách điểm bán '+Math.round(distance)+'m, vượt bán kính 200m. Kiểm tra địa chỉ hoặc tọa độ đã lưu.',422);
  const template=await db`SELECT id FROM field_survey_templates WHERE id=${tid}::uuid AND province=${c.province}`;
  if(!template.length)return bad('Mẫu không thuộc tỉnh điểm bán',409);
  if(rid){const stops=await db`SELECT id FROM sales_records WHERE id=${rid}::uuid AND kind='visit' AND owner_sub=${actor.sub} AND data->>'customerId'=${cid} AND data->>'plannedDate'=${vnDay(started)} AND public.sales_can_access(${actor.sub},owner_sub,province,district)`;if(!stops.length)return bad('Điểm ghé không thuộc tuyến/ngày thực tế',409);}
  if(drid){
   const stops=await db`SELECT s.id FROM public.field_route_stops s
    JOIN public.field_day_routes r ON r.id=s.day_route_id
    JOIN public.field_monthly_plans p ON p.id=r.monthly_plan_id
    WHERE s.id=${drid}::uuid AND s.missed_code IS NULL AND s.stop_kind='customer'
      AND s.customer_id=${cid}::uuid AND s.owner_sub=${actor.sub}
      AND r.owner_sub=${actor.sub} AND r.status='ready' AND p.status='planned'
      AND r.route_date=${vnDay(started)}::date
      AND public.sales_monthly_plan_scope_allowed(${actor.sub},p.scope_kind,p.scope_key,p.province,p.district)`;
   if(!stops.length)return bad('Điểm khảo sát không thuộc tuyến/ngày thực tế',409);
  }
  // One transaction: verified GPS history and parent session share the stable client UUID.
  const rows=await db`WITH eligible AS MATERIALIZED (
   SELECT c.* FROM customers c WHERE c.id=${cid}::uuid AND c.province=${c.province} AND c.district=${c.district}
   AND public.sales_customer_fieldwork_allowed(${actor.sub},c.id)
   AND ((${first} AND c.latitude IS NULL AND c.longitude IS NULL) OR (NOT ${first} AND c.location_consent AND c.latitude IS NOT DISTINCT FROM ${c.latitude}::double precision AND c.longitude IS NOT DISTINCT FROM ${c.longitude}::double precision))
   AND (${rid===null} OR EXISTS(SELECT 1 FROM sales_records r WHERE r.id=${rid}::uuid AND r.kind='visit' AND r.owner_sub=${actor.sub} AND r.data->>'customerId'=${cid} AND r.data->>'plannedDate'=${vnDay(started)}))
   AND (${drid===null} OR EXISTS(SELECT 1 FROM public.field_route_stops st JOIN public.field_day_routes r ON r.id=st.day_route_id JOIN public.field_monthly_plans p ON p.id=r.monthly_plan_id WHERE st.id=${drid}::uuid AND st.missed_code IS NULL AND st.customer_id=${cid}::uuid AND st.owner_sub=${actor.sub} AND st.stop_kind='customer' AND r.owner_sub=${actor.sub} AND r.status='ready' AND p.status='planned' AND r.route_date=${vnDay(started)}::date AND public.sales_monthly_plan_scope_allowed(${actor.sub},p.scope_kind,p.scope_key,p.province,p.district)))
   FOR UPDATE
  ), created AS (
   INSERT INTO field_survey_sessions(id,customer_id,owner_sub,province,district,route_stop_id,day_route_stop_id,template_id,started_at,latitude,longitude,accuracy_m,distance_m,location_initialized)
   SELECT ${id}::uuid,c.id,${actor.sub},c.province,c.district,${rid}::uuid,${drid}::uuid,${tid}::uuid,${started}::timestamptz,${v.latitude as number},${v.longitude as number},${v.accuracy_m as number},${distance},${initializeCustomer}
   FROM eligible c ON CONFLICT(id) DO NOTHING RETURNING *
  ), initialized AS (
   UPDATE customers c SET latitude=s.latitude,longitude=s.longitude,location_accuracy_m=s.accuracy_m,location_consent=true,
      location_source='gps',location_recorded_by=s.owner_sub,location_recorded_at=s.started_at,
      version=c.version+1,updated_at=now()
   FROM created s WHERE c.id=s.customer_id AND s.location_initialized AND c.latitude IS NULL AND c.longitude IS NULL RETURNING c.id
  ), gps AS (
   INSERT INTO field_visits(customer_id,owner_sub,client_ref,checkin_at,latitude,longitude,accuracy_m,distance_m,note,day_route_stop_id)
   SELECT customer_id,owner_sub,id,started_at,latitude,longitude,accuracy_m,distance_m,
    CASE WHEN location_initialized THEN 'Phiên khảo sát · ghi nhận tọa độ lần đầu' ELSE 'Phiên khảo sát' END,day_route_stop_id
   FROM created WHERE ${visitRef===null} AND
    (NOT location_initialized OR EXISTS(SELECT 1 FROM initialized)) RETURNING id
  ) SELECT created.* FROM created
    WHERE ${visitRef!==null} OR EXISTS(SELECT 1 FROM gps)`;
  const item=await getSession(db,actor,id);
  if(!item||item.owner_sub!==actor.sub||item.customer_id!==cid||item.template_id!==tid||(item.route_stop_id??null)!==rid||(item.day_route_stop_id??null)!==drid)return bad('Xung đột phiên hoặc quyền',409);
  return json({item,idempotent:!rows.length},rows.length?201:200);
 }
 const m=/^\/api\/v1\/sessions\/([a-f0-9-]{36})(?:\/(photos)(?:\/([a-f0-9-]{36}))?)?$/i.exec(path);
 if(!m||!isUuid(m[1])||m[3]&&!isUuid(m[3]))return bad('Endpoint không tồn tại',404);
 const id=m[1],s=await getSession(db,actor,id);
 if(!s)return bad('Không tìm thấy phiên hoặc không có quyền',404);
 if(!m[2]&&req.method==='GET')return json({item:s,photos:await sessionPhotos(db,id,actor)});
 if(!m[2]&&req.method==='PATCH'){
  if(s.owner_sub!==actor.sub)return bad('Chỉ chủ phiên được sửa',403);
  let v:Body;try{v=await body(req);}catch{return bad('JSON không hợp lệ');}
  const end=captureTime(v.ended_at);
  if(!isUuid(v.client_ref)||!Number.isInteger(v.version)||!end||Date.parse(end)<Date.parse(s.started_at)||typeof v.note!=='string'||v.note.length>4000)return bad('Thời gian hoặc phiên bản không hợp lệ');
  if(s.last_mutation_ref===v.client_ref)return json({item:s,idempotent:true});
  if(s.status!=='in_progress'||Number(s.version)!==v.version)return bad('Phiên đã thay đổi hoặc đã hoàn thành',409);
  const err=validateSurveyAnswers(s.questions as Question[],v.answers);if(err)return bad(err);
  const marketBrands=v.market_brands===undefined?
   marketBrandsFromLegacyAnswers(v.answers):v.market_brands;
  if(marketBrands!==null&&(
     !Array.isArray(marketBrands)||marketBrands.length>50||
     marketBrands.some(name=>typeof name!=='string'||name.trim().length<1||
        name.trim().length>100||/[\x00-\x1f\x7f]/.test(name))))
   return bad('Danh sách nhãn hàng thị trường không hợp lệ');
  try{
   // Atomic DB function: complete session and replace this customer's market
   // snapshot, but never add repeat observations to an aggregate count.
   const rows=await db`SELECT public.sales_complete_survey_market(
    ${actor.sub},${id}::uuid,${v.client_ref}::uuid,${Number(v.version)},
    ${end}::timestamptz,${v.note},${JSON.stringify(v.answers)}::jsonb,
    ${marketBrands===null?null:JSON.stringify(marketBrands)}::jsonb) AS item`;
   return json({item:rows[0].item});
  }catch(e){
   const reason=String((e as Error).message??'');
   if(reason.includes('market_survey_forbidden'))return bad('Không có quyền khảo sát điểm bán',403);
   if(reason.includes('market_survey_invalid')||reason.includes('market_brand_invalid'))
    return bad('Dữ liệu khảo sát hoặc nhãn hàng không hợp lệ',400);
   if(reason.includes('market_survey_stale')||reason.includes('market_survey_photos')||
      reason.includes('market_survey_not_found'))
    return bad('Ảnh chưa đủ hoặc phiên/quyền đã thay đổi; tải lại',409);
   throw e;
  }
 }
 if(m[2]==='photos'){
  if(req.method==='GET'&&!m[3])return json({items:await sessionPhotos(db,id,actor)});
  if(req.method==='GET'&&m[3]){
   if(!env.PHOTOS_BUCKET)return bad('Kho ảnh chưa cấu hình',503);
   const rows=await db`SELECT p.object_key,p.mime_type,p.thumbnail_key FROM field_survey_photos p JOIN field_survey_sessions s ON s.id=p.session_id JOIN customers c ON c.id=s.customer_id WHERE p.id=${m[3]}::uuid AND p.session_id=${id}::uuid AND p.status='ready' AND (s.owner_sub=${actor.sub} AND public.sales_customer_fieldwork_allowed(${actor.sub},c.id) OR public.sales_customer_allowed(${actor.sub},c.id,'media'))`;
   if(!rows.length)return bad('Không tìm thấy ảnh',404);
   const thumb=url.searchParams.get('thumbnail')==='1'&&rows[0].thumbnail_key;const blob=await env.PHOTOS_BUCKET.get(thumb||rows[0].object_key);if(!blob)return bad('Ảnh không còn trên kho',404);
   return new Response(blob.body,{headers:{'Content-Type':thumb?'image/jpeg':rows[0].mime_type,'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'}});
  }
  if(req.method!=='POST'||m[3])return bad('Method not allowed',405);
  if(s.owner_sub!==actor.sub)return bad('Chỉ chủ phiên thêm ảnh',403);
  if(!env.PHOTOS_BUCKET)return bad('Kho ảnh chưa cấu hình',503);
  const photoId=req.headers.get('X-Upload-Id'),kind=req.headers.get('X-Photo-Kind')??'',captured=captureTime(req.headers.get('X-Captured-At')),contentType=req.headers.get('content-type')??'',modern=contentType.includes('application/json'),mime=modern?'image/jpeg':contentType;
  if(!isUuid(photoId)||!photoKinds.includes(kind)||!captured||Date.parse(captured)<Date.parse(s.started_at)-60000||!['image/jpeg','image/png','image/webp'].includes(mime))return bad('Metadata ảnh không hợp lệ');
  if(Number(req.headers.get('content-length')??0)>5242880)return bad('Ảnh quá 5MB',413);
  let raw:ArrayBuffer,thumbnail:ArrayBuffer|null=null,thash:string|null=null;
  if(modern){try{const body=await req.text();if(body.length>3200000)return bad('Ảnh quá giới hạn',413);const v=JSON.parse(body);
   raw=base64(v.image,2097152);thumbnail=base64(v.thumbnail,153600);
   if(!cleanJpeg(new Uint8Array(raw),1600)||!cleanJpeg(new Uint8Array(thumbnail),320))return bad('JPEG có metadata hoặc kích thước không hợp lệ',415);
   thash=await digest(thumbnail);if(v.sha256!==await digest(raw)||v.thumbnail_sha256!==thash)return bad('Checksum không khớp',422);
  }catch{return bad('Dữ liệu ảnh không hợp lệ',422);}}
  else{raw=await req.arrayBuffer();if(raw.byteLength<4||raw.byteLength>5242880)return bad('Ảnh quá giới hạn',413);if(!signature(mime,new Uint8Array(raw)))return bad('Nội dung ảnh sai định dạng',415);}
  const sha=await digest(raw),key='sessions/'+id+'/'+photoId+'/'+sha,thumbkey=thumbnail?key+'/thumb-'+thash:null;
  // Reserve a DB row first. Serialize reserve/complete on the session row; never delete an object on retry.
  const [,reserved,existing]=await db.transaction([
   db`SELECT id FROM field_survey_sessions WHERE id=${id}::uuid FOR UPDATE`,
   db`INSERT INTO field_survey_photos(id,session_id,kind,mime_type,bytes,sha256,object_key,captured_at,created_by,thumbnail_key,thumbnail_bytes,thumbnail_sha256)
   SELECT ${photoId}::uuid,s.id,${kind},${mime},${raw.byteLength},${sha},${key},${captured}::timestamptz,${actor.sub},${thumbkey},${thumbnail?.byteLength??null},${thash}
   FROM field_survey_sessions s JOIN customers c ON c.id=s.customer_id WHERE s.id=${id}::uuid AND s.owner_sub=${actor.sub} AND s.status='in_progress'
   AND public.sales_customer_allowed(${actor.sub},c.id,'view')
   AND (SELECT count(*) FROM field_survey_photos p WHERE p.session_id=s.id)<12 ON CONFLICT(id) DO NOTHING RETURNING *`,
   db`SELECT * FROM field_survey_photos WHERE id=${photoId}::uuid AND session_id=${id}::uuid AND created_by=${actor.sub}`
  ]);
  const row=reserved[0]??existing[0];
  if(!row||row.sha256!==sha||row.kind!==kind||row.mime_type!==mime||(row.thumbnail_sha256??null)!==thash)return bad('Ảnh trùng UUID khác nội dung, phiên đã đóng hoặc quá 12 ảnh',409);
  if(row.status==='ready')return json({item:{id:photoId,kind,sha256:sha},idempotent:true});
  await env.PHOTOS_BUCKET.put(key,raw,{onlyIf:{etagDoesNotMatch:'*'},httpMetadata:{contentType:mime},customMetadata:{sha256:sha}});
  const head=await env.PHOTOS_BUCKET.head(key);
  if(!head||head.size!==raw.byteLength||head.customMetadata?.sha256!==sha)return bad('Kho ảnh chưa xác nhận; thử lại',503);
  if(thumbnail&&thumbkey&&thash){
   await env.PHOTOS_BUCKET.put(thumbkey,thumbnail,{onlyIf:{etagDoesNotMatch:'*'},httpMetadata:{contentType:'image/jpeg'},customMetadata:{sha256:thash}});
   const h=await env.PHOTOS_BUCKET.head(thumbkey);if(!h||h.size!==thumbnail.byteLength||h.customMetadata?.sha256!==thash)return bad('Thumbnail chưa xác nhận; thử lại',503);
  }
  const ready=await db`UPDATE field_survey_photos p SET status='ready' WHERE p.id=${photoId}::uuid AND p.session_id=${id}::uuid AND p.sha256=${sha}
   AND EXISTS(SELECT 1 FROM field_survey_sessions s JOIN customers c ON c.id=s.customer_id WHERE s.id=p.session_id AND s.owner_sub=${actor.sub} AND public.sales_customer_allowed(${actor.sub},c.id,'view')) RETURNING id,kind,sha256`;
  return ready.length?json({item:ready[0]},201):bad('Quyền đã thay đổi',403);
 }
 return bad('Method not allowed',405);
}
