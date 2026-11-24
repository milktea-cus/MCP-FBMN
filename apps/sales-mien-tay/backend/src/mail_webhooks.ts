import {neon} from '@neondatabase/serverless';

type Env={DATABASE_URL:string;RESEND_API_KEY?:string;RESEND_INBOUND_WEBHOOK_SECRET?:string};
const ok=(status=200)=>new Response(JSON.stringify({ok:status===200}),{status,
 headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[1-8][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i;
const email=/^[a-z0-9._+-]+@fbmn[.]vn$/;

export async function verifyResendSignature(
 raw:string,headers:Headers,secret:string,now=Math.floor(Date.now()/1000),
):Promise<boolean>{
 const id=headers.get('svix-id'),timestamp=headers.get('svix-timestamp'),sig=headers.get('svix-signature');
 if(!id||!timestamp||!sig||id.length>180||!id.match(/^[A-Za-z0-9_-]+$/)||
   !/^[0-9]{10}$/.test(timestamp)||Math.abs(Number(timestamp)-now)>300||
   !/^whsec_[A-Za-z0-9+/_=-]+$/.test(secret))return false;
 let key:Uint8Array;
 try{key=Uint8Array.from(atob(secret.slice(6)),c=>c.charCodeAt(0));}catch{return false;}
 if(key.length<16)return false;
 const signed=id+'.'+timestamp+'.'+raw;
 const keyBuffer=new ArrayBuffer(key.length);
 new Uint8Array(keyBuffer).set(key);
 const cryptoKey=await crypto.subtle.importKey('raw',keyBuffer,{name:'HMAC',hash:'SHA-256'},false,['sign']);
 const digest=new Uint8Array(await crypto.subtle.sign('HMAC',cryptoKey,new TextEncoder().encode(signed)));
 for(const candidate of sig.split(/\s+/)){
  if(!candidate.startsWith('v1,'))continue;
  let received:Uint8Array;
  try{received=Uint8Array.from(atob(candidate.slice(3)),c=>c.charCodeAt(0));}
  catch{continue;}
  if(received.length!==digest.length)continue;
  let diff=0;
  for(let i=0;i<digest.length;i++)diff|=digest[i]^received[i];
  if(diff===0)return true;
 }
 return false;
}


// Resend Headless Webhook API provides authoritative event payloads. When a
// signing secret cannot be installed cross-account, treat each callback solely
// as a hint: look up the Svix message ID with the already-bound Resend API key
// and ignore all unverified data in the callback body.
const inboundWebhookId='6256051c-8bf0-4f74-ab41-711c17e35bba';

export async function verifyResendEventWithProvider(
 headers:Headers,apiKey:string,now=Math.floor(Date.now()/1000),
):Promise<Record<string,unknown>|null>{
 const id=headers.get('svix-id')??'';
 const stamp=headers.get('svix-timestamp')??'';
 if(!/^msg_[A-Za-z0-9]{12,110}$/.test(id)||!/^\d{10}$/.test(stamp)||
    Math.abs(Number(stamp)-now)>300)return null;
 const response=await fetch('https://api.resend.com/webhooks/'+inboundWebhookId+
  '/events/'+encodeURIComponent(id),{
  headers:{Authorization:'Bearer '+apiKey,Accept:'application/json'},
  redirect:'manual',signal:AbortSignal.timeout(8000)
 });
 if(response.status===404||response.status===403||response.status===401)return null;
 if(!response.ok)throw Error('Provider event verification unavailable');
 const body=await response.text();
 if(body.length>32000)throw Error('Provider event too large');
 const event=JSON.parse(body) as Record<string,unknown>;
 if(event.id!==id||event.type!=='inbox.email.received')return null;
 const created=Date.parse(String(event.created_at??''));
 if(!Number.isFinite(created)||Math.abs(Date.now()-created)>24*3600000)return null;
 const content=typeof event.payload==='string'?JSON.parse(event.payload):event.payload;
 if(content===null||typeof content!=='object'||Array.isArray(content))return null;
 const verified=content as Record<string,unknown>;
 if(verified.type!=='inbox.email.received')return null;
 return verified;
}

export async function resendInboundWebhook(req:Request,env:Env):Promise<Response>{
 if(req.method!=='POST')return ok(405);
 if(!env.RESEND_API_KEY)return ok(503);
 if(Number(req.headers.get('content-length')??0)>32000)return ok(413);
 let raw:string;
 try{raw=await req.text();if(raw.length>32000)return ok(413);}catch{return ok(400);}
 let payload:Record<string,unknown>;
 if(env.RESEND_INBOUND_WEBHOOK_SECRET){
  if(!await verifyResendSignature(raw,req.headers,env.RESEND_INBOUND_WEBHOOK_SECRET))
    return ok(401);
  try{const data=JSON.parse(raw);if(!data||typeof data!=='object'||Array.isArray(data))
    return ok(400);payload=data as Record<string,unknown>;}catch{return ok(400);}
 }else{
  // No signing key available: refuse the callback unless Resend verifies its
  // exact message ID and supplies the canonical payload over an authorized GET.
  // A forged body is never consumed, even when it contains a plausible ID.
  let verified:Record<string,unknown>|null;
  try{verified=await verifyResendEventWithProvider(req.headers,env.RESEND_API_KEY);}
  catch{return ok(503);}
  if(!verified)return ok(401);
  payload=verified;
 }
 if(payload.type!=='inbox.email.received')return ok();
 const data=payload.data as Record<string,unknown>|null;
 if(!data||typeof data!=='object'||!uuid.test(String(data.inbox_id??''))||
   !uuid.test(String(data.thread_id??''))||!uuid.test(String(data.email_id??'')))return ok(400);
 const arrived=Date.parse(String(payload.created_at??''));
 if(!Number.isFinite(arrived)||Math.abs(Date.now()-arrived)>24*3600000)return ok();
 // A signed event may still name a different inbox: resolve the ID against
 // Resend's trusted API, never use the event's free-form "to" or subject.
 let mailbox:string;
 try{
  const provider=await fetch('https://api.resend.com/inboxes/'+data.inbox_id,{
   headers:{Authorization:'Bearer '+env.RESEND_API_KEY,Accept:'application/json'},
   redirect:'manual',signal:AbortSignal.timeout(8000)});
  if(!provider.ok)return ok(provider.status>=500||provider.status===429?503:200);
  const resp=await provider.text();
  if(resp.length>8000)return ok(503);
  const info=JSON.parse(resp) as Record<string,unknown>;
  mailbox=String(info.email_address??'').toLowerCase();
  if(!email.test(mailbox))return ok();
 }catch{return ok(503);}
 try{
  const db=neon(env.DATABASE_URL);
  await db`SELECT public.sales_mail_received(${mailbox},${String(data.email_id)}::uuid,${String(data.thread_id)}::uuid,${new Date(arrived)})`;
  return ok();
 }catch{return ok(503);}
}
