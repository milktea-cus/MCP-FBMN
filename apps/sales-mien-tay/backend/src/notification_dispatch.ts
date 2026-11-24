import {neon} from '@neondatabase/serverless';
import {sendWebPush} from './notifications';
import {sendFcmDevice} from './fcm';
import {probeFcmOAuthOnce,probeFcmProviderOnce} from './notification_probe';
import {transientPushError,deviceDigest} from './notification_policy';

type Env={DATABASE_URL:string;FCM_SERVICE_ACCOUNT_JSON?:string;VAPID_PUBLIC_KEY?:string;
 VAPID_PRIVATE_JWK?:string;VAPID_SUBJECT?:string};
function cleanCode(v:string):string {
 return /^[A-Za-z0-9_]{1,80}$/.test(v)?v:'provider_error';
}
export async function dispatchNotifications(env:Env):Promise<{claimed:number;sent:number;failed:number}> {
 const sql=neon(env.DATABASE_URL);
 // FCM diagnostic must never prevent actual queued delivery.
 await probeFcmOAuthOnce(env).catch(()=>undefined);
 await probeFcmProviderOnce(env).catch(()=>undefined);
 const lease=crypto.randomUUID();
 // A competing cron invocation can't claim the same row until lease expiry.
 const claimed=await sql`WITH due AS (
  SELECT event_id,recipient_sub FROM public.field_notification_outbox
  WHERE mode<>'digest' AND ((state='pending') OR (state='processing' AND lease_until<now()))
   AND available_at<=now() AND expires_at>now()
  ORDER BY available_at,event_id LIMIT 20 FOR UPDATE SKIP LOCKED)
 UPDATE public.field_notification_outbox b SET state='processing',
  lease_until=now()+interval '120 seconds',lease_id=${lease}::uuid
 FROM due WHERE b.event_id=due.event_id AND b.recipient_sub=due.recipient_sub
 RETURNING b.event_id,b.recipient_sub,b.notification_id,b.scope_revision,b.mode`;
 let sent=0,failed=0;
 for(const task of claimed){
  try{
   // A permission batch can advance scope_revision while this lease is open.
   const [scope]=await sql`SELECT s.scope_revision,s.active,public.sales_identity_exists(s.user_sub) AS valid,
     b.scope_revision AS queued_revision,b.mode AS current_mode,
     b.available_at<=now() AS due,b.expires_at>now() AS unexpired
     FROM public.staff_members s JOIN public.field_notification_outbox b
      ON b.recipient_sub=s.user_sub AND b.event_id=${task.event_id}
      AND b.lease_id=${lease}::uuid WHERE s.user_sub=${task.recipient_sub}`;
   if(!scope)continue;
   if(!scope.active||!scope.valid||String(scope.scope_revision)!==String(scope.queued_revision)||!scope.unexpired){
    await sql`UPDATE public.field_notification_outbox SET state='cancelled',lease_id=NULL,lease_until=NULL
      WHERE event_id=${task.event_id} AND recipient_sub=${task.recipient_sub} AND lease_id=${lease}::uuid`;
    continue;
   }
   if(!scope.due){
    await sql`UPDATE public.field_notification_outbox SET state='pending',lease_id=NULL,lease_until=NULL
      WHERE event_id=${task.event_id} AND recipient_sub=${task.recipient_sub} AND lease_id=${lease}::uuid`;
    continue;
   }
   if(scope.current_mode==='in_app'){
    await sql`UPDATE public.field_notification_outbox SET state='done',lease_id=NULL,lease_until=NULL
     WHERE event_id=${task.event_id} AND recipient_sub=${task.recipient_sub} AND lease_id=${lease}::uuid`;
    continue;
   }
   // N3 consumes digest rows transactionally into one daily summary.
   const prev=await sql`SELECT budget_reserved FROM public.field_notification_outbox
    WHERE event_id=${task.event_id} AND recipient_sub=${task.recipient_sub} AND lease_id=${lease}::uuid`;
   if(!prev[0]?.budget_reserved){
    const important=await sql`SELECT e.category FROM public.field_notification_events e WHERE e.id=${task.event_id}`;
    const kind=['security','assignment'].includes(String(important[0]?.category))?'important':'normal';
    const day=new Date(Date.now()+7*3600000).toISOString().slice(0,10);
    const reserved=await sql`INSERT INTO public.field_notification_daily_budget(recipient_sub,local_day,kind,used)
      VALUES(${task.recipient_sub},${day}::date,${kind},1)
      ON CONFLICT(recipient_sub,local_day,kind) DO UPDATE SET used=public.field_notification_daily_budget.used+1
      WHERE public.field_notification_daily_budget.used<5 RETURNING used`;
    if(!reserved.length){
     await sql`UPDATE public.field_notification_outbox SET state='done',lease_id=NULL,lease_until=NULL
      WHERE event_id=${task.event_id} AND recipient_sub=${task.recipient_sub} AND lease_id=${lease}::uuid`;
     continue;
    }
    await sql`UPDATE public.field_notification_outbox SET budget_reserved=true
      WHERE event_id=${task.event_id} AND recipient_sub=${task.recipient_sub} AND lease_id=${lease}::uuid`;
   }
   const devices=await sql`SELECT 'web'::text AS channel,endpoint AS address,NULL::text AS binding
    FROM public.field_push_subscriptions WHERE recipient_sub=${task.recipient_sub}
    ORDER BY updated_at DESC LIMIT 5`;
   const android=await sql`SELECT 'android'::text AS channel,token AS address,binding_id::text AS binding
    FROM public.field_android_push_devices WHERE recipient_sub=${task.recipient_sub}
    ORDER BY updated_at DESC LIMIT 5`;
   for(const dev of [...devices,...android]){
    const digest=await deviceDigest(String(dev.address));
    await sql`INSERT INTO public.field_notification_delivery(notification_id,channel,device_key)
     VALUES(${task.notification_id},${dev.channel},${digest}) ON CONFLICT DO NOTHING`;
   }
   await sql`UPDATE public.field_notification_outbox SET state='done',lease_id=NULL,lease_until=NULL
    WHERE event_id=${task.event_id} AND recipient_sub=${task.recipient_sub} AND lease_id=${lease}::uuid`;
  }catch{
   failed++;
   await sql`UPDATE public.field_notification_outbox SET state='pending',lease_until=NULL,lease_id=NULL,
     available_at=now()+interval '5 minutes'
     WHERE event_id=${task.event_id} AND recipient_sub=${task.recipient_sub} AND lease_id=${lease}::uuid`;
  }
 }
 const due=await sql`SELECT d.notification_id,d.channel,d.device_key,d.attempts,n.recipient_sub
  FROM public.field_notification_delivery d
  JOIN public.field_notifications n ON n.id=d.notification_id
  JOIN public.staff_members s ON s.user_sub=n.recipient_sub
  WHERE ((d.state='pending' AND d.next_at<=now()) OR (d.state='processing' AND d.lease_until<now()))
   AND d.attempts<5 AND s.active AND public.sales_identity_exists(s.user_sub)
   AND (n.scope_revision IS NULL OR n.scope_revision=s.scope_revision)
  ORDER BY d.next_at,d.notification_id LIMIT 25`;
 for(const row of due){
  const attemptLease=crypto.randomUUID();
  const [lock]=await sql`UPDATE public.field_notification_delivery SET state='processing',
   lease_id=${attemptLease}::uuid,lease_until=now()+interval '90 seconds',attempts=attempts+1
   WHERE notification_id=${row.notification_id} AND channel=${row.channel} AND device_key=${row.device_key}
   AND attempts<5 AND ((state='pending' AND next_at<=now()) OR (state='processing' AND lease_until<now()))
   RETURNING attempts`;
  if(!lock)continue;
  let code='invalid_device',ok=false;
  try{
   // Check revocation once more at the last boundary before provider delivery.
   const [fresh]=await sql`SELECT s.active,public.sales_identity_exists(s.user_sub) AS identity_valid,
    (n.scope_revision IS NULL OR n.scope_revision=s.scope_revision) AS valid_scope
    FROM public.staff_members s JOIN public.field_notifications n ON n.recipient_sub=s.user_sub
    WHERE n.id=${row.notification_id} AND s.user_sub=${row.recipient_sub}`;
   if(!fresh?.active||!fresh?.identity_valid||!fresh?.valid_scope){code='revoked';}
   else {
   const devices=row.channel==='web'?
    await sql`SELECT endpoint AS address,NULL::text AS binding FROM public.field_push_subscriptions
     WHERE recipient_sub=${row.recipient_sub} ORDER BY updated_at DESC LIMIT 5`:
    await sql`SELECT token AS address,binding_id::text AS binding FROM public.field_android_push_devices
     WHERE recipient_sub=${row.recipient_sub} ORDER BY updated_at DESC LIMIT 5`;
   let found:null|{address:string;binding:string|null}=null;
   for(const d of devices){
    if(await deviceDigest(String(d.address))===row.device_key){
     found={address:String(d.address),binding:d.binding?String(d.binding):null};break;
    }
   }
   if(found){
    if(row.channel==='android'){
     const result=await sendFcmDevice(env,found.address,found.binding??'');
     ok=result.accepted;code=result.code;
    }else{
     const status=await sendWebPush(env,found.address);
     ok=status>=200&&status<300;
     code=ok?'accepted':status>=300&&status<400?'web_redirect_blocked':'http_'+status;
    }
   }
   }
  }catch{code='network_error';}
  const transient=transientPushError(code);
  if(ok)sent++;else failed++;
  const state=ok?'accepted':transient&&Number(lock.attempts)<5?'pending':'dead';
  const backoff=Math.min(60,Math.pow(2,Number(lock.attempts)))+Math.floor(Math.random()*3);
  await sql`UPDATE public.field_notification_delivery
   SET state=${state},lease_id=NULL,lease_until=NULL,error_code=${ok?null:cleanCode(code)},
    next_at=now()+${backoff}*interval '1 minute'
   WHERE notification_id=${row.notification_id} AND channel=${row.channel}
    AND device_key=${row.device_key} AND lease_id=${attemptLease}::uuid`;
 }
 return {claimed:claimed.length,sent,failed};
}
