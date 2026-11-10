import { neon } from '@neondatabase/serverless';
import { createRemoteJWKSet, jwtVerify } from 'jose';

export interface AuthEnv {
 DATABASE_URL: string;
 AUTH_ISSUER: string;
 AUTH_AUDIENCE: string;
 AUTH_JWKS_URL: string;
}
const base = 'https://ep-bitter-bar-bd8r5813.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth';
const origin = 'https://sales-mien-tay.vercel.app';
const cookieName = '__Host-sales-session';
const upstreamCookie = '__Secure-neon-auth.session_token';
const json = (body: unknown, status=200, extra: Record<string,string>={}) => new Response(JSON.stringify(body), {
 status, headers: {'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store', ...extra}
});
export class AuthError extends Error { constructor(public status: number, message: string) {super(message);} }
function cookie(req: Request): string | undefined {
 return req.headers.get('Cookie')?.split(';').map(s=>s.trim()).find(s=>s.startsWith(cookieName+'='))?.slice(cookieName.length+1);
}
function sessionHeader(value: string) { return upstreamCookie+'='+value; }
function setCookie(value: string, age: number) {
 return cookieName+'='+value+'; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age='+age;
}
async function provider(path: string, method: string, value?: string, body?: string) {
 // Workers only supports "manual" and "follow". Never forward auth cookies or
 // credentials to a redirected destination; reject redirects explicitly.
 let res:Response;
 try {
  res=await fetch(base+path,{method,redirect:'manual',headers:{Origin:origin,Accept:'application/json',
   ...(value?{Cookie:sessionHeader(value)}:{}),...(body?{'Content-Type':'application/json'}:{})},body});
 } catch {
  throw new AuthError(503,'Dịch vụ xác thực chưa sẵn sàng');
 }
 if(res.status>=300 && res.status<400) throw new AuthError(503,'Dịch vụ xác thực chưa sẵn sàng');
 return res;
}
async function sessionSubject(value: string) {
 if(value.length<32||value.length>4096||! /^[A-Za-z0-9%._~+\/=:-]+$/.test(value))throw new AuthError(401,'Phiên đăng nhập không hợp lệ');
 let res:Response;try{res=await provider('/get-session?disableCookieCache=true','GET',value);}catch{throw new AuthError(503,'Dịch vụ xác thực chưa sẵn sàng');}
 if(!res.ok) throw new AuthError(res.status>=500?503:401,'Phiên đăng nhập không hợp lệ');
 let data:{user?:{id?:string;emailVerified?:boolean};session?:{expiresAt?:string}};try{data=await res.json();}catch{throw new AuthError(401,'Phiên đăng nhập không hợp lệ');}
 if(!data?.user?.id || !data.session || !data.user.emailVerified ||
 !data.session.expiresAt || !Number.isFinite(Date.parse(data.session.expiresAt)) || Date.parse(data.session.expiresAt)<=Date.now()) throw new AuthError(401,'Phiên hết hạn hoặc email chưa xác minh');
 return data.user.id;
}
export async function principal(env: AuthEnv, sub: string) {
 const db=neon(env.DATABASE_URL);
 const rows=await db`SELECT *, public.sales_identity_exists(user_sub) AS identity_valid FROM public.staff_members WHERE user_sub=${sub}`;
 const staff=rows[0];
 if(!staff || !staff.active || !staff.identity_valid) throw new AuthError(403,'Tài khoản chưa được cấp quyền hoặc đã bị khóa');
 const scopes=await db`SELECT province,district FROM public.staff_scopes WHERE user_sub=${sub} ORDER BY province,district`;
 return {sub,admin:staff.role==='admin',manager:staff.role==='manager',staff,scopes};
}
export async function userFromRequest(req: Request, env: AuthEnv) {
 const auth=req.headers.get('Authorization');
 let sub:string;
 if(auth){
  const match=/^Bearer (\S+)$/i.exec(auth);
  if(!match || !env.AUTH_JWKS_URL?.startsWith('https://') || !env.AUTH_ISSUER || !env.AUTH_AUDIENCE) throw new AuthError(401,'Token không hợp lệ');
  try {
   const {payload}=await jwtVerify(match[1],createRemoteJWKSet(new URL(env.AUTH_JWKS_URL)),{issuer:env.AUTH_ISSUER,audience:env.AUTH_AUDIENCE,algorithms:['RS256','ES256','EdDSA'],requiredClaims:['sub','exp']});
   if(!payload.sub) throw Error('subject'); sub=payload.sub;
  }catch{throw new AuthError(401,'Token không hợp lệ hoặc hết hạn');}
 }else{
  const value=cookie(req); if(!value) throw new AuthError(401,'Chưa đăng nhập');
  sub=await sessionSubject(value);
 }
 return principal(env,sub);
}
export async function authRoutes(req: Request, env: AuthEnv, url: URL): Promise<Response|null> {
 if(!['/api/auth/login','/api/auth/logout','/api/auth/otp/request','/api/auth/otp/login'].includes(url.pathname)) return null;
 if(req.method!=='POST') return json({error:'Method not allowed'},405);
 if(req.headers.get('Origin')!==origin) return json({error:'Origin không hợp lệ'},403);
 if(url.pathname.endsWith('/logout')){
  const value=cookie(req);
  if(value){const res=await provider('/sign-out','POST',value,'{}');if(!res.ok && res.status!==401) return json({error:'Chưa thể đăng xuất; thử lại'},503);}
  return json({ok:true},200,{'Set-Cookie':setCookie('',0)});
 }
 if(!req.headers.get('Content-Type')?.includes('application/json')) return json({error:'JSON required'},400);
 const raw=await req.text();if(raw.length>4096)return json({error:'Dữ liệu quá lớn'},400);
 let data:{email?:unknown;password?:unknown;otp?:unknown};try{data=JSON.parse(raw);}catch{return json({error:'JSON không hợp lệ'},400);}
 if(!data || typeof data.email!=='string'||data.email.length>254||!data.email.includes('@')) return json({error:'Email không hợp lệ'},400);
 const email=data.email.trim().toLowerCase();
 const db=neon(env.DATABASE_URL);
 const known=await db`SELECT user_sub FROM public.staff_members WHERE lower(email)=${email} AND active LIMIT 1`;
 if(url.pathname.endsWith('/otp/request')){
  if(known.length){
   const result=await provider('/email-otp/send-verification-otp','POST',undefined,JSON.stringify({email,type:'sign-in'}));
   if(!result.ok)return json({error:'Chưa thể gửi mã. Vui lòng thử lại.'},result.status===429?429:503);
  }
  return json({ok:true});
 }
 if(!known.length)return json({error:'Đăng nhập không thành công'},401);
 const otpLogin=url.pathname.endsWith('/otp/login');
 if(otpLogin ? typeof data.otp!=='string'||!/^\d{6}$/.test(data.otp) : typeof data.password!=='string'||data.password.length>256||!data.password)
  return json({error:'Thông tin đăng nhập không hợp lệ'},400);
 const res=await provider(otpLogin?'/sign-in/email-otp':'/sign-in/email','POST',undefined,JSON.stringify(otpLogin?{email,otp:data.otp}:{email,password:data.password,rememberMe:true}));
 if(!res.ok)return json({error:'Đăng nhập không thành công. Kiểm tra thông tin hoặc mã xác minh.'},res.status===429?429:res.status>=500?503:401);
 const header=res.headers.get('Set-Cookie')??'';
 const value=header.match(/(?:^|,\s*)__Secure-neon-auth\.session_token=([^;\s,]+)/)?.[1];
 if(!value)return json({error:'Không nhận được phiên xác thực'},502);
 const sub=await sessionSubject(value);
 if(sub!==known[0].user_sub)throw new AuthError(403,'Identity không khớp hồ sơ nhân viên');
 await principal(env,sub);
 return json({ok:true},200,{'Set-Cookie':setCookie(value,604800)});
}

export async function provisionIdentity(req:Request,env:AuthEnv,actor:{admin:boolean}):Promise<Response>{
 if(!actor.admin)return json({error:'Chỉ Admin tạo tài khoản'},403);
 if(req.method!=='POST')return json({error:'Method not allowed'},405);
 if(req.headers.get('Origin')!==origin)return json({error:'Origin không hợp lệ'},403);
 const value=cookie(req);if(!value)return json({error:'Cần phiên quản trị xác thực'},401);
 let data:{email?:unknown;name?:unknown};try{const raw=await req.text();if(raw.length>4096)throw Error();data=JSON.parse(raw);}catch{return json({error:'JSON không hợp lệ'},400);}
 if(!data||typeof data.email!=='string'||data.email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email.trim())||typeof data.name!=='string'||!data.name.trim()||data.name.length>240)return json({error:'Email hoặc tên không hợp lệ'},400);
 const email=data.email.trim().toLowerCase();
 const result=await provider('/admin/create-user','POST',value,JSON.stringify({email,name:data.name.trim(),password:crypto.randomUUID()+crypto.randomUUID(),role:'user'}));
 if(!result.ok)return json({error:'Không tạo được identity. Kiểm tra quyền quản trị Neon Auth hoặc tài khoản đã tồn tại.'},result.status===401||result.status===403?403:result.status>=500?503:409);
 const created=await result.json() as {user?:{id?:string};id?:string};
 const sub=created.user?.id??created.id;
 if(!sub||!/^[0-9a-f-]{36}$/i.test(sub))return json({error:'Identity chưa được đồng bộ'},502);
 return json({user_sub:sub,email},201);
}
