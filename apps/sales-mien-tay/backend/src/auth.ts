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
 return fetch(base+path,{method,redirect:'error',headers:{Origin:origin,Accept:'application/json',
 ...(value?{Cookie:sessionHeader(value)}:{}),...(body?{'Content-Type':'application/json'}:{})},body});
}
async function sessionSubject(value: string) {
 const res=await provider('/get-session?disableCookieCache=true','GET',value);
 if(!res.ok) throw new AuthError(res.status>=500?503:401,'Phiên đăng nhập không hợp lệ');
 const data=await res.json() as {user?:{id?:string;emailVerified?:boolean};session?:{expiresAt?:string}};
 if(!data?.user?.id || !data.session || !data.user.emailVerified ||
 !data.session.expiresAt || Date.parse(data.session.expiresAt)<=Date.now()) throw new AuthError(401,'Phiên hết hạn hoặc email chưa xác minh');
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
 if(url.pathname!='/api/auth/login' && url.pathname!='/api/auth/logout') return null;
 if(req.method!=='POST') return json({error:'Method not allowed'},405);
 if(req.headers.get('Origin')!==origin) return json({error:'Origin không hợp lệ'},403);
 if(url.pathname.endsWith('/logout')){
  const value=cookie(req);
  if(value){const res=await provider('/sign-out','POST',value,'{}');if(!res.ok && res.status!==401) return json({error:'Chưa thể đăng xuất; thử lại'},503);}
  return json({ok:true},200,{'Set-Cookie':setCookie('',0)});
 }
 if(!req.headers.get('Content-Type')?.includes('application/json')) return json({error:'JSON required'},400);
 const raw=await req.text();if(raw.length>4096)return json({error:'Dữ liệu quá lớn'},400);
 let data:{email?:unknown;password?:unknown};try{data=JSON.parse(raw);}catch{return json({error:'JSON không hợp lệ'},400);}
 if(!data || typeof data.email!=='string'||typeof data.password!=='string'||data.email.length>254||data.password.length>256||!data.password) return json({error:'Thông tin đăng nhập không hợp lệ'},400);
 const res=await provider('/sign-in/email','POST',undefined,JSON.stringify({email:data.email.trim(),password:data.password,rememberMe:true}));
 if(!res.ok)return json({error:'Đăng nhập không thành công. Kiểm tra tài khoản, mật khẩu và xác minh email.'},res.status===429?429:res.status>=500?503:401);
 const header=res.headers.get('Set-Cookie')??'';
 const value=header.match(/(?:^|,\s*)__Secure-neon-auth\.session_token=([^;\s,]+)/)?.[1];
 if(!value)return json({error:'Không nhận được phiên xác thực'},502);
 const sub=await sessionSubject(value);
 await principal(env,sub);
 return json({ok:true},200,{'Set-Cookie':setCookie(value,604800)});
}
