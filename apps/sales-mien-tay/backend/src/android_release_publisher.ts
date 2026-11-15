import {createRemoteJWKSet,jwtVerify} from 'jose';
import {releasePackageName,validateRelease} from './app_releases';

/**
 * Private release publisher: no long-lived GitHub or R2 credentials.
 * Only the Owner-approved signed-release GitHub Actions job can call this API,
 * authenticated with a short-lived GitHub OIDC JWT.
 *
 * The first release signing key is generated on the GitHub runner, immediately
 * AES-GCM wrapped using a secret held only by Cloudflare and stored in private
 * R2. Subsequent runs retrieve exactly the same protected keystore.
 */
type Env={
 APP_RELEASES_BUCKET?:R2Bucket;
 FIELD_WORK_SIGNING_WRAP_KEY?:string;
};
const issuer='https://token.actions.githubusercontent.com';
const audience='field-work-android-release-mcp-fbmn';
const jwks=createRemoteJWKSet(new URL(issuer+'/.well-known/jwks'));
const prefix='/api/internal/field-work/android';
const signingObject='private/signing/field-work-v1.enc';
const hex64=/^[0-9a-f]{64}$/;
const encoder=new TextEncoder();
const result=(body:unknown,status=200)=>new Response(JSON.stringify(body),{
 status,headers:{'Content-Type':'application/json; charset=utf-8',
                'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'},
});
const fail=(error:string,status=400)=>result({error},status);
function hex(bytes:Uint8Array){
 return Array.from(bytes).map(b=>b.toString(16).padStart(2,'0')).join('');
}
function unhex(value:string){
 if(!hex64.test(value))throw Error('invalid wrap key');
 return Uint8Array.from(value.match(/../g)!.map(s=>parseInt(s,16)));
}
const b64=(data:Uint8Array)=>btoa(String.fromCharCode(...data));
const unb64=(value:string)=>Uint8Array.from(atob(value),c=>c.charCodeAt(0));
async function wrappingKey(value:string){
 return crypto.subtle.importKey('raw',unhex(value),'AES-GCM',false,['encrypt','decrypt']);
}
async function authorized(req:Request):Promise<boolean>{
 const auth=req.headers.get('Authorization')??'';
 if(!/^Bearer [A-Za-z0-9._-]+$/.test(auth))return false;
 try{
  const {payload}=await jwtVerify(auth.slice(7),jwks,{
   issuer,audience,algorithms:['RS256'],
   requiredClaims:['sub','exp','iat'],
   clockTolerance:5,
  });
  return payload.sub==='repo:milktea-cus/MCP-FBMN:ref:refs/heads/main' &&
   payload.repository==='milktea-cus/MCP-FBMN' &&
   String(payload.repository_id)==='1452277750' &&
   payload.actor==='milktea-cus' &&
   payload.event_name==='issue_comment' &&
   payload.ref==='refs/heads/main' &&
   payload.job_workflow_ref===
    'milktea-cus/MCP-FBMN/.github/workflows/sales-android-release.yml@refs/heads/main';
 }catch{return false;}
}
async function jsonBody(req:Request,max=90000):Promise<Record<string,unknown>|null>{
 if((Number(req.headers.get('content-length'))||0)>max)return null;
 const raw=await req.text();
 if(raw.length>max)return null;
 try{
  const value:unknown=JSON.parse(raw);
  return value!==null&&typeof value==='object'&&!Array.isArray(value)
   ?value as Record<string,unknown>:null;
 }catch{return null;}
}
type Signing={keystoreBase64:string;password:string;alias:string;signerSha256:string};
function validSigning(data:Record<string,unknown>):data is Record<keyof Signing,string>{
 return typeof data.keystoreBase64==='string' &&
  data.keystoreBase64.length>=1000 && data.keystoreBase64.length<=80000 &&
  /^[A-Za-z0-9+/]+={0,2}$/.test(data.keystoreBase64) &&
  typeof data.password==='string' &&
  /^[A-Za-z0-9_-]{30,90}$/.test(data.password) &&
  data.alias==='field-work' &&
  typeof data.signerSha256==='string' && hex64.test(data.signerSha256);
}
async function loadSigning(bucket:R2Bucket,master:string){
 const item=await bucket.get(signingObject);
 if(!item)return null;
 if(item.size>100000)throw Error('signing object too big');
 const encrypted=await item.json() as {schema:number;iv:string;ciphertext:string};
 if(encrypted.schema!==1 || !/^[a-f0-9]{24}$/.test(encrypted.iv) ||
  !encrypted.ciphertext || encrypted.ciphertext.length>150000)
  throw Error('invalid signing object');
 const key=await wrappingKey(master);
 const plain=await crypto.subtle.decrypt(
  {name:'AES-GCM',iv:Uint8Array.from(encrypted.iv.match(/../g)!.map(s=>parseInt(s,16)))},
  key,unb64(encrypted.ciphertext));
 const value:unknown=JSON.parse(new TextDecoder().decode(plain));
 if(!value || typeof value!=='object' || Array.isArray(value) ||
    !validSigning(value as Record<string,unknown>))throw Error('signing payload damaged');
 return value as Signing;
}
function apkKey(code:number){return 'releases/'+code+'/field-work-'+code+'.apk';}
const validCode=(code:number)=>Number.isSafeInteger(code)&&code>=2&&code<=100000000;
export async function githubAndroidPublisher(
 req:Request,env:Env,url:URL,
):Promise<Response|null>{
 if(!url.pathname.startsWith(prefix+'/'))return null;
 if(!await authorized(req))return fail('Không được phép phát hành Android',403);
 const bucket=env.APP_RELEASES_BUCKET;
 const master=env.FIELD_WORK_SIGNING_WRAP_KEY;
 if(!bucket||!master||!hex64.test(master))return fail('Chưa cấu hình kho ký an toàn',503);
 const path=url.pathname.slice(prefix.length);
 if(path==='/signing'){
  if(req.method==='GET'){
   try{
    const profile=await loadSigning(bucket,master);
    return profile?result(profile):fail('Chưa có khóa ký release',404);
   }catch{return fail('Không đọc được khóa ký release',503);}
  }
  if(req.method==='POST'){
   const data=await jsonBody(req);
   if(!data||!validSigning(data))return fail('Thông tin khóa ký không hợp lệ');
   if(await bucket.head(signingObject))return fail('Khóa ký đã tồn tại, không được ghi đè',409);
   try{
    const iv=crypto.getRandomValues(new Uint8Array(12));
    const key=await wrappingKey(master);
    const encrypted=await crypto.subtle.encrypt({name:'AES-GCM',iv},key,
      encoder.encode(JSON.stringify(data)));
    const envelope=JSON.stringify({schema:1,iv:hex(iv),
      ciphertext:b64(new Uint8Array(encrypted))});
    await bucket.put(signingObject,envelope,{
      httpMetadata:{contentType:'application/json'},
    });
    const checked=await loadSigning(bucket,master);
    if(!checked||checked.signerSha256!==data.signerSha256)
      return fail('Chưa xác minh được khóa ký đã lưu',503);
    return result({saved:true,signerSha256:checked.signerSha256},201);
   }catch{return fail('Không thể lưu khóa ký release',503);}
  }
  return fail('Phương thức không hỗ trợ',405);
 }
 const match=/^\/artifact\/(\d+)$/.exec(path);
 if(match){
  const code=Number(match[1]);
  if(!validCode(code))return fail('Mã phiên bản không hợp lệ');
  const key=apkKey(code);
  if(req.method==='PUT'){
   const length=Number(req.headers.get('Content-Length'));
   const digest=req.headers.get('X-APK-SHA256')??'';
   const signer=req.headers.get('X-APK-SIGNER-SHA256')??'';
   if(!Number.isSafeInteger(length)||length<4096||length>100*1024*1024||
     !hex64.test(digest)||!hex64.test(signer)||!req.body)
     return fail('APK hoặc checksum không hợp lệ',413);
   const pinned=await loadSigning(bucket,master);
   if(!pinned||pinned.signerSha256!==signer)return fail('Sai chữ ký APK',403);
   if(await bucket.head(key))return fail('Phiên bản đã phát hành, không ghi đè',409);
   try{
    await bucket.put(key,req.body,{
     httpMetadata:{contentType:'application/vnd.android.package-archive'},
     customMetadata:{sha256:digest,signersha256:signer},
    });
    const head=await bucket.head(key);
    if(!head||head.size!==length||head.customMetadata?.sha256!==digest||
       head.customMetadata?.signersha256!==signer)
     return fail('R2 không xác nhận đủ APK',503);
    return result({uploaded:true,size:head.size,sha256:digest},201);
   }catch{return fail('Lỗi upload APK vào R2',503);}
  }
  if(req.method==='GET'){
   const file=await bucket.get(key);
   if(!file)return fail('Không tìm thấy APK',404);
   return new Response(file.body,{headers:{
     'Content-Type':'application/vnd.android.package-archive',
     'Content-Length':String(file.size),'Cache-Control':'no-store',
    }});
  }
  return fail('Phương thức không hỗ trợ',405);
 }
 if(path==='/promote'&&req.method==='POST'){
  const input=await jsonBody(req,5000);
  if(!input)return fail('Manifest không hợp lệ');
  const release={
   schema:1,packageName:releasePackageName,
   versionCode:input.versionCode,versionName:input.versionName,
   size:input.size,sha256:input.sha256,signerSha256:input.signerSha256,
   objectKey:apkKey(Number(input.versionCode)),notes:input.notes,
   releasedAt:new Date().toISOString(),
  };
  const checked=validateRelease(release);
  if(!checked)return fail('Bản release không hợp lệ');
  const signer=await loadSigning(bucket,master);
  if(!signer||signer.signerSha256!==checked.signerSha256)
   return fail('Chữ ký APK không trùng khóa đã chốt',403);
  const file=await bucket.head(checked.objectKey);
  if(!file||file.size!==checked.size||
     file.customMetadata?.sha256!==checked.sha256||
     file.customMetadata?.signersha256!==checked.signerSha256)
   return fail('APK trên R2 không khớp manifest',409);
  const existing=await bucket.get('releases/latest.json');
  if(existing){
   const old=await existing.json() as {versionCode?:number;signerSha256?:string};
   if((old.versionCode??0)>=checked.versionCode || old.signerSha256!==checked.signerSha256)
    return fail('VersionCode phải tăng và giữ nguyên chữ ký',409);
   await bucket.put('releases/history/'+old.versionCode+'.json',
    JSON.stringify(old),{httpMetadata:{contentType:'application/json'}});
  }
  await bucket.put('releases/latest.json',JSON.stringify(checked),{
    httpMetadata:{contentType:'application/json'},
  });
  return result({published:true,versionCode:checked.versionCode,
   sha256:checked.sha256,signerSha256:checked.signerSha256},201);
 }
 return fail('Không tìm thấy endpoint phát hành',404);
}
