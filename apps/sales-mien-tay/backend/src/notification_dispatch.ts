import {neon} from '@neondatabase/serverless';
import {sendWebPush} from './notifications';
import {sendFcmDevice} from './fcm';
import {probeFcmOAuthOnce,probeFcmProviderOnce} from './notification_probe';
import {transientPushError,deviceDigest,deliveryMode,quietUntil,retiredDevice} from './notification_policy';

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
 // Cancel expired/revoked work, preserving history.
 await sql`UPDATE public.field_notification_outbox b SET state='cancelled',lease_id=NULL,lease_until=NULL
   WHERE (b.state='pending' OR (b.state='processing' AND b.lease_until<now()))
   AND (b.expires_at<=now() OR NOT EXISTS(SELECT 1 FROM public.staff_members s
    WHERE s.user_sub=b.recipient_sub AND s.active AND s.scope_revision=b.scope_revision
      AND public.sales_identity_exists(s.user_sub)))`;
 await sql`UPDATE public.field_notification_delivery d SET state='cancelled',lease_id=NULL,lease_until=NULL,error_code='revoked_or_expired'
  WHERE (d.state='pending' OR (d.state='processing' AND d.lease_until<now()))
   AND NOT EXISTS(SELECT 1 FROM public.field_notifications n JOIN public.staff_members s ON s.user_sub=n.recipient_sub
    JOIN public.field_notification_outbox b ON b.notification_id=n.id AND b.recipient_sub=n.recipient_sub
    WHERE n.id=d.notification_id AND s.active AND public.sales_identity_exists(s.user_sub)
     AND b.scope_revision=s.scope_revision AND b.expires_at>now()
     AND (n.scope_revision IS NULL OR n.scope_revision=s.scope_revision)
     AND b.state IN ('pending','processing','done'))`;
 await sql`UPDATE public.field_notification_delivery SET state='dead',lease_id=NULL,lease_until=NULL,error_code='retry_exhausted'
  WHERE attempts>=5 AND (state='pending' OR (state='processing' AND lease_until<now()))`;
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
     b.scope_revision AS queued_revision,e.category,
     coalesce(p.mode,c.default_mode) AS preference,c.mandatory,c.producer_enabled,
     coalesce(q.quiet_start,1260) AS quiet_start,coalesce(q.quiet_end,420) AS quiet_end,
     b.available_at<=now() AS due,b.expires_at>now() AS unexpired
     FROM public.staff_members s JOIN public.field_notification_outbox b
      ON b.recipient_sub=s.user_sub AND b.event_id=${task.event_id}
      AND b.lease_id=${lease}::uuid
     JOIN public.field_notification_events e ON e.id=b.event_id
     JOIN public.field_notification_categories c ON c.category=e.category
     LEFT JOIN public.field_notification_preferences p ON p.recipient_sub=s.user_sub AND p.category=e.category
     LEFT JOIN public.field_notification_settings q ON q.recipient_sub=s.user_sub
     WHERE s.user_sub=${task.recipient_sub}`;
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
   const mode=deliveryMode(scope.preference,scope.mandatory,String(scope.category));
   if(!scope.producer_enabled||mode==='off'||mode==='in_app'){
    await sql`UPDATE public.field_notification_outbox SET state='done',lease_id=NULL,lease_until=NULL
     WHERE event_id=${task.event_id} AND recipient_sub=${task.recipient_sub} AND lease_id=${lease}::uuid`;
    continue;
   }
   if(mode==='digest'){
    const now=new Date(),local=new Date(now.getTime()+7*3600000);
    let slot=new Date(Date.UTC(local.getUTCFullYear(),local.getUTCMonth(),local.getUTCDate(),11));
    if(slot<=now)slot=new Date(slot.getTime()+86400000);
    const at=quietUntil(slot,Number(scope.quiet_start),Number(scope.quiet_end));
    await sql`UPDATE public.field_notification_outbox SET mode='digest',state='pending',lease_id=NULL,lease_until=NULL,
     available_at=${at.toISOString()}::timestamptz,expires_at=${new Date(at.getTime()+6*3600000).toISOString()}::timestamptz
     WHERE event_id=${task.event_id} AND recipient_sub=${task.recipient_sub} AND lease_id=${lease}::uuid`;
    continue;
   }
   const now=new Date(),at=quietUntil(now,Number(scope.quiet_start),Number(scope.quiet_end));
   if(at>now){
    await sql`UPDATE public.field_notification_outbox SET state=CASE WHEN expires_at>${at.toISOString()}::timestamptz THEN 'pending' ELSE 'cancelled' END,
     available_at=least(${at.toISOString()}::timestamptz,expires_at-interval '1 millisecond'),lease_id=NULL,lease_until=NULL
     WHERE event_id=${task.event_id} AND recipient_sub=${task.recipient_sub} AND lease_id=${lease}::uuid`;
    continue;
   }
   // N3 consumes digest rows transactionally into one daily summary.
   // One SQL statement reserves budget and records it against the live lease.
   const kind=['security','assignment'].includes(String(scope.category))?'important':'normal';
   const day=new Date(Date.now()+7*3600000).toISOString().slice(0,10);
   const reserved=await sql`WITH locked AS (
    SELECT budget_reserved FROM public.field_notification_outbox
     WHERE event_id=${task.event_id} AND recipient_sub=${task.recipient_sub}
      AND lease_id=${lease}::uuid AND lease_until>now() FOR UPDATE
   ), budget AS (
    INSERT INTO public.field_notification_daily_budget(recipient_sub,local_day,kind,used)
     SELECT ${task.recipient_sub},${day}::date,${kind},1 FROM locked WHERE NOT budget_reserved
    ON CONFLICT(recipient_sub,local_day,kind) DO UPDATE SET used=public.field_notification_daily_budget.used+1
     WHERE public.field_notification_daily_budget.used<5 RETURNING used
   ) UPDATE public.field_notification_outbox b SET budget_reserved=true
    WHERE b.event_id=${task.event_id} AND b.recipient_sub=${task.recipient_sub} AND b.lease_id=${lease}::uuid
    AND (EXISTS(SELECT 1 FROM locked WHERE budget_reserved) OR EXISTS(SELECT 1 FROM budget))
    RETURNING b.event_id`;
   if(!reserved.length){
    await sql`UPDATE public.field_notification_outbox SET state='done',lease_id=NULL,lease_until=NULL
     WHERE event_id=${task.event_id} AND recipient_sub=${task.recipient_sub} AND lease_id=${lease}::uuid AND lease_until>now()`;
    continue;
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
    (n.scope_revision IS NULL OR n.scope_revision=s.scope_revision) AS valid_scope,
    EXISTS (
      SELECT 1 FROM public.field_notification_outbox b
      WHERE b.notification_id=n.id AND b.recipient_sub=n.recipient_sub
        AND b.scope_revision=s.scope_revision AND b.expires_at>now()
        AND b.state IN ('pending','processing','done')
    ) AS within_expiry,n.category,n.read_at,c.producer_enabled,c.mandatory,
    coalesce(p.mode,c.default_mode) AS preference,
    coalesce(q.quiet_start,1260) AS quiet_start,coalesce(q.quiet_end,420) AS quiet_end
    FROM public.staff_members s JOIN public.field_notifications n ON n.recipient_sub=s.user_sub
    JOIN public.field_notification_categories c ON c.category=n.category
    LEFT JOIN public.field_notification_preferences p ON p.recipient_sub=s.user_sub AND p.category=n.category
    LEFT JOIN public.field_notification_settings q ON q.recipient_sub=s.user_sub
    WHERE n.id=${row.notification_id} AND s.user_sub=${row.recipient_sub}`;
   if(!fresh?.active||!fresh?.identity_valid||!fresh?.valid_scope){code='revoked';}
   else if(!fresh.within_expiry){code='expired';}
   else if(fresh.read_at||!fresh.producer_enabled||
    deliveryMode(fresh.preference,fresh.mandatory,String(fresh.category))!=='immediate'){code='suppressed';}
   else {
   const now=new Date(),at=quietUntil(now,Number(fresh.quiet_start),Number(fresh.quiet_end));
   if(at>now){
    await sql`UPDATE public.field_notification_delivery SET state='pending',lease_id=NULL,lease_until=NULL,
     attempts=greatest(0,attempts-1),next_at=${at.toISOString()}::timestamptz
     WHERE notification_id=${row.notification_id} AND channel=${row.channel} AND device_key=${row.device_key}
      AND lease_id=${attemptLease}::uuid`;
    continue;
   }
   const devices=row.channel==='web'?
    await sql`SELECT endpoint AS address,NULL::text AS binding,updated_at::text AS registered_at FROM public.field_push_subscriptions
     WHERE recipient_sub=${row.recipient_sub} ORDER BY updated_at DESC LIMIT 5`:
    await sql`SELECT token AS address,binding_id::text AS binding,updated_at::text AS registered_at FROM public.field_android_push_devices
     WHERE recipient_sub=${row.recipient_sub} ORDER BY updated_at DESC LIMIT 5`;
   let found:null|{address:string;binding:string|null;registeredAt:string}=null;
   for(const d of devices){
    if(await deviceDigest(String(d.address))===row.device_key){
     found={address:String(d.address),binding:d.binding?String(d.binding):null,registeredAt:String(d.registered_at)};break;
    }
   }
   if(found){
    if(row.channel==='android'){
     const result=await sendFcmDevice(env,found.address,found.binding??'',
      await deviceDigest('notification:'+String(row.notification_id)+':'+String(row.recipient_sub)));
     ok=result.accepted;code=result.code;
    }else{
     const status=await sendWebPush(env,found.address);
     ok=status>=200&&status<300;
     code=ok?'accepted':status>=300&&status<400?'web_redirect_blocked':'http_'+status;
    }
    if(retiredDevice(String(row.channel),code)){
     try{
      if(row.channel==='android')await sql`DELETE FROM public.field_android_push_devices
       WHERE recipient_sub=${row.recipient_sub} AND token=${found.address}
       AND binding_id=${found.binding}::uuid AND updated_at=${found.registeredAt}::timestamptz`;
      else await sql`DELETE FROM public.field_push_subscriptions
       WHERE recipient_sub=${row.recipient_sub} AND endpoint=${found.address}
       AND updated_at=${found.registeredAt}::timestamptz`;
     }catch{/* Terminal delivery even if cleanup fails. */}
    }
   }
   }
  }catch{code='network_error';}
  const transient=transientPushError(code);
  if(ok)sent++;else failed++;
  const state=ok?'accepted':code==='revoked'||code==='expired'||code==='suppressed'?'cancelled':
   transient&&Number(lock.attempts)<5?'pending':'dead';
  const backoff=Math.min(60,Math.pow(2,Number(lock.attempts)))+Math.floor(Math.random()*3);
  await sql`UPDATE public.field_notification_delivery
   SET state=${state},lease_id=NULL,lease_until=NULL,error_code=${ok?null:cleanCode(code)},
    next_at=now()+${backoff}*interval '1 minute'
   WHERE notification_id=${row.notification_id} AND channel=${row.channel}
    AND device_key=${row.device_key} AND lease_id=${attemptLease}::uuid`;
 }
 return {claimed:claimed.length,sent,failed};
}
