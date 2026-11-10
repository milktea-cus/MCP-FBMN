import { neon } from '@neondatabase/serverless';
import {AuthError, authRoutes, userFromRequest, provisionIdentity} from './auth';
import {staffRoutes} from './staff';
import districts from './districts_old.json';
import {customerRoutes} from './customers';
import {surveyRoutes} from './surveys';

interface Env {
  DATABASE_URL: string;
  AUTH_ISSUER: string;
  AUTH_AUDIENCE: string;
  AUTH_JWKS_URL: string;
  ALLOWED_ORIGINS: string;
  PHOTOS_BUCKET?: R2Bucket;
}
type Kind = 'survey' | 'target' | 'forecast' | 'visit' | 'dealer' | 'competitor' | 'support';
const kinds: Kind[] = ['survey', 'target', 'forecast', 'visit', 'dealer', 'competitor', 'support'];
type Json = Record<string, unknown>;
interface SalesRecordBody {
  kind?: Kind;
  client_ref?: string;
  version?: number;
  province?: string;
  district?: string;
  customer_name?: string;
  period_ym?: string;
  data?: Json;
}
const locationMap = districts as Record<string, string[]>;
const json = (value: unknown, status = 200): Response => new Response(JSON.stringify(value), {
  status, headers: {'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store'},
});
const bad = (message: string, status = 400) => json({error: message}, status);
const allowedOrigin = (origin: string | null, env: Env) =>
  !!origin && env.ALLOWED_ORIGINS.split(',').map(v => v.trim()).includes(origin);
function cors(res: Response, origin: string | null, env: Env): Response {
  if (!allowedOrigin(origin, env)) return res;
  const h = new Headers(res.headers);
  h.set('Access-Control-Allow-Origin', origin!);
  h.set('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Upload-Id, X-Photo-Kind, X-Captured-At, X-Sync-Identity, X-Sync-Revision');
  h.set('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
  h.set('Vary', 'Origin');
  return new Response(res.body, {status: res.status, headers: h});
}
function validate(body: SalesRecordBody, requireKind: boolean): string | null {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return 'Dữ liệu không hợp lệ';
  if (requireKind && (!body.kind || !kinds.includes(body.kind))) return 'Loại biểu mẫu không hợp lệ';
  if (body.province && !locationMap[body.province]) return 'Tỉnh/TP không thuộc danh mục địa giới cũ';
  if (body.district && (!body.province || !locationMap[body.province]?.includes(body.district)))
    return 'Huyện/Quận không phù hợp với tỉnh';
  if (body.kind && body.kind !== 'target' && !body.province) return 'Thiếu tỉnh/TP';
  if (body.kind && !['target', 'competitor'].includes(body.kind) && !body.district) return 'Thiếu huyện/quận';
  if (body.period_ym && !/^\d{4}-(0[1-9]|1[0-2])$/.test(body.period_ym)) return 'Tháng phải có dạng YYYY-MM';
  if (body.data !== undefined && (body.data === null || typeof body.data !== 'object' || Array.isArray(body.data)))
    return 'data phải là một object';
  if (body.customer_name && body.customer_name.length > 240) return 'Tên khách hàng quá dài';
  if (body.kind === 'survey' && !body.customer_name?.trim()) return 'Thiếu tên điểm bán';
  if (body.kind === 'target' && !body.period_ym) return 'Thiếu tháng kế hoạch';
  if (body.kind === 'forecast' && (!body.customer_name?.trim() || !body.period_ym))
    return 'Dự kiến doanh thu cần tên khách hàng và tháng';
  if ((body.kind === 'target' || body.kind === 'forecast') && body.data) {
    const weekly = body.data.weekly;
    if (!Array.isArray(weekly) || weekly.length !== 5 || weekly.some(v => typeof v !== 'number' || !Number.isFinite(v) || v < 0))
      return 'Doanh thu 5 tuần phải là các số không âm';
  }
  return null;
}
async function readBody(req: Request): Promise<SalesRecordBody> {
  if (!req.headers.get('content-type')?.toLowerCase().includes('application/json'))
    throw new Error('Content-Type phải là application/json');
  if (Number(req.headers.get('content-length') ?? 0) > 64000) throw new Error('Dữ liệu quá lớn');
  const raw = await req.text();
  if (raw.length > 64000) throw new Error('Dữ liệu quá lớn');
  return JSON.parse(raw) as SalesRecordBody;
}
export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const origin = req.headers.get('Origin');
    if (req.method === 'OPTIONS')
      return cors(new Response(null, {status: allowedOrigin(origin, env) ? 204 : 403}), origin, env);
    if (req.headers.has('Cookie') && !['GET','HEAD','OPTIONS'].includes(req.method) && !allowedOrigin(origin,env)) return bad('Origin không hợp lệ',403);
    if (origin && !allowedOrigin(origin, env)) return bad('Origin không được cho phép', 403);
    const answer = async (): Promise<Response> => {
      const url = new URL(req.url);
      if (url.pathname === '/health' && req.method === 'GET') {
        if(!env.DATABASE_URL)return json({status:'unavailable',database:'unconfigured'},503);
        try{await neon(env.DATABASE_URL)`SELECT 1`;return json({status:'ok',database:'ok'});}catch{return json({status:'unavailable',database:'unavailable'},503);}
      }
      if (!env.DATABASE_URL) return bad('DATABASE_URL chưa được cấu hình', 503);
      const authResponse = await authRoutes(req, env, url);
      if (authResponse) return authResponse;
      let user: Awaited<ReturnType<typeof userFromRequest>>;
      user = await userFromRequest(req, env);
      const syncIdentity=req.headers.get('X-Sync-Identity');
      if(syncIdentity!==null&&(syncIdentity!==user.sub||req.headers.get('X-Sync-Revision')!==String(user.staff.scope_revision)))return bad('Phiên hoặc địa bàn đồng bộ đã thay đổi',403);
      if (url.pathname === '/api/v1/me' && req.method === 'GET') return json({identity: user.sub, role: user.staff.role, employee_code: user.staff.employee_code, full_name: user.staff.full_name, email: user.staff.email, scope_revision: String(user.staff.scope_revision), scopes: user.scopes, permissions: user.admin ? ['staff:manage','records:all'] : user.manager ? ['records:team','records:own'] : ['records:own']});
      if(url.pathname==='/api/v1/admin/identity')return provisionIdentity(req,env,user);
      const staffResponse = await staffRoutes(req, env, user, url);
      if (staffResponse) return staffResponse;
      if (url.pathname === '/api/v1/meta' && req.method === 'GET') {
        const allowed = user.admin ? locationMap : Object.fromEntries(Object.entries(locationMap).filter(([p])=>user.scopes.some(s=>s.province===p)).map(([p,ds])=>[p,ds.filter(d=>user.scopes.some(s=>s.province===p && (s.district==='' || s.district===d)))]));
        return json({districts: allowed, kinds});
      }
      if (!env.DATABASE_URL) return bad('DATABASE_URL chưa được cấu hình', 503);
      const productResponse = await customerRoutes(req, env, user, url);
      if (productResponse) return productResponse;
      const surveyResponse=await surveyRoutes(req,env,user,url);
      if(surveyResponse)return surveyResponse;
      const sql = neon(env.DATABASE_URL);
      if(url.pathname==='/api/v1/routes'&&req.method==='GET'){
        const day=url.searchParams.get('day')??'';
        if(!/^\d{4}-\d{2}-\d{2}$/.test(day)||!Number.isFinite(Date.parse(day))||new Date(day).toISOString().slice(0,10)!==day)return bad('Ngày không hợp lệ');
        const date=new Date(day+'T00:00:00Z'),monday=new Date(date);
        monday.setUTCDate(date.getUTCDate()-((date.getUTCDay()+6)%7));
        const sunday=new Date(monday);sunday.setUTCDate(monday.getUTCDate()+6);
        const weekStart=monday.toISOString().slice(0,10),weekEnd=sunday.toISOString().slice(0,10);
        const period=url.searchParams.get('period')??'day';
        if(!['day','week','month'].includes(period))return bad('Kỳ không hợp lệ');
        const monthly=period==='month',weekly=period==='week';
        const monthStart=day.slice(0,7)+'-01';
        const monthEnd=new Date(Date.UTC(date.getUTCFullYear(),date.getUTCMonth()+1,0)).toISOString().slice(0,10);
        const start=monthly?monthStart:weekly?weekStart:day,end=monthly?monthEnd:weekly?weekEnd:day;
        const province=url.searchParams.get('province')??'';
        const items=await sql`WITH eligible AS (
          SELECT c.*,s.full_name FROM customers c JOIN staff_members s ON s.user_sub=c.owner_sub
          WHERE public.sales_can_access(${user.sub},c.owner_sub,c.province,c.district)
          AND (${!province} OR c.province=${province})
        ), planned AS (
          SELECT r.id,r.version,r.owner_sub,r.data,r.province,r.district
          FROM sales_records r WHERE r.kind='visit' AND r.data->>'plannedDate' BETWEEN ${start} AND ${end}
          AND public.sales_can_access(${user.sub},r.owner_sub,r.province,r.district)
        )
        SELECT r.id,r.version,c.owner_sub,c.full_name,c.province,c.district,
          coalesce(r.data,'{}'::jsonb) AS data,c.id AS customer_id,c.name,c.address_line,c.latitude,c.longitude,
          r.id IS NOT NULL AS planned,
          coalesce(v.visited,false) AS visited,coalesce(v.visited_week,false) AS visited_week,coalesce(v.visited_period,false) AS visited_period,v.last_visit,v.week_visits,coalesce(s.completed_sessions,0) AS completed_sessions
        FROM eligible c LEFT JOIN planned r ON r.data->>'customerId'=c.id::text AND r.owner_sub=c.owner_sub
        LEFT JOIN LATERAL (
          SELECT bool_or(to_char(x.checkin_at AT TIME ZONE 'Asia/Ho_Chi_Minh','YYYY-MM-DD')=coalesce(r.data->>'plannedDate',${day})) AS visited,
          bool_or((x.checkin_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN ${weekStart}::date AND ${weekEnd}::date) AS visited_week,
          bool_or((x.checkin_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN ${start}::date AND ${end}::date) AS visited_period,
          max(x.checkin_at) AS last_visit,count(*) FILTER(WHERE (x.checkin_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN ${weekStart}::date AND ${weekEnd}::date) AS week_visits
          FROM field_visits x WHERE x.customer_id=c.id AND x.owner_sub=c.owner_sub
        ) v ON true
        LEFT JOIN LATERAL (
          SELECT count(*) AS completed_sessions FROM field_survey_sessions fs WHERE fs.customer_id=c.id AND fs.owner_sub=c.owner_sub AND fs.status='completed'
          AND (fs.started_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN ${start}::date AND ${end}::date
          AND public.sales_can_access(${user.sub},fs.owner_sub,fs.province,fs.district)
        ) s ON true
        ORDER BY r.data->>'plannedDate' NULLS LAST,CASE WHEN r.data->>'sequence' ~ '^[0-9]{1,4}$' THEN (r.data->>'sequence')::int ELSE 9999 END,c.name,c.id`;
        return json({items,week_start:weekStart,week_end:weekEnd,period_start:start,period_end:end});
      }
      if(url.pathname==='/api/v1/reports/monthly'&&req.method==='GET'){
        const month=url.searchParams.get('month')??'';
        if(!/^\d{4}-(0[1-9]|1[0-2])$/.test(month))return bad('Tháng không hợp lệ');
        const province=url.searchParams.get('province')??'';
        const items=await sql`WITH r AS (
          SELECT owner_sub,province,kind,data FROM sales_records
          WHERE period_ym=${month} AND kind IN ('target','forecast')
            AND public.sales_can_access(${user.sub},owner_sub,province,district)
            AND (${!province} OR province=${province})
        ), totals AS (
          SELECT owner_sub,province,
            sum(CASE WHEN kind='target' AND jsonb_typeof(data->'monthlyTarget')='number' THEN (data->>'monthlyTarget')::numeric ELSE 0 END) AS target,
            sum(CASE WHEN kind='forecast' THEN coalesce((SELECT sum(CASE WHEN jsonb_typeof(w)='number' THEN (w#>>'{}')::numeric ELSE 0 END) FROM jsonb_array_elements(CASE WHEN jsonb_typeof(data->'weekly')='array' THEN data->'weekly' ELSE '[]'::jsonb END) w),0) ELSE 0 END) AS forecast,
            count(*) FILTER(WHERE kind='forecast') AS forecasts
          FROM r GROUP BY owner_sub,province
        ), visits AS (
          SELECT v.owner_sub,c.province,count(*) AS checkins
          FROM field_visits v JOIN customers c ON c.id=v.customer_id
          WHERE to_char(v.checkin_at AT TIME ZONE 'Asia/Ho_Chi_Minh','YYYY-MM')=${month}
            AND public.sales_can_access(${user.sub},c.owner_sub,c.province,c.district)
            AND public.sales_can_access(${user.sub},v.owner_sub,c.province,c.district)
            AND (${!province} OR c.province=${province})
          GROUP BY v.owner_sub,c.province
        )
        SELECT coalesce(t.owner_sub,v.owner_sub) AS owner_sub,coalesce(t.province,v.province) AS province,
          s.full_name,coalesce(t.target,0) AS target,coalesce(t.forecast,0) AS forecast,
          coalesce(t.forecasts,0) AS forecasts,coalesce(v.checkins,0) AS checkins
        FROM totals t FULL JOIN visits v ON t.owner_sub=v.owner_sub AND coalesce(t.province,'')=coalesce(v.province,'')
        JOIN staff_members s ON s.user_sub=coalesce(t.owner_sub,v.owner_sub)
        ORDER BY s.full_name,coalesce(t.province,v.province) NULLS FIRST`;
        return json({month,items});
      }
      if (url.pathname === '/api/v1/records' && req.method === 'GET') {
        const kind = url.searchParams.get('kind') ?? '';
        if (!kinds.includes(kind as Kind)) return bad('kind không hợp lệ');
        const province = url.searchParams.get('province') ?? '';
        const period = url.searchParams.get('period_ym') ?? '';
        const rows = await sql`
          SELECT id, kind, owner_sub, province, district, customer_name, period_ym,
                 data, version, created_at, updated_at
          FROM sales_records
          WHERE kind = ${kind} AND public.sales_can_access(${user.sub},owner_sub,province,district)
            AND (${!province} OR province = ${province})
            AND (${!period} OR period_ym = ${period})
          ORDER BY updated_at DESC LIMIT 200`;
        return json({items: rows});
      }
      if (url.pathname === '/api/v1/records' && req.method === 'POST') {
        let body: SalesRecordBody;
        try { body = await readBody(req); } catch { return bad('JSON không hợp lệ'); }
        const error = validate(body, true);
        if(body.kind&&['visit','forecast','survey'].includes(body.kind)&&body.data?.customerId!==undefined){
          const id=body.data.customerId,day=body.data.plannedDate,sequence=body.data.sequence;
          if(typeof id!=='string'||!/^[0-9a-f-]{36}$/i.test(id)||(body.kind==='visit'&&(typeof day!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(day)||!Number.isFinite(Date.parse(day))||new Date(day).toISOString().slice(0,10)!==day||typeof sequence!=='number'||!Number.isInteger(sequence)||sequence<1||sequence>9999)))return bad('Điểm ghé, ngày hoặc thứ tự không hợp lệ');
          const customer=await sql`SELECT name,province,district,owner_sub FROM customers WHERE id::text=${id} AND public.sales_can_access(${user.sub},owner_sub,province,district)`;
          if(!customer.length)return bad('Không có quyền điểm bán',403);
          if(customer[0].owner_sub!==user.sub)return bad('Chỉ lập tuyến/biểu mẫu cho khách hàng của mình',403);
          if(body.province!==customer[0].province||body.district!==customer[0].district)return bad('Địa bàn tuyến không khớp điểm bán');
          body.customer_name=customer[0].name;
        }
        if(body.client_ref!==undefined && !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(body.client_ref))return bad('client_ref không hợp lệ');
        if (error) return bad(error);
        if (body.province && !user.admin) {
          const scope = await sql`SELECT 1 FROM staff_scopes WHERE user_sub=${user.sub}
            AND province=${body.province} AND (district='' OR district=${body.district ?? ''}) LIMIT 1`;
          if (!scope.length) return bad('Chưa được phân địa bàn này', 403);
        }
        const rows = await sql`
          INSERT INTO sales_records (kind, owner_sub, province, district, customer_name, period_ym, data, client_ref)
          SELECT ${body.kind!}, ${user.sub}, ${body.province ?? null}, ${body.district ?? null},
                  ${body.customer_name ?? null}, ${body.period_ym ?? null}, ${JSON.stringify(body.data ?? {})}::jsonb, ${body.client_ref??null}::uuid
          WHERE public.sales_can_access(${user.sub},${user.sub},${body.province ?? null},${body.district ?? null})
          AND (${body.data?.customerId==null} OR EXISTS(SELECT 1 FROM customers c WHERE c.id::text=${String(body.data?.customerId??'')} AND public.sales_can_access(${user.sub},c.owner_sub,c.province,c.district) AND c.province=${body.province??null} AND c.district=${body.district??null})) ON CONFLICT DO NOTHING RETURNING *`;
        if(rows.length)return json({item:rows[0]},201);
        if(body.client_ref){const existing=await sql`SELECT * FROM sales_records WHERE owner_sub=${user.sub} AND client_ref=${body.client_ref}::uuid AND public.sales_can_access(${user.sub},owner_sub,province,district)`;if(existing.length)return json({item:existing[0],idempotent:true});}
        return bad('Bản ghi đã tồn tại hoặc không có quyền địa bàn',409);
      }
      const match = /^\/api\/v1\/records\/([0-9a-f-]{36})$/i.exec(url.pathname);
      if (match && req.method === 'PATCH') {
        let body: SalesRecordBody;
        try { body = await readBody(req); } catch { return bad('JSON không hợp lệ'); }
        if (body.kind || !body.data) return bad('PATCH chỉ hỗ trợ data cùng trường địa bàn');
        const current = await sql`SELECT * FROM sales_records WHERE id=${match[1]}::uuid
          AND public.sales_can_access(${user.sub},owner_sub,province,district) LIMIT 1`;
        if (!current.length) return bad('Không tìm thấy hoặc không có quyền', 404);
        const old=current[0];
        if(old.owner_sub!==user.sub&&!user.admin)return bad('Chỉ xem dữ liệu cấp dưới, không sửa thay',403);
        if(old.kind==='visit'&&old.data?.customerId){
          if(typeof body.client_ref!=='string'||!/^[0-9a-f-]{36}$/i.test(body.client_ref)||!Number.isInteger(body.version))return bad('Thiếu phiên bản hoặc mã thao tác');
          if(old.last_mutation_ref===body.client_ref)return json({item:old,idempotent:true});
          if(Number(old.version)!==body.version)return bad('Tuyến đã thay đổi, tải lại trước khi sửa',409);
          const day=body.data.plannedDate,sequence=body.data.sequence;
          if(typeof day!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(day)||!Number.isFinite(Date.parse(day))||new Date(day).toISOString().slice(0,10)!==day||typeof sequence!=='number'||!Number.isInteger(sequence)||sequence<1||sequence>9999)return bad('Ngày hoặc thứ tự không hợp lệ');
          const data={...old.data,plannedDate:day,sequence,purpose:String(body.data.purpose??'').slice(0,1000)};
          try{const rows=await sql`UPDATE sales_records SET data=${JSON.stringify(data)}::jsonb,version=version+1,last_mutation_ref=${body.client_ref}::uuid,updated_at=now() WHERE id=${match[1]}::uuid AND version=${body.version!} AND public.sales_can_access(${user.sub},owner_sub,province,district) AND EXISTS(SELECT 1 FROM customers c WHERE c.id::text=${String(old.data.customerId)} AND public.sales_can_access(${user.sub},c.owner_sub,c.province,c.district))
          AND NOT EXISTS(SELECT 1 FROM field_visits v WHERE v.customer_id::text=${String(old.data.customerId)} AND v.owner_sub=sales_records.owner_sub AND (v.checkin_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=(sales_records.data->>'plannedDate')::date) RETURNING *`;return rows.length?json({item:rows[0]}):bad('Tuyến đã ghé, xung đột phiên bản hoặc quyền',409);}
          catch(e){if((e as {code?:string}).code==='23505')return bad('Khách đã có lịch ngày này',409);throw e;}
        }
        if(['target','forecast'].includes(old.kind)){
          if(typeof body.client_ref!=='string'||!/^[0-9a-f-]{36}$/i.test(body.client_ref)||!Number.isInteger(body.version))return bad('Thiếu phiên bản hoặc mã thao tác');
          if(old.last_mutation_ref===body.client_ref)return json({item:old,idempotent:true});
          if(Number(old.version)!==body.version)return bad('Kế hoạch đã thay đổi, tải lại trước khi sửa',409);
          const data:Json={...body.data, ...(old.data?.customerId?{customerId:old.data.customerId}:{})};
          const error=validate({kind:old.kind,province:old.province,district:old.district,customer_name:old.customer_name,period_ym:old.period_ym,data},true);
          if(error)return bad(error);
          if(old.kind==='target'&&(typeof data.monthlyTarget!=='number'||!Number.isFinite(data.monthlyTarget)||data.monthlyTarget<0))return bad('Chỉ tiêu không hợp lệ');
          const rows=await sql`UPDATE sales_records SET data=${JSON.stringify(data)}::jsonb,version=version+1,last_mutation_ref=${body.client_ref}::uuid,updated_at=now() WHERE id=${match[1]}::uuid AND version=${body.version!} AND public.sales_can_access(${user.sub},owner_sub,province,district) RETURNING *`;
          return rows.length?json({item:rows[0]}):bad('Xung đột phiên bản hoặc quyền',409);
        }
        const province = body.province ?? current[0].province;
        const district = body.district ?? current[0].district;
        if (province && !locationMap[province]) return bad('Tỉnh không hợp lệ');
        if (district && (!province || !locationMap[province]?.includes(district)))
          return bad('Huyện không khớp tỉnh; phải chọn lại huyện', 400);
        if (province && !user.admin) {
          const scope = await sql`SELECT 1 FROM staff_scopes WHERE user_sub=${user.sub}
            AND province=${province} AND (district='' OR district=${district ?? ''}) LIMIT 1`;
          if (!scope.length) return bad('Chưa được phân địa bàn này', 403);
        }
        const rows = await sql`
          UPDATE sales_records SET province=${province}, district=${district},
            data=${JSON.stringify(body.data)}::jsonb, updated_at=now()
          WHERE id=${match[1]}::uuid AND public.sales_can_access(${user.sub},owner_sub,province,district) AND public.sales_can_access(${user.sub},owner_sub,${province},${district}) RETURNING *`;
        return rows.length ? json({item: rows[0]}) : bad('Không tìm thấy hoặc không có quyền', 404);
      }
      if (match && req.method === 'DELETE') {
        if (!user.admin) return bad('Chỉ admin được xóa', 403);
        const rows = await sql`DELETE FROM sales_records WHERE id = ${match[1]}::uuid RETURNING id`;
        return rows.length ? json({deleted: rows[0].id}) : bad('Không tìm thấy', 404);
      }
      return bad('Endpoint không tồn tại', 404);
    };
    try { return cors(await answer(), origin, env); }
    catch (e) { return cors(e instanceof AuthError ? bad(e.message,e.status) : bad('Lỗi hệ thống, vui lòng thử lại', 500), origin, env); }
  },
};