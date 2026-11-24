import {neon} from '@neondatabase/serverless';
import {validMode,validMinute,pageSize,validCursor} from './notification_policy';
import type {userFromRequest} from './auth';
import {fcmConfigured,registerFcm,unregisterFcm,sendFcm,validFcmToken,validBinding,type FcmReport} from './fcm';

type Actor=Awaited<ReturnType<typeof userFromRequest>>;
type PushEnv={DATABASE_URL:string;FCM_SERVICE_ACCOUNT_JSON?:string;VAPID_PUBLIC_KEY?:string;VAPID_PRIVATE_JWK?:string;VAPID_SUBJECT?:string};
const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{
 status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}
});
const fail=(error:string,status=400)=>reply({error},status);
const encoder=new TextEncoder();
const b64=(bytes:Uint8Array)=>btoa(String.fromCharCode(...bytes)).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
const validEndpoint=(value:unknown):value is string=>{
 if(typeof value!=='string'||value.length>2048||value.length<32)return false;
 try{
  const u=new URL(value);
  if(u.protocol!=='https:'||u.port||u.username||u.password||u.hash)return false;
  const h=u.hostname.toLowerCase();
  return h==='fcm.googleapis.com'||h==='updates.push.services.mozilla.com'||
    h==='web.push.apple.com'||h.endsWith('.push.apple.com')||
    h.endsWith('.notify.windows.com');
 }catch{return false;}
};
function validSubscription(value:unknown):value is {endpoint:string;keys:{p256dh:string;auth:string}}{
 if(!value||typeof value!=='object'||Array.isArray(value))return false;
 const x=value as Record<string,unknown>,keys=x.keys as Record<string,unknown>|undefined;
 return validEndpoint(x.endpoint)&&!!keys&&typeof keys.p256dh==='string'&&
  /^[A-Za-z0-9_-]{80,100}$/.test(keys.p256dh)&&typeof keys.auth==='string'&&
  /^[A-Za-z0-9_-]{16,35}$/.test(keys.auth);
}
async function body(req:Request):Promise<Record<string,unknown>>{
 const txt=await req.text();if(txt.length>6000)throw Error('large');
 const obj=JSON.parse(txt);if(!obj||typeof obj!=='object'||Array.isArray(obj))throw Error('invalid');
 return obj as Record<string,unknown>;
}
async function vapidJwt(env:PushEnv,endpoint:string):Promise<string>{
 if(!env.VAPID_PRIVATE_JWK||!env.VAPID_PUBLIC_KEY||!env.VAPID_SUBJECT)throw Error('push not configured');
 const jwk=JSON.parse(env.VAPID_PRIVATE_JWK) as JsonWebKey;
 const key=await crypto.subtle.importKey('jwk',jwk,{name:'ECDSA',namedCurve:'P-256'},false,['sign']);
 const now=Math.floor(Date.now()/1000);
 const head=b64(encoder.encode(JSON.stringify({typ:'JWT',alg:'ES256'})));
 const claims=b64(encoder.encode(JSON.stringify({
  aud:new URL(endpoint).origin,exp:now+3600,sub:env.VAPID_SUBJECT
 })));
 const unsigned=head+'.'+claims;
 const signature=new Uint8Array(await crypto.subtle.sign({name:'ECDSA',hash:'SHA-256'},key,encoder.encode(unsigned)));
 return unsigned+'.'+b64(signature);
}
/** Empty-payload standard Web Push: private customer details never reach a locked screen. */
async function sendPush(env:PushEnv,endpoint:string):Promise<number>{
 const token=await vapidJwt(env,endpoint);
 const res=await fetch(endpoint,{method:'POST',headers:{
  Authorization:'vapid t='+token+', k='+env.VAPID_PUBLIC_KEY,
  TTL:'3600',Urgency:'normal'
 },signal:AbortSignal.timeout(8000)});
 return res.status;
}
async function fanOutWeb(env:PushEnv,recipient:string):Promise<void>{
 if(!env.VAPID_PUBLIC_KEY||!env.VAPID_PRIVATE_JWK||!env.VAPID_SUBJECT)return;
 const sql=neon(env.DATABASE_URL);
 const subs=await sql`SELECT endpoint FROM field_push_subscriptions WHERE recipient_sub=${recipient}
  ORDER BY updated_at DESC LIMIT 5`;
 await Promise.all(subs.map(async s=>{
  const endpoint=String(s.endpoint);
  if(!validEndpoint(endpoint))return;
  try{
   const status=await sendPush(env,endpoint);
   if(status===404||status===410)await sql`DELETE FROM field_push_subscriptions
    WHERE recipient_sub=${recipient} AND endpoint=${endpoint}`;
  }catch{/* A push service failure cannot undo a business transaction. */}
 }));
}
export async function publishNotification(env:PushEnv,recipient:string,eventKey:string,title:string,description:string):Promise<void>{
 await publishWithReport(env,recipient,eventKey,title,description);
}
async function publishWithReport(env:PushEnv,recipient:string,eventKey:string,title:string,description:string):Promise<FcmReport>{
 if(!recipient||eventKey.length>160)return {accepted:0,failed:0,reason:'invalid_event'};
 const sql=neon(env.DATABASE_URL);
 const inserted=await sql`INSERT INTO field_notifications(recipient_sub,event_key,title,body)
  SELECT s.user_sub,${eventKey},${title},${description}
  FROM staff_members s WHERE s.user_sub=${recipient} AND s.active AND public.sales_identity_exists(s.user_sub)
  ON CONFLICT(recipient_sub,event_key) DO NOTHING RETURNING id`;
 if(!inserted.length)return {accepted:0,failed:0,reason:'not_inserted'};
 const [,android]=await Promise.allSettled([fanOutWeb(env,recipient),sendFcm(env,recipient)]);
 return android.status==='fulfilled'?android.value:{accepted:0,failed:0,reason:'server_error'};
}
export async function notificationRoutes(req:Request,env:PushEnv,u:Actor,url:URL):Promise<Response|null>{
 const path=url.pathname;
 if(!path.startsWith('/api/v1/notifications'))return null;
 const sql=neon(env.DATABASE_URL);
 if(path==='/api/v1/notifications/config'&&req.method==='GET')
  return reply({supported:!!(env.VAPID_PUBLIC_KEY&&env.VAPID_PRIVATE_JWK&&env.VAPID_SUBJECT),
   public_key:env.VAPID_PUBLIC_KEY??null,android_supported:fcmConfigured(env)});
 if(path==='/api/v1/notifications/preferences'&&req.method==='GET'){
  const [categories,settings]=await Promise.all([
   sql`SELECT c.category,c.default_mode,c.mandatory,
     CASE WHEN c.mandatory AND p.mode='off' THEN 'in_app' ELSE coalesce(p.mode,c.default_mode) END AS mode
     FROM public.field_notification_categories c LEFT JOIN public.field_notification_preferences p
     ON p.category=c.category AND p.recipient_sub=${u.sub} ORDER BY c.category`,
   sql`SELECT quiet_start,quiet_end FROM public.field_notification_settings WHERE recipient_sub=${u.sub}`
  ]);
  return reply({categories,quiet_hours:settings[0]??{quiet_start:1260,quiet_end:420},timezone:'Asia/Ho_Chi_Minh'});
 }
 if(path==='/api/v1/notifications/preferences'&&req.method==='PATCH'){
  let doc:Record<string,unknown>;try{doc=await body(req);}catch{return fail('Thiết lập không hợp lệ');}
  if(typeof doc.category!=='string'||!validMode(doc.mode))return fail('Thiết lập không hợp lệ');
  const rows=await sql`INSERT INTO public.field_notification_preferences(recipient_sub,category,mode)
   SELECT ${u.sub},category,CASE WHEN mandatory AND ${doc.mode}='off' THEN 'in_app' ELSE ${doc.mode} END
   FROM public.field_notification_categories WHERE category=${doc.category}
   ON CONFLICT(recipient_sub,category) DO UPDATE SET mode=excluded.mode RETURNING category,mode`;
  if(!rows.length)return fail('Nhóm thông báo không tồn tại',404);
  return reply({item:rows[0]});
 }
 if(path==='/api/v1/notifications/quiet-hours'&&req.method==='PATCH'){
  let doc:Record<string,unknown>;try{doc=await body(req);}catch{return fail('Thiết lập không hợp lệ');}
  if(!validMinute(doc.quiet_start)||!validMinute(doc.quiet_end))return fail('Giờ yên lặng không hợp lệ');
  const rows=await sql`INSERT INTO public.field_notification_settings(recipient_sub,quiet_start,quiet_end)
   VALUES (${u.sub},${doc.quiet_start},${doc.quiet_end}) ON CONFLICT(recipient_sub) DO UPDATE
   SET quiet_start=excluded.quiet_start,quiet_end=excluded.quiet_end RETURNING quiet_start,quiet_end`;
  return reply({quiet_hours:rows[0],timezone:'Asia/Ho_Chi_Minh'});
 }
 if(path==='/api/v1/notifications'&&req.method==='GET'){
  const limit=pageSize(url.searchParams.get('limit')),before=url.searchParams.get('before');
  if(limit===null||(before!==null&&!validCursor(before)))return fail('Phân trang không hợp lệ');
  const [items,count]=await Promise.all([
   sql`SELECT id::text AS id,title,body,created_at,read_at,category,group_count,updated_at FROM field_notifications
      WHERE recipient_sub=${u.sub} AND (scope_revision IS NULL OR scope_revision=${String(u.staff.scope_revision)}::bigint)
      AND (${before}::bigint IS NULL OR id<${before}::bigint) ORDER BY id DESC LIMIT ${limit+1}`,
   sql`SELECT count(*)::int AS unread FROM field_notifications WHERE recipient_sub=${u.sub} AND read_at IS NULL
      AND (scope_revision IS NULL OR scope_revision=${String(u.staff.scope_revision)}::bigint)`
  ]);
  const page=items.slice(0,limit);
  return reply({items:page,unread_count:count[0]?.unread??0,next_cursor:items.length>limit?page[page.length-1].id:null});
 }
 if(path==='/api/v1/notifications/read-all'&&req.method==='POST'){
  const rows=await sql`WITH changed AS (UPDATE field_notifications SET read_at=now()
    WHERE recipient_sub=${u.sub} AND read_at IS NULL
    AND (scope_revision IS NULL OR scope_revision=${String(u.staff.scope_revision)}::bigint) RETURNING id)
    SELECT count(*)::int AS updated FROM changed`;
  return reply({updated:rows[0]?.updated??0});
 }
 const read=/^\/api\/v1\/notifications\/([0-9]{1,19})\/read$/.exec(path);
 if(read&&req.method==='POST'){
  if(!validCursor(read[1]))return fail('Thông báo không tồn tại',404);
  const items=await sql`UPDATE field_notifications SET read_at=coalesce(read_at,now())
    WHERE id=${read[1]}::bigint AND recipient_sub=${u.sub}
    AND (scope_revision IS NULL OR scope_revision=${String(u.staff.scope_revision)}::bigint)
    RETURNING id::text AS id,read_at`;
  if(!items.length)return fail('Thông báo không tồn tại',404);
  return reply({item:items[0]});
 }
 if(path==='/api/v1/notifications/android/subscription'&&req.method==='POST'){
  if(!fcmConfigured(env))return fail('Máy chủ chưa cấu hình FCM',503);
  let doc:Record<string,unknown>;try{doc=await body(req);}catch{return fail('Đăng ký không hợp lệ');}
  if(!validFcmToken(doc.token)||!validBinding(doc.binding))return fail('Thiết bị Android không hợp lệ');
  await registerFcm(env,u.sub,doc.token,doc.binding);
  return reply({ok:true});
 }
 if(path==='/api/v1/notifications/android/unsubscribe'&&req.method==='POST'){
  let doc:Record<string,unknown>;try{doc=await body(req);}catch{return fail('Đăng ký không hợp lệ');}
  if(!validBinding(doc.binding))return fail('Thiết bị Android không hợp lệ');
  await unregisterFcm(env,u.sub,doc.binding);
  return reply({ok:true});
 }
 if(path==='/api/v1/notifications/subscription'&&req.method==='POST'){
  if(!env.VAPID_PUBLIC_KEY||!env.VAPID_PRIVATE_JWK)return fail('Chưa bật Push',503);
  let doc:Record<string,unknown>;
  try{doc=await body(req);}catch{return fail('Dữ liệu đăng ký không hợp lệ');}
  if(!validSubscription(doc))return fail('Thiết bị Push không hợp lệ');
  // A browser subscription is an opaque capability; one endpoint belongs to one account at a time.
  await sql`INSERT INTO field_push_subscriptions(endpoint,recipient_sub,p256dh,auth,updated_at)
   VALUES (${doc.endpoint},${u.sub},${doc.keys.p256dh},${doc.keys.auth},now())
   ON CONFLICT(endpoint) DO UPDATE SET recipient_sub=excluded.recipient_sub,
    p256dh=excluded.p256dh,auth=excluded.auth,updated_at=now()`;
  return reply({ok:true});
 }
 if(path==='/api/v1/notifications/unsubscribe'&&req.method==='POST'){
  let doc:Record<string,unknown>;
  try{doc=await body(req);}catch{return fail('Đăng ký không hợp lệ');}
  if(!validEndpoint(doc.endpoint))return fail('Endpoint không hợp lệ');
  await sql`DELETE FROM field_push_subscriptions WHERE endpoint=${doc.endpoint} AND recipient_sub=${u.sub}`;
  return reply({ok:true});
 }
 if(path==='/api/v1/notifications/test'&&req.method==='POST'){
  // Atomic per-account gate: concurrent requests cannot each claim a slot.
  const gate=await sql`INSERT INTO public.field_notification_test_gate(recipient_sub,next_at)
   SELECT s.user_sub,now()+interval '60 seconds' FROM public.staff_members s
   WHERE s.user_sub=${u.sub} AND s.active AND public.sales_identity_exists(s.user_sub)
    AND NOT EXISTS(SELECT 1 FROM public.field_notifications WHERE recipient_sub=${u.sub}
      AND event_key LIKE 'test:%' AND created_at>now()-interval '60 seconds')
   ON CONFLICT(recipient_sub) DO UPDATE SET next_at=excluded.next_at
    WHERE field_notification_test_gate.next_at<=now() RETURNING recipient_sub`;
  if(!gate.length)return fail('Chỉ gửi thử mỗi 60 giây',429);
  try{const android=await publishWithReport(env,u.sub,'test:'+crypto.randomUUID(),
    'Thử thông báo Field Work','Thông báo đã đến hộp thư của bạn.');
    return reply({ok:true,android},201);}
  catch{return fail('Không gửi được thông báo thử',503);}
 }
 return fail('Endpoint không tồn tại',404);
}
