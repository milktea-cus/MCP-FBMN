import {neon} from '@neondatabase/serverless';

type MailEnv={DATABASE_URL:string;RESEND_API_KEY?:string};
type StaffActor={sub:string;staff:Record<string,unknown>};
const json=(value:unknown,status=200)=>new Response(JSON.stringify(value),{
 status,headers:{'Content-Type':'application/json; charset=utf-8',
   'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'}});
const fail=(message:string,status=400)=>json({error:message},status);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const email=/^[^\s@<>\r\n]{1,64}@[a-z0-9.-]+[.][a-z]{2,}$/i;
const mailbox=/^[a-z0-9._+-]+@fbmn[.]vn$/;
const allowedFolders=new Set(['inbox','sent','archive']);
type ResendResult={status:number;data:Record<string,unknown>|null};
async function provider(env:MailEnv,path:string,method:'GET'|'POST'='GET',body?:unknown,idempotency?:string):Promise<ResendResult>{
 const key=env.RESEND_API_KEY;
 if(!key||!/^re_[a-z0-9_-]{16,}$/i.test(key))return {status:503,data:null};
 if(!/^\/inboxes\/[a-z0-9._+-]+@fbmn[.]vn(?:\/threads(?:\/[0-9a-f-]{36}(?:\/emails\/[0-9a-f-]{36})?)?|\/emails)?(?:\?[a-z0-9=&-]+)?$/i.test(path))
  return {status:400,data:null};
 try{
  const resp=await fetch('https://api.resend.com'+path,{
   method,redirect:'manual',
   headers:{Authorization:'Bearer '+key,Accept:'application/json',
    ...(body===undefined?{}:{'Content-Type':'application/json'}),
    ...(idempotency?{'Idempotency-Key':idempotency}:{})},
   body:body===undefined?undefined:JSON.stringify(body),
   signal:AbortSignal.timeout(method==='POST'?25000:12000)
  });
  if(!resp.ok||!resp.headers.get('content-type')?.includes('application/json'))
   return {status:resp.status===429?429:503,data:null};
  const text=await resp.text();
  if(text.length>450000)return {status:503,data:null};
  const data=JSON.parse(text);
  return data&&typeof data==='object'&&!Array.isArray(data)?{status:200,data}: {status:503,data:null};
 }catch{return {status:503,data:null};}
}
function view(data:Record<string,unknown>){
 // Do not forward untrusted HTML, raw provider headers or signed attachment URLs.
 return {id:data.id,subject:data.subject,from:data.from,to:data.to,
  direction:data.direction,read:data.read,received_at:data.received_at,
  folder:data.folder,unread:data.unread,has_attachment:data.has_attachment,
  email_count:data.email_count,created_at:data.created_at,
  text:typeof data.text==='string'?data.text.slice(0,120000):null};
}
export async function mailRoutes(req:Request,env:MailEnv,actor:StaffActor,url:URL):Promise<Response|null>{
 if(!url.pathname.startsWith('/api/v1/mail'))return null;
 if(!actor.staff.active)return fail('Tài khoản đã khóa',403);
 const db=neon(env.DATABASE_URL);
 const grant=await db`SELECT mb.mailbox FROM public.staff_mailboxes mb
  JOIN public.staff_members s ON s.user_sub=mb.user_sub
  WHERE mb.user_sub=${actor.sub} AND s.active LIMIT 1`;
 if(!grant.length)return fail('Tài khoản chưa được gán hộp thư',403);
 const assigned=String(grant[0].mailbox);
 if(!mailbox.test(assigned))return fail('Hộp thư không hợp lệ',403);
 if(url.pathname==='/api/v1/mail/me'&&req.method==='GET')
  return json({mailbox:assigned,enabled:Boolean(env.RESEND_API_KEY)});
 if(!env.RESEND_API_KEY)return fail('Chưa cấu hình cổng email trong Worker',503);
 // Inbox resolution and all Resend calls happen server-side using a fixed
 // address derived only from the signed-in identity, never a client inbox ID.
 // Resend accepts addresses as inbox identifiers.
 const box=assigned;
 if(url.pathname==='/api/v1/mail/threads'&&req.method==='GET'){
  const folder=url.searchParams.get('folder')??'inbox';
  const after=url.searchParams.get('after');
  if(!allowedFolders.has(folder)||url.searchParams.has('inboxId')||
    (after!==null&&!uuid.test(after)))return fail('Bộ lọc email không hợp lệ');
  const q=new URLSearchParams({folders:folder,limit:'30'});
  if(after)q.set('after',after);
  const result=await provider(env,`/inboxes/${box}/threads?${q}`);
  if(!result.data)return fail('Cổng email chưa sẵn sàng',result.status);
  const items=result.data.data;
  if(!Array.isArray(items))return fail('Phản hồi hộp thư không hợp lệ',503);
  return json({mailbox:assigned,items:items.map(v=>view(v as Record<string,unknown>)),
    has_more:result.data.has_more===true});
 }
 const thread=/^\/api\/v1\/mail\/threads\/([0-9a-f-]{36})$/i.exec(url.pathname);
 if(thread&&req.method==='GET'){
  if(!uuid.test(thread[1]))return fail('Mã thư không hợp lệ');
  const result=await provider(env,`/inboxes/${box}/threads/${thread[1]}`);
  if(!result.data)return fail('Không mở được hội thoại',result.status);
  const raw=result.data;
  const emails=Array.isArray(raw.emails)?raw.emails:[];
  return json({thread:view(raw),emails:emails.map(v=>view(v as Record<string,unknown>))});
 }
 const letter=/^\/api\/v1\/mail\/threads\/([0-9a-f-]{36})\/emails\/([0-9a-f-]{36})$/i.exec(url.pathname);
 if(letter&&req.method==='GET'){
  if(!uuid.test(letter[1])||!uuid.test(letter[2]))return fail('Mã thư không hợp lệ');
  const result=await provider(env,`/inboxes/${box}/threads/${letter[1]}/emails/${letter[2]}`);
  if(!result.data)return fail('Không mở được email',result.status);
  return json({item:view(result.data)});
 }
 if(url.pathname==='/api/v1/mail/send'&&req.method==='POST'){
  if(!req.headers.get('content-type')?.startsWith('application/json'))return fail('Chỉ hỗ trợ JSON',415);
  let payload:Record<string,unknown>;
  try{
   const raw=await req.text();
   if(raw.length>60000)throw Error('limit');
   payload=JSON.parse(raw);
   if(!payload||typeof payload!=='object'||Array.isArray(payload))throw Error('shape');
  }catch{return fail('Nội dung email không hợp lệ');}
  if(Object.keys(payload).some(k=>!['to','subject','text','request_id'].includes(k))||
   typeof payload.to!=='string'||!email.test(payload.to)||
   typeof payload.subject!=='string'||!payload.subject.trim()||
   payload.subject.length>200||/[\r\n]/.test(payload.subject)||
   typeof payload.text!=='string'||!payload.text.trim()||payload.text.length>12000||
   typeof payload.request_id!=='string'||!uuid.test(payload.request_id))
    return fail('Nội dung hoặc người nhận không hợp lệ');
  // Resend inbox send endpoint retains sent history in the same assigned inbox.
  const result=await provider(env,`/inboxes/${box}/emails`,'POST',{
   to:[payload.to.trim().toLowerCase()],subject:payload.subject.trim(),text:payload.text.trim()
  },'field-mail/'+payload.request_id);
  if(!result.data)return fail('Không gửi được email',result.status);
  return json({id:result.data.id,status:'queued'},201);
 }
 return fail('Không hỗ trợ thao tác email này',405);
}
