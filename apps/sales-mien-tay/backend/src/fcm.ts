import {importPKCS8, SignJWT} from 'jose';
import {neon} from '@neondatabase/serverless';

export type FcmEnv={DATABASE_URL:string;FCM_SERVICE_ACCOUNT_JSON?:string};
const project='mcp-sales-ee068';
const oauth='https://oauth2.googleapis.com/token';
const scope='https://www.googleapis.com/auth/firebase.messaging';
const tokenPattern=/^[A-Za-z0-9_:.\-]{32,2048}$/;
const bindingPattern=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
export const validFcmToken=(x:unknown):x is string=>typeof x==='string'&&tokenPattern.test(x)&&!/[\r\n]/.test(x);
export const validBinding=(x:unknown):x is string=>typeof x==='string'&&bindingPattern.test(x)&&!/[\r\n]/.test(x);
function credentials(env:FcmEnv){
 if(!env.FCM_SERVICE_ACCOUNT_JSON)return null;
 try{
  const x=JSON.parse(env.FCM_SERVICE_ACCOUNT_JSON);
  if(x.type!=='service_account'||x.project_id!==project||
   typeof x.client_email!=='string'||!x.client_email.endsWith('.gserviceaccount.com')||
   typeof x.private_key!=='string'||!x.private_key.startsWith('-----BEGIN PRIVATE KEY-----'))return null;
  return {email:x.client_email as string,key:x.private_key as string};
 }catch{return null;}
}
export const fcmConfigured=(env:FcmEnv)=>credentials(env)!==null;
async function accessToken(env:FcmEnv){
 const c=credentials(env);if(!c)throw Error('FCM unavailable');
 const key=await importPKCS8(c.key,'RS256');
 const assertion=await new SignJWT({scope}).setProtectedHeader({alg:'RS256',typ:'JWT'})
  .setIssuer(c.email).setAudience(oauth).setIssuedAt().setExpirationTime('5m').sign(key);
 const res=await fetch(oauth,{method:'POST',redirect:'error',
  headers:{'Content-Type':'application/x-www-form-urlencoded'},
  body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion}),
  signal:AbortSignal.timeout(8000)});
 if(!res.ok)throw Error('FCM authorization failed');
 const result=await res.json() as {access_token?:unknown};
 if(typeof result.access_token!=='string')throw Error('FCM authorization failed');
 return result.access_token;
}
export async function registerFcm(env:FcmEnv,sub:string,token:string,binding:string){
 const sql=neon(env.DATABASE_URL);
 // Binding is an installation enrollment nonce; re-registering replaces the
 // former account and rotated token. The native receiver also checks the nonce.
 await sql`INSERT INTO public.field_android_push_devices(binding_id,recipient_sub,token,updated_at)
 VALUES (${binding}::uuid,${sub},${token},now())
 ON CONFLICT(token) DO UPDATE SET recipient_sub=excluded.recipient_sub,
 binding_id=excluded.binding_id,updated_at=now()`;
 await sql`DELETE FROM public.field_android_push_devices
 WHERE recipient_sub=${sub} AND binding_id=${binding}::uuid AND token<>${token}`;
}
export async function unregisterFcm(env:FcmEnv,sub:string,binding:string){
 await neon(env.DATABASE_URL)`DELETE FROM public.field_android_push_devices
 WHERE recipient_sub=${sub} AND binding_id=${binding}::uuid`;
}
export async function sendFcm(env:FcmEnv,sub:string):Promise<{accepted:number;failed:number}>{
 if(!fcmConfigured(env))return {accepted:0,failed:0};
 const sql=neon(env.DATABASE_URL);
 const devices=await sql`SELECT d.token,d.binding_id::text AS binding_id
 FROM public.field_android_push_devices d JOIN public.staff_members s ON s.user_sub=d.recipient_sub
 WHERE d.recipient_sub=${sub} AND s.active AND public.sales_identity_exists(s.user_sub)
 ORDER BY d.updated_at DESC LIMIT 5`;
 if(!devices.length)return {accepted:0,failed:0};
 let access:string;try{access=await accessToken(env);}catch{return {accepted:0,failed:devices.length};}
 const delivered=await Promise.all(devices.map(async d=>{
  if(!validFcmToken(d.token)||!validBinding(d.binding_id))return false;
  try{
   const r=await fetch('https://fcm.googleapis.com/v1/projects/'+project+'/messages:send',{
    method:'POST',redirect:'error',headers:{Authorization:'Bearer '+access,'Content-Type':'application/json'},
    body:JSON.stringify({message:{token:d.token,data:{kind:'field_notification',binding:d.binding_id},
     android:{priority:'HIGH',ttl:'3600s'}}}),signal:AbortSignal.timeout(8000)});
   if(r.ok)return true;
   const error=await r.json().catch(()=>null) as {error?:{details?:Array<{errorCode?:string}>}}|null;
   if(error?.error?.details?.some(x=>x.errorCode==='UNREGISTERED')){
    await sql`DELETE FROM public.field_android_push_devices WHERE token=${d.token}
    AND recipient_sub=${sub} AND binding_id=${d.binding_id}::uuid`;
   }
  }catch{/* Do not expose credentials, tokens or Google response bodies. */}
  return false;
 }));
 const accepted=delivered.filter(Boolean).length;
 return {accepted,failed:devices.length-accepted};
}
