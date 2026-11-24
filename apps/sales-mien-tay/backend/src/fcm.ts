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
  return {email:x.client_email as string,key:(x.private_key as string).replace(/\\n/g,'\n').trim(),kid:typeof x.private_key_id==='string'&&/^[a-f0-9]{40}$/i.test(x.private_key_id)?x.private_key_id:undefined};
 }catch{return null;}
}
export const fcmConfigured=(env:FcmEnv)=>credentials(env)!==null;
class OAuthFailure extends Error {
 readonly code:string;
 constructor(code:string){super(code);this.code=code;}
}
const b64url=(bytes:Uint8Array)=>btoa(String.fromCharCode(...bytes)).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
const encode=(value:unknown)=>b64url(new TextEncoder().encode(JSON.stringify(value)));
export function oauthErrorCode(status:number,doc:unknown):string{
 const value=doc&&typeof doc==='object'?doc as {error?:unknown;error_description?:unknown}:{};
 const desc=typeof value.error_description==='string'?value.error_description.toLowerCase():'';
 if(value.error==='invalid_grant'){
  if(desc.includes('signature'))return 'oauth_invalid_signature';
  if(desc.includes('disabled')||desc.includes('not found')||desc.includes('deleted'))return 'oauth_account_invalid';
  if(desc.includes('iat')||desc.includes('exp')||desc.includes('timeframe'))return 'oauth_clock';
  return 'oauth_invalid_grant';
 }
 if(value.error==='invalid_client'||value.error==='unauthorized_client'||value.error==='invalid_scope')return 'oauth_'+value.error;
 return 'oauth_http_'+status;
}
export async function createFcmAssertion(env:FcmEnv,now=Math.floor(Date.now()/1000)):Promise<string>{
 const c=credentials(env);if(!c)throw new OAuthFailure('oauth_config_invalid');
 let key:CryptoKey;
 try{
  const encoded=c.key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,'');
  const der=Uint8Array.from(atob(encoded),v=>v.charCodeAt(0));
  key=await crypto.subtle.importKey('pkcs8',der,{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
 }catch{throw new OAuthFailure('oauth_key_invalid');}
 const header=encode({alg:'RS256',typ:'JWT',...(c.kid?{kid:c.kid}:{})});
 const claims=encode({iss:c.email,scope,aud:oauth,iat:now-30,exp:now+300});
 const message=header+'.'+claims;
 try{
  const signature=await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,new TextEncoder().encode(message));
  return message+'.'+b64url(new Uint8Array(signature));
 }catch{throw new OAuthFailure('oauth_sign_failed');}
}
export async function accessToken(env:FcmEnv,request:typeof fetch=fetch){
 const assertion=await createFcmAssertion(env);
 let res:Response;
 try{
  res=await request(oauth,{method:'POST',redirect:'error',
   headers:{'Content-Type':'application/x-www-form-urlencoded'},
   body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion}).toString(),
   signal:AbortSignal.timeout(12000)});
 }catch{throw new OAuthFailure('oauth_network_failed');}
 const result=await res.json().catch(()=>null) as {access_token?:unknown}|null;
 if(!res.ok)throw new OAuthFailure(oauthErrorCode(res.status,result));
 if(typeof result?.access_token!=='string'||!result.access_token)throw new OAuthFailure('oauth_response_invalid');
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
export type FcmReport={accepted:number;failed:number;reason?:string};
export async function sendFcm(env:FcmEnv,sub:string):Promise<FcmReport>{
 if(!fcmConfigured(env))return {accepted:0,failed:0,reason:'not_configured'};
 const sql=neon(env.DATABASE_URL);
 const devices=await sql`SELECT d.token,d.binding_id::text AS binding_id
 FROM public.field_android_push_devices d JOIN public.staff_members s ON s.user_sub=d.recipient_sub
 WHERE d.recipient_sub=${sub} AND s.active AND public.sales_identity_exists(s.user_sub)
 ORDER BY d.updated_at DESC LIMIT 5`;
 if(!devices.length)return {accepted:0,failed:0,reason:'no_device'};
 let access:string;try{access=await accessToken(env);}catch(e){return {accepted:0,failed:devices.length,reason:e instanceof OAuthFailure?e.code:'oauth_failed'};}
 const delivered=await Promise.all(devices.map(async d=>{
  if(!validFcmToken(d.token)||!validBinding(d.binding_id))return 'invalid_device';
  try{
   const r=await fetch('https://fcm.googleapis.com/v1/projects/'+project+'/messages:send',{
    method:'POST',redirect:'error',headers:{Authorization:'Bearer '+access,'Content-Type':'application/json'},
    body:JSON.stringify({message:{token:d.token,data:{kind:'field_notification',binding:d.binding_id},
     android:{priority:'HIGH',ttl:'3600s'}}}),signal:AbortSignal.timeout(8000)});
   if(r.ok)return 'accepted';
   const error=await r.json().catch(()=>null) as {error?:{details?:Array<{errorCode?:string}>}}|null;
   if(error?.error?.details?.some(x=>x.errorCode==='UNREGISTERED')){
    await sql`DELETE FROM public.field_android_push_devices WHERE token=${d.token}
    AND recipient_sub=${sub} AND binding_id=${d.binding_id}::uuid`;
   }
   const code=error?.error?.details?.find(x=>typeof x.errorCode==='string')?.errorCode;
   if(code==='UNREGISTERED'||code==='SENDER_ID_MISMATCH'||code==='INVALID_ARGUMENT'||code==='QUOTA_EXCEEDED')return code;
   return 'http_'+r.status;
  }catch{return 'network_error';}
 }));
 const accepted=delivered.filter(x=>x==='accepted').length;
 return {accepted,failed:devices.length-accepted,...(accepted===devices.length?{}:{reason:delivered.find(x=>x!=='accepted')})};
}
