import type {userFromRequest} from './auth';

/**
 * Field Work APK distribution. The release bucket must remain private.
 * Publishing is performed by the signed CI release workflow, never by an API.
 */
type Actor=Awaited<ReturnType<typeof userFromRequest>>;
type ReleaseEnv={
  APP_RELEASES_BUCKET?:R2Bucket;
  APP_DOWNLOAD_HMAC_KEY?:string;
};
export type AndroidRelease={
  schema:1;
  versionCode:number;
  versionName:string;
  packageName:string;
  size:number;
  sha256:string;
  signerSha256:string;
  objectKey:string;
  notes:string;
  releasedAt:string;
};

export const releasePackageName='com.example.sales_mien_tay';
const latestKey='releases/latest.json';
const maxApkSize=250*1024*1024;
const hex64=/^[a-f0-9]{64}$/;
const respond=(data:unknown,status=200)=>new Response(JSON.stringify(data),{
  status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'private, no-store'}
});
const error=(message:string,status=400)=>respond({error:message},status);

/** Exact whitelist prevents release-manifest path injection and foreign packages. */
export function validateRelease(data:unknown):AndroidRelease|null{
  if(!data||typeof data!=='object'||Array.isArray(data))return null;
  const d=data as Record<string,unknown>;
  if(d.schema!==1||!Number.isSafeInteger(d.versionCode)||Number(d.versionCode)<2||Number(d.versionCode)>100000000||
     typeof d.versionName!=='string'||!/^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.]+)?$/.test(d.versionName)||
     d.versionName.length>48||d.packageName!==releasePackageName||
     !Number.isSafeInteger(d.size)||Number(d.size)<4096||Number(d.size)>maxApkSize||
     typeof d.sha256!=='string'||!hex64.test(d.sha256)||
     typeof d.signerSha256!=='string'||!hex64.test(d.signerSha256)||
     typeof d.notes!=='string'||d.notes.length>2000||
     typeof d.releasedAt!=='string'||d.releasedAt.length>48||
     Number.isNaN(Date.parse(d.releasedAt))||
     d.objectKey!==`releases/${d.versionCode}/field-work-${d.versionCode}.apk`)return null;
  return d as AndroidRelease;
}
function publicRelease(d:AndroidRelease){
  return {versionCode:d.versionCode,versionName:d.versionName,packageName:d.packageName,
    size:d.size,sha256:d.sha256,signerSha256:d.signerSha256,notes:d.notes,releasedAt:d.releasedAt};
}
async function activeRelease(bucket:R2Bucket):Promise<AndroidRelease|null>{
  const file=await bucket.get(latestKey);
  if(!file)return null;
  if(file.size>5000)throw Error('release manifest too large');
  let value:unknown;
  try{value=await file.json();}catch{throw Error('invalid release manifest');}
  const release=validateRelease(value);
  if(!release)throw Error('untrusted release manifest');
  const apk=await bucket.head(release.objectKey);
  if(!apk||apk.size!==release.size||
      apk.customMetadata?.sha256!==release.sha256||
      apk.customMetadata?.signersha256!==release.signerSha256)
    throw Error('release APK not verified');
  return release;
}
const encoder=new TextEncoder();
function toHex(input:ArrayBuffer):string{
  return [...new Uint8Array(input)].map(n=>n.toString(16).padStart(2,'0')).join('');
}
async function digest(env:ReleaseEnv,parts:string):Promise<string>{
  const secret=env.APP_DOWNLOAD_HMAC_KEY;
  if(!secret||secret.length<32||secret.length>512)throw Error('download key not configured');
  const key=await crypto.subtle.importKey('raw',encoder.encode(secret),
    {name:'HMAC',hash:'SHA-256'},false,['sign']);
  return toHex(await crypto.subtle.sign('HMAC',key,encoder.encode(parts)));
}
function secureMatch(a:string,b:string):boolean{
  if(a.length!==b.length)return false;
  let diff=0;
  for(let i=0;i<a.length;i++)diff|=a.charCodeAt(i)^b.charCodeAt(i);
  return diff===0;
}
function signPayload(user:Actor,release:AndroidRelease,expires:number){
  return [user.sub,user.staff.scope_revision,release.versionCode,release.sha256,expires].join(':');
}
function configured(env:ReleaseEnv){
  return !!env.APP_RELEASES_BUCKET&&!!env.APP_DOWNLOAD_HMAC_KEY&&env.APP_DOWNLOAD_HMAC_KEY.length>=32;
}
export async function appReleaseRoutes(req:Request,env:ReleaseEnv,user:Actor,url:URL):Promise<Response|null>{
  const path=url.pathname;
  if(!path.startsWith('/api/v1/app/releases'))return null;
  if(!configured(env))return error('Chưa bật cập nhật Android',503);
  const bucket=env.APP_RELEASES_BUCKET!;
  if(path==='/api/v1/app/releases/latest'&&req.method==='GET'){
    try{
      const latest=await activeRelease(bucket);
      return latest?respond({available:true,release:publicRelease(latest)}):respond({available:false});
    }catch{return error('Bản cập nhật chưa được xác minh',503);}
  }
  if(path==='/api/v1/app/releases/ticket'&&req.method==='POST'){
    let version:unknown;
    try{
      if(Number(req.headers.get('content-length')??0)>1024)return error('Dữ liệu không hợp lệ',413);
      const body=await req.text();
      if(body.length>1024)return error('Dữ liệu không hợp lệ',413);
      version=(JSON.parse(body) as Record<string,unknown>).versionCode;
    }catch{return error('Dữ liệu không hợp lệ');}
    try{
      const latest=await activeRelease(bucket);
      if(!latest||version!==latest.versionCode)return error('Phiên bản không còn khả dụng',409);
      const expires=Math.floor(Date.now()/1000)+300;
      const signature=await digest(env,signPayload(user,latest,expires));
      const query=new URLSearchParams({
        versionCode:String(latest.versionCode),expires:String(expires),signature
      });
      return respond({url:`/api/v1/app/releases/download?${query.toString()}`,expires});
    }catch{return error('Không tạo được liên kết tải APK',503);}
  }
  if(path==='/api/v1/app/releases/download'&&req.method==='GET'){
    const version=Number(url.searchParams.get('versionCode')??0);
    const expires=Number(url.searchParams.get('expires')??0);
    const signature=url.searchParams.get('signature')??'';
    const now=Math.floor(Date.now()/1000);
    if(!Number.isSafeInteger(version)||!Number.isSafeInteger(expires)||
       expires<=now||expires>now+300||!hex64.test(signature))
      return error('Liên kết tải đã hết hạn hoặc không hợp lệ',403);
    try{
      const release=await activeRelease(bucket);
      if(!release||version!==release.versionCode)return error('Phiên bản không còn được phát hành',409);
      const correct=await digest(env,signPayload(user,release,expires));
      if(!secureMatch(signature,correct))return error('Không có quyền tải bản cập nhật',403);
      const range=req.headers.get('Range');
      let offset=0;
      if(range){
        const match=/^bytes=(\d+)-$/.exec(range);
        if(!match||!Number.isSafeInteger(Number(match[1]))||Number(match[1])>=release.size)
          return new Response(null,{status:416,headers:{'Content-Range':`bytes */${release.size}`}});
        offset=Number(match[1]);
      }
      const apk=await bucket.get(release.objectKey,
        offset?{range:{offset}}:undefined);
      if(!apk)return error('Tệp APK không tồn tại',503);
      const headers=new Headers({
        'Content-Type':'application/vnd.android.package-archive',
        'Content-Disposition':`attachment; filename="field-work-${version}.apk"`,
        'Content-Length':String(release.size-offset),
        'Cache-Control':'private, no-store',
        'X-Content-Type-Options':'nosniff',
        'Accept-Ranges':'bytes',
      });
      if(offset)headers.set('Content-Range',`bytes ${offset}-${release.size-1}/${release.size}`);
      return new Response(apk.body,{status:offset?206:200,headers});
    }catch{return error('Chưa tải được APK từ R2',503);}
  }
  return error('Endpoint cập nhật không tồn tại',404);
}
