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
const MAX_ATTACHMENTS=4;
const MAX_ATTACHMENT_BYTES=5*1024*1024;
const MAX_BODY_CHARS=9*1024*1024;
// Only familiar business document and image types may be submitted.
const mimeByExt:Record<string,string>={
 pdf:'application/pdf',png:'image/png',jpg:'image/jpeg',jpeg:'image/jpeg',
 webp:'image/webp',txt:'text/plain',csv:'text/csv',
 docx:'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
 xlsx:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
 pptx:'application/vnd.openxmlformats-officedocument.presentationml.presentation'
};
type AttachmentInput={filename:string;content:string;content_type:string};
export function validateAttachments(value:unknown):AttachmentInput[]|null{
 if(value===undefined||value===null)return [];
 if(!Array.isArray(value)||value.length>MAX_ATTACHMENTS)return null;
 let total=0;
 const files:AttachmentInput[]=[];
 for(const item of value){
  if(!item||typeof item!=='object'||Array.isArray(item))return null;
  const f=item as Record<string,unknown>;
  if(Object.keys(f).some(k=>!['filename','content'].includes(k))||
     typeof f.filename!=='string'||typeof f.content!=='string'||
     f.filename.length>120||!f.filename.trim()||
     /[\\/\r\n\0]/.test(f.filename)||f.filename.startsWith('.')||
     !/^[A-Za-z0-9+/]+={0,2}$/.test(f.content)||
     f.content.length%4!==0)return null;
  const ext=f.filename.toLowerCase().split('.').pop()??'';
  const contentType=mimeByExt[ext];
  if(!contentType)return null;
  const length=(f.content.length/4)*3-(f.content.endsWith('==')?2:f.content.endsWith('=')?1:0);
  if(length<1||length>MAX_ATTACHMENT_BYTES)return null;
  total+=length;
  if(total>MAX_ATTACHMENT_BYTES)return null;
  files.push({filename:f.filename,content:f.content,content_type:contentType});
 }
 return files;
}
export const withSignature=(body:string,signature:string)=>
 signature.trim()?body.trimEnd()+'\n\n'+signature.trim():body;
export const validSignature=(v:unknown):v is string=>
 typeof v==='string'&&v.length<=3000&&!/[\0]/.test(v);

type ResendResult={status:number;data:Record<string,unknown>|null};
async function provider(env:MailEnv,path:string,method:'GET'|'POST'|'PATCH'='GET',body?:unknown,idempotency?:string):Promise<ResendResult>{
 const key=env.RESEND_API_KEY;
 if(!key||!/^re_[a-z0-9_-]{16,}$/i.test(key))return {status:503,data:null};
 if(!(
 /^\/inboxes\/[a-z0-9._+-]+@fbmn[.]vn(?:\/threads(?:\/[0-9a-f-]{36}(?:\/emails(?:\/[0-9a-f-]{36}(?:\/reply)?)?)?)?|\/drafts(?:\/[0-9a-f-]{36}(?:\/send)?)?)?(?:\?[a-z0-9=&-]+)?$/i.test(path)
 || /^\/emails\/(?:receiving\/)?[0-9a-f-]{36}\/attachments\/[0-9a-f-]{36}$/i.test(path)
 ))
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
  if(text.length>1000000)return {status:503,data:null};
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
  attachments:Array.isArray(data.attachments)?
   data.attachments.slice(0,30).map((x:unknown)=>{
    const a=(x&&typeof x==='object'&&!Array.isArray(x))?x as Record<string,unknown>:{};
    return {id:a.id,filename:a.filename,size:a.size};
   }):[],
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
 const signatures=await db`SELECT signature_text FROM public.staff_mailbox_signatures
  WHERE mailbox=${assigned} LIMIT 1`;
 const signature=String(signatures[0]?.signature_text??'');
 if(url.pathname==='/api/v1/mail/me'&&req.method==='GET')
  return json({mailbox:assigned,enabled:Boolean(env.RESEND_API_KEY),signature});
 if(url.pathname==='/api/v1/mail/signature'&&req.method==='PUT'){
  if(!req.headers.get('content-type')?.startsWith('application/json'))return fail('Chỉ hỗ trợ JSON',415);
  let data:Record<string,unknown>;
  try{
   const raw=await req.text();
   if(raw.length>5000)throw Error('too long');
   data=JSON.parse(raw);
   if(!data||typeof data!=='object'||Array.isArray(data))throw Error('invalid');
  }catch{return fail('Chữ ký không hợp lệ');}
  if(Object.keys(data).length!==1||!('signature' in data)||!validSignature(data.signature))
   return fail('Chữ ký tối đa 3.000 ký tự',400);
  // Mailbox is derived only from the signed-in actor; check assignment again
  // inside the INSERT so a revoked employee cannot edit another inbox.
  const changed=await db`INSERT INTO public.staff_mailbox_signatures
   (mailbox,signature_text,updated_by)
   SELECT mb.mailbox,${data.signature},${actor.sub}
   FROM public.staff_mailboxes mb JOIN public.staff_members s ON s.user_sub=mb.user_sub
   WHERE mb.user_sub=${actor.sub} AND mb.mailbox=${assigned} AND s.active
   ON CONFLICT(mailbox) DO UPDATE SET signature_text=excluded.signature_text,
   updated_by=excluded.updated_by,updated_at=now() RETURNING mailbox`;
  if(!changed.length)return fail('Đã thu hồi quyền hộp thư',403);
  return json({signature:data.signature});
 }
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
  const page=await provider(env,`/inboxes/${box}/threads/${thread[1]}/emails?limit=100`);
  if(!page.data||!Array.isArray(page.data.data))return fail('Không tải được danh sách thư trong hội thoại',page.status);
  return json({thread:view(result.data),emails:page.data.data.map(v=>view(v as Record<string,unknown>)),
   has_more:page.data.has_more===true});
 }
 const letter=/^\/api\/v1\/mail\/threads\/([0-9a-f-]{36})\/emails\/([0-9a-f-]{36})$/i.exec(url.pathname);
 if(letter&&req.method==='GET'){
  if(!uuid.test(letter[1])||!uuid.test(letter[2]))return fail('Mã thư không hợp lệ');
  const result=await provider(env,`/inboxes/${box}/threads/${letter[1]}/emails/${letter[2]}`);
  if(!result.data)return fail('Không mở được email',result.status);
  return json({item:view(result.data)});
 }
 // No globally scoped Resend attachment lookup is allowed until a message
 // and the attachment's ID have been resolved inside this employee's inbox.
 const download=/^\/api\/v1\/mail\/threads\/([0-9a-f-]{36})\/emails\/([0-9a-f-]{36})\/attachments\/([0-9a-f-]{36})(\/download)?$/i.exec(url.pathname);
 if(download&&req.method==='GET'){
  if(download.slice(1).some(id=>!uuid.test(id)))return fail('Mã tệp không hợp lệ');
  const item=await provider(env,`/inboxes/${box}/threads/${download[1]}/emails/${download[2]}`);
  if(!item.data)return fail('Không được truy cập tệp này',404);
  const matches=Array.isArray(item.data.attachments)&&item.data.attachments.some((a:unknown)=>
   !!a&&typeof a==='object'&&(a as Record<string,unknown>).id===download[3]);
  if(!matches)return fail('Tệp không thuộc email đã chọn',404);
  const receiving=item.data.direction==='inbound';
  const target=receiving?
   `/emails/receiving/${download[2]}/attachments/${download[3]}`:
   `/emails/${download[2]}/attachments/${download[3]}`;
  const file=await provider(env,target);
  if(!file.data||typeof file.data.download_url!=='string')
   return fail('Tệp chưa sẵn sàng để tải',503);
  let safe:URL;
  try{safe=new URL(file.data.download_url);}catch{return fail('Liên kết tệp không hợp lệ',503);}
  if(safe.protocol!=='https:'||safe.username||safe.password)
   return fail('Liên kết tệp không an toàn',503);
  if(download[4]==='/download'){
   // Same-origin browser navigation keeps the HttpOnly session cookie intact,
   // while the redirect points only to the short-lived Resend signed URL.
   return new Response(null,{status:302,headers:{
    Location:safe.toString(),'Cache-Control':'private, no-store',
    'Referrer-Policy':'no-referrer'
   }});
  }
  return json({url:safe.toString(),filename:file.data.filename??null,expires_at:file.data.expires_at??null});
 }
 const mark=/^\/api\/v1\/mail\/threads\/([0-9a-f-]{36})\/read$/i.exec(url.pathname);
 if(mark&&req.method==='POST'){
  if(!uuid.test(mark[1]))return fail('Mã hội thoại không hợp lệ');
  const done=await provider(env,`/inboxes/${box}/threads/${mark[1]}`,'PATCH',{read:true});
  if(!done.data)return fail('Không đánh dấu đã đọc được',done.status);
  return json({ok:true});
 }
 const reply=/^\/api\/v1\/mail\/threads\/([0-9a-f-]{36})\/emails\/([0-9a-f-]{36})\/reply$/i.exec(url.pathname);
 if(reply&&req.method==='POST'){
  if(!uuid.test(reply[1])||!uuid.test(reply[2]))return fail('Mã thư không hợp lệ');
  let data:Record<string,unknown>;
  try{
   const raw=await req.text();
   if(raw.length>60000)throw Error('limit');
   data=JSON.parse(raw);
  }catch{return fail('Nội dung trả lời không hợp lệ');}
  if(!data||typeof data!=='object'||Array.isArray(data)||
   Object.keys(data).some(k=>!['text','request_id','attachments'].includes(k))||
   typeof data.text!=='string'||!data.text.trim()||data.text.length>12000||
   typeof data.request_id!=='string'||!uuid.test(data.request_id))
    return fail('Nội dung trả lời không hợp lệ');
  const attachments=validateAttachments(data.attachments);
  if(!attachments)return fail('Tệp không hợp lệ; tối đa 4 tệp, tổng 5 MB',400);
  const result=await provider(env,`/inboxes/${box}/threads/${reply[1]}/emails/${reply[2]}/reply`,
   'POST',{text:withSignature(data.text.trim(),signature),...(attachments.length?{attachments}:{})},
   'field-mail-reply/'+data.request_id);
  if(!result.data||typeof result.data.id!=='string')return fail('Không trả lời được email',result.status);
  return json({id:result.data.id,status:'sent'},201);
 }
 if(url.pathname==='/api/v1/mail/send'&&req.method==='POST'){
  if(!req.headers.get('content-type')?.startsWith('application/json'))return fail('Chỉ hỗ trợ JSON',415);
  let payload:Record<string,unknown>;
  try{
   const raw=await req.text();
   if(raw.length>MAX_BODY_CHARS)throw Error('limit');
   payload=JSON.parse(raw);
   if(!payload||typeof payload!=='object'||Array.isArray(payload))throw Error('shape');
  }catch{return fail('Nội dung email không hợp lệ');}
  if(Object.keys(payload).some(k=>!['to','subject','text','request_id','attachments'].includes(k))||
   typeof payload.to!=='string'||!email.test(payload.to)||
   typeof payload.subject!=='string'||!payload.subject.trim()||
   payload.subject.length>200||/[\r\n]/.test(payload.subject)||
   typeof payload.text!=='string'||!payload.text.trim()||payload.text.length>12000||
   typeof payload.request_id!=='string'||!uuid.test(payload.request_id))
    return fail('Nội dung hoặc người nhận không hợp lệ');
  const attachments=validateAttachments(payload.attachments);
  if(!attachments)return fail('Tệp không hợp lệ; tối đa 4 tệp, tổng 5 MB',400);
  // A new inbox message must first be a draft. Generic /emails does not
  // record the sent message in the assigned inbox, so never use it here.
  const requestId=String(payload.request_id);
  const draft=await provider(env,`/inboxes/${box}/drafts`,'POST',{
   to:[payload.to.trim().toLowerCase()],subject:payload.subject.trim(),
   text:withSignature(payload.text.trim(),signature),...(attachments.length?{attachments}:{})
  },'field-mail-draft/'+requestId);
  if(!draft.data||typeof draft.data.id!=='string'||!uuid.test(draft.data.id))
   return fail('Chưa tạo được thư nháp để gửi',draft.status);
  const sent=await provider(env,`/inboxes/${box}/drafts/${draft.data.id}/send`,'POST',
   undefined,'field-mail-send/'+requestId);
  if(!sent.data||typeof sent.data.id!=='string')
   return json({error:'Chưa xác nhận gửi thành công; thư nháp vẫn được giữ',
     draft_id:draft.data.id},503);
  return json({id:sent.data.id,status:'sent'},201);
 }
 return fail('Không hỗ trợ thao tác email này',405);
}
