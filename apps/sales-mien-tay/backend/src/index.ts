import { neon } from '@neondatabase/serverless';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import districts from './districts_old.json';
import {customerRoutes} from './customers';

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
  h.set('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Upload-Id');
  h.set('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
  h.set('Vary', 'Origin');
  return new Response(res.body, {status: res.status, headers: h});
}
async function userFromRequest(request: Request, env: Env) {
  const match = /^Bearer (\S+)$/i.exec(request.headers.get('Authorization') ?? '');
  if (!match) throw new Error('Thiếu access token');
  if (!env.AUTH_JWKS_URL.startsWith('https://')) throw new Error('AUTH_JWKS_URL chưa hợp lệ');
  const jwks = createRemoteJWKSet(new URL(env.AUTH_JWKS_URL));
  const { payload } = await jwtVerify(match[1], jwks, {
    issuer: env.AUTH_ISSUER, audience: env.AUTH_AUDIENCE, algorithms: ['RS256', 'ES256'],
  });
  if (!payload.sub) throw new Error('Token thiếu subject');
  // Chỉ tin role/roles trong JWT đã xác minh chữ ký, không tin role trong request body.
  const roles = [payload.role, ...(Array.isArray(payload.roles) ? payload.roles : [])]
    .filter((v): v is string => typeof v === 'string');
  return {sub: payload.sub, manager: roles.includes('manager') || roles.includes('admin'),
    admin: roles.includes('admin')};
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
    if (origin && !allowedOrigin(origin, env)) return bad('Origin không được cho phép', 403);
    const answer = async (): Promise<Response> => {
      const url = new URL(req.url);
      if (url.pathname === '/health' && req.method === 'GET') return json({status: 'worker_alive', database: 'not_checked'});
      let user: Awaited<ReturnType<typeof userFromRequest>>;
      try { user = await userFromRequest(req, env); } catch { return bad('Chưa xác thực hoặc token không hợp lệ', 401); }
      if (url.pathname === '/api/v1/meta' && req.method === 'GET')
        return json({districts: locationMap, kinds});
      if (!env.DATABASE_URL) return bad('DATABASE_URL chưa được cấu hình', 503);
      const productResponse = await customerRoutes(req, env, user, url);
      if (productResponse) return productResponse;
      const sql = neon(env.DATABASE_URL);
      if (url.pathname === '/api/v1/records' && req.method === 'GET') {
        const kind = url.searchParams.get('kind') ?? '';
        if (!kinds.includes(kind as Kind)) return bad('kind không hợp lệ');
        const province = url.searchParams.get('province') ?? '';
        const period = url.searchParams.get('period_ym') ?? '';
        const rows = await sql`
          SELECT id, kind, owner_sub, province, district, customer_name, period_ym,
                 data, created_at, updated_at
          FROM sales_records
          WHERE kind = ${kind} AND (owner_sub = ${user.sub} OR ${user.admin} OR
            (${user.manager} AND EXISTS (SELECT 1 FROM staff_scopes s
              WHERE s.user_sub=${user.sub} AND s.province=sales_records.province
                AND (s.district='' OR s.district=sales_records.district))))
            AND (${!province} OR province = ${province})
            AND (${!period} OR period_ym = ${period})
          ORDER BY updated_at DESC LIMIT 200`;
        return json({items: rows});
      }
      if (url.pathname === '/api/v1/records' && req.method === 'POST') {
        let body: SalesRecordBody;
        try { body = await readBody(req); } catch { return bad('JSON không hợp lệ'); }
        const error = validate(body, true);
        if (error) return bad(error);
        if (body.province && !user.admin) {
          const scope = await sql`SELECT 1 FROM staff_scopes WHERE user_sub=${user.sub}
            AND province=${body.province} AND (district='' OR district=${body.district ?? ''}) LIMIT 1`;
          if (!scope.length) return bad('Chưa được phân địa bàn này', 403);
        }
        const rows = await sql`
          INSERT INTO sales_records (kind, owner_sub, province, district, customer_name, period_ym, data)
          VALUES (${body.kind!}, ${user.sub}, ${body.province ?? null}, ${body.district ?? null},
                  ${body.customer_name ?? null}, ${body.period_ym ?? null}, ${JSON.stringify(body.data ?? {})}::jsonb)
          RETURNING *`;
        return json({item: rows[0]}, 201);
      }
      const match = /^\/api\/v1\/records\/([0-9a-f-]{36})$/i.exec(url.pathname);
      if (match && req.method === 'PATCH') {
        let body: SalesRecordBody;
        try { body = await readBody(req); } catch { return bad('JSON không hợp lệ'); }
        if (body.kind || !body.data) return bad('PATCH chỉ hỗ trợ data cùng trường địa bàn');
        const current = await sql`SELECT province,district,owner_sub FROM sales_records WHERE id=${match[1]}::uuid
          AND (owner_sub=${user.sub} OR ${user.admin}) LIMIT 1`;
        if (!current.length) return bad('Không tìm thấy hoặc không có quyền', 404);
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
          WHERE id=${match[1]}::uuid AND (owner_sub=${user.sub} OR ${user.admin}) RETURNING *`;
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
    catch { return cors(bad('Lỗi hệ thống, vui lòng thử lại', 500), origin, env); }
  },
};