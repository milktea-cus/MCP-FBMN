import {accessToken,fcmConfigured} from './fcm';
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
