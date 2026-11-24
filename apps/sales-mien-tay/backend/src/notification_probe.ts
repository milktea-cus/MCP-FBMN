import {accessToken,fcmConfigured,validateFcmDevice} from './fcm';
import {transientPushError} from './notification_policy';
import {neon} from '@neondatabase/serverless';
type Env={DATABASE_URL:string;FCM_SERVICE_ACCOUNT_JSON?:string};
// Cron performs a bounded Google OAuth network probe without sending a push or persisting tokens.
export async function probeFcmOAuthOnce(env:Env):Promise<void>{
 const sql=neon(env.DATABASE_URL),key='n1_fcm_oauth_rc16';
 const rows=await sql`INSERT INTO public.field_notification_runtime_checks(check_key,status,reason)
   VALUES(${key},'pending',NULL)
   ON CONFLICT(check_key) DO UPDATE SET checked_at=now(),
     attempts=field_notification_runtime_checks.attempts+1
   WHERE field_notification_runtime_checks.status='pending'
     AND field_notification_runtime_checks.checked_at<now()-interval '15 minutes'
     AND field_notification_runtime_checks.attempts<3
   RETURNING attempts`;
 if(!rows.length)return;
 let status='ok',reason:null|string=null;
 if(!fcmConfigured(env)){status='failed';reason='not_configured';}
 else try{await accessToken(env);}catch(e){
  const msg=e instanceof Error?e.message:'server_error';
  reason=/^oauth_[a-z0-9_]{1,70}$/.test(msg)?msg:'server_error';
  const transient=reason==='oauth_network_failed'||/^oauth_http_(429|5[0-9]{2})$/.test(reason);
  status=transient&&Number(rows[0].attempts)<3?'pending':'failed';
 }
 await sql`UPDATE public.field_notification_runtime_checks
  SET status=${status},reason=${reason},checked_at=now() WHERE check_key=${key}`;
}

// Verify the real FCM messages:send endpoint with validate_only (never delivers).
// Only an active ADMIN device is used, and the raw FCM device token stays server-side.
export async function probeFcmProviderOnce(env:Env):Promise<void>{
 const sql=neon(env.DATABASE_URL),key='n1_fcm_provider_validation_rc16';
 const rows=await sql`INSERT INTO public.field_notification_runtime_checks(check_key,status,reason)
   VALUES(${key},'pending',NULL)
   ON CONFLICT(check_key) DO UPDATE SET checked_at=now(),
    attempts=field_notification_runtime_checks.attempts+1
   WHERE field_notification_runtime_checks.status='pending'
    AND field_notification_runtime_checks.checked_at<now()-interval '15 minutes'
    AND field_notification_runtime_checks.attempts<3
   RETURNING attempts`;
 if(!rows.length)return;
 let status='failed',reason='no_admin_device';
 if(fcmConfigured(env)){
  const devices=await sql`SELECT d.token,d.binding_id::text AS binding FROM public.field_android_push_devices d
    JOIN public.staff_members s ON s.user_sub=d.recipient_sub
    WHERE s.active AND s.role='admin' AND public.sales_identity_exists(s.user_sub)
    ORDER BY d.updated_at DESC LIMIT 1`;
  if(devices.length){
   const result=await validateFcmDevice(env,String(devices[0].token),String(devices[0].binding));
   status=result.ok?'ok':transientPushError(result.code)&&Number(rows[0].attempts)<3?'pending':'failed';
   reason=result.ok?'validated':result.code;
  }
 }else{reason='not_configured';}
 await sql`UPDATE public.field_notification_runtime_checks
  SET status=${status},reason=${reason},checked_at=now() WHERE check_key=${key}`;
}
