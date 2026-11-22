import {neon} from '@neondatabase/serverless';
import districts from './districts_old.json';
import type {AuthEnv} from './auth';

type Actor={sub:string;admin:boolean;manager:boolean};
const areas=districts as Record<string,string[]>;
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const respond=(value:unknown,status=200)=>new Response(JSON.stringify(value),{status,
 headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const fail=(error:string,status=400)=>respond({error},status);
const clean=(x:unknown,max:number)=>typeof x==='string'&&x.trim().length<=max?x.trim():null;
function tax(raw:unknown):string|null|undefined{
 if(raw===null||raw===undefined||raw==='')return null;
 if(typeof raw!=='string'||raw.length>24)return undefined;
 const value=raw.replace(/[\s.-]/g,'');
 return /^\d{10}(?:\d{3})?$/.test(value)?value:undefined;
}
async function body(req:Request):Promise<Record<string,unknown>>{
 if(!req.headers.get('Content-Type')?.toLowerCase().includes('application/json'))
  throw Error('json');
 const raw=await req.text();
 if(raw.length>12000)throw Error('size');
 const value:unknown=JSON.parse(raw);
 if(!value||typeof value!=='object'||Array.isArray(value))throw Error('body');
 return value as Record<string,unknown>;
}
function failure(err:unknown){
 const m=(err as Error).message??'';
 if(m.includes('market_forbidden'))return fail('Không có quyền với địa bàn hoặc điểm bán',403);
 if(m.includes('market_conflict'))return fail('Dữ liệu đã thay đổi hoặc đã xử lý',409);
 if(m.includes('market_visit_required'))return fail('Phải ghi nhận GPS ghé thực tế trước khi chuyển khách',409);
 if(m.includes('market_school_mismatch'))return fail('Trường không thuộc địa bàn của điểm bán',400);
 if(m.includes('market_invalid'))return fail('Thông tin điểm bán hoặc vị trí không hợp lệ');
 return fail('Không lưu được điểm bán tiềm năng',503);
}
function numberParam(text:string|null,defaultValue:number,max:number){
 const value=text??String(defaultValue);
 if(!/^[1-9]\d*$/.test(value))return null;
 const n=Number(value);return Number.isSafeInteger(n)&&n<=max?n:null;
}

/** One canonical lead source: public.field_prospects, including existing route leads. */
export async function marketProspectRoutes(req:Request,env:AuthEnv,actor:Actor,url:URL):Promise<Response|null>{
 const base='/api/v1/market-prospects';
 if(url.pathname!==base&&!url.pathname.startsWith(base+'/'))return null;
 const db=neon(env.DATABASE_URL);
 const detailed=new RegExp('^/api/v1/market-prospects/([a-f0-9-]{36})(?:/(visits|convert|close))?$', 'i').exec(url.pathname);
 if(url.pathname===base&&req.method==='GET'){
  const province=(url.searchParams.get('province')??'').trim();
  const district=(url.searchParams.get('district')??'').trim();
  const wardNew=(url.searchParams.get('ward_new')??'').trim();
  const status=(url.searchParams.get('status')??'').trim();
  const search=(url.searchParams.get('q')??'').trim();
  const schoolId=(url.searchParams.get('school_id')??'').trim();
  const page=numberParam(url.searchParams.get('page'),1,10000);
  const size=numberParam(url.searchParams.get('size'),20,50);
  if(!page||!size||search.length>120||province.length>120||district.length>120||wardNew.length>120||
    ((district!==''||wardNew!=='')&&province==='')||!['','new','converted','closed'].includes(status)||
    (schoolId!==''&&!uuid.test(schoolId)))return fail('Bộ lọc điểm bán không hợp lệ');
  const result=await db`
   WITH visible AS (
    SELECT p.id,p.owner_sub,p.name,p.address_line,p.province,p.district,p.ward_new,
      p.address_legacy,p.google_maps_url,p.google_place_id,p.category,
      p.phone,p.tax_code,p.note,p.source_kind,p.school_id,p.status,p.converted_customer_id,
      p.last_visit_at,p.last_visit_latitude,p.last_visit_longitude,p.version,p.created_at,
      s.name AS school_name,
      (SELECT count(*)::int FROM public.field_prospect_visits v WHERE v.prospect_id=p.id) + CASE WHEN p.area_visit_id IS NULL THEN 0 ELSE 1 END AS visits,
      (SELECT count(*)::int FROM public.field_market_prospect_photos f WHERE f.prospect_id=p.id AND f.status='ready') AS photo_count
    FROM public.field_prospects p LEFT JOIN public.schools s ON s.id=p.school_id
    WHERE p.province IS NOT NULL AND
     public.sales_market_prospect_allowed(${actor.sub},p.id)
     AND (${province}='' OR p.province=${province})
     AND (${district}='' OR p.district=${district})
     AND (${wardNew}='' OR p.ward_new=${wardNew})
     AND (${status}='' OR p.status=${status})
     AND (${schoolId}='' OR p.school_id=${schoolId||null}::uuid)
     AND (${search}='' OR position(lower(${search}) in lower(p.name))>0)
   )
   SELECT (SELECT count(*)::int FROM visible) AS total,
    coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM (
     SELECT * FROM visible ORDER BY created_at DESC,id DESC
      LIMIT ${size} OFFSET ${(page-1)*size}
    ) t),'[]'::jsonb) AS items`;
  // Wards come only from prospects visible under server-side ACL; the
  // parent province/district are legacy territory scopes, never new wards.
  const wardRows=province===''?[]:await db`SELECT DISTINCT p.ward_new
    FROM public.field_prospects p
    WHERE p.province=${province} AND p.ward_new IS NOT NULL
      AND (${district}='' OR p.district=${district})
      AND public.sales_market_prospect_allowed(${actor.sub},p.id)
    ORDER BY p.ward_new LIMIT 150`;
  return respond({items:result[0]?.items??[],total:result[0]?.total??0,
   page,size,hasMore:page*size<Number(result[0]?.total??0),
   wards:wardRows.map(r=>String(r.ward_new))});
 }
 if(url.pathname===base+'/tax-check'&&req.method==='GET'){
  const value=tax(url.searchParams.get('mst'));
  if(value===undefined||value===null)return fail('MST phải có 10 hoặc 13 chữ số');
  const [customers,prospects]=await Promise.all([
   db`SELECT c.id,c.name,c.province,c.district,c.status
      FROM public.customers c
      WHERE regexp_replace(coalesce(c.vat_tax_code,''),'[^0-9]','','g')=${value}
      AND public.sales_customer_allowed(${actor.sub},c.id,'view')
      ORDER BY c.name LIMIT 20`,
   db`SELECT p.id,p.name,p.province,p.district,p.status,p.converted_customer_id
      FROM public.field_prospects p WHERE p.tax_code=${value} AND p.province IS NOT NULL
      AND public.sales_market_prospect_allowed(${actor.sub},p.id)
      ORDER BY p.created_at DESC LIMIT 20`
  ]);
  return respond({customers,prospects});
 }
 if(url.pathname===base&&req.method==='POST'){
  let b:Record<string,unknown>;try{b=await body(req);}catch{return fail('JSON không hợp lệ');}
  const id=b.client_ref;
  const name=clean(b.name,240),address=clean(b.address_line,500);
  const province=clean(b.province,120),district=clean(b.district,120);
  const category=b.category??'khac',phone=clean(b.phone,20),note=clean(b.note,2000)??'';
  const code=tax(b.tax_code),school=b.school_id??null;
  if(typeof id!=='string'||!uuid.test(id)||!name||name.length<2||
   !address||address.length<3||!province||!district||
   !['tap_hoa','sieu_thi','dai_ly','npp','nha_sach','van_phong_pham','cua_hang','khac'].includes(String(category))||
   code===undefined||(b.phone!==null&&b.phone!==undefined&&b.phone!==''&&(!phone||phone.length<8))||
   (school!==null&&(typeof school!=='string'||!uuid.test(school))))return fail('Dữ liệu điểm bán không hợp lệ');
  if(!areas[province]?.includes(district)){
   const valid=await db`SELECT 1 FROM public.territory_catalog p JOIN public.territory_catalog d
    ON d.parent_code=p.code WHERE p.level='province' AND d.level='district' AND p.active AND d.active
    AND p.name=${province} AND d.name=${district} LIMIT 1`;
   if(!valid.length)return fail('Tỉnh huyện không hợp lệ');
  }
  try{
   const rows=await db`SELECT public.sales_market_prospect_create(
    ${actor.sub},${id}::uuid,${name},${address},${province},${district},
    ${String(category)},${phone||null},${code??null},${note},${school}::uuid) AS item`;
   return respond({item:rows[0]?.item},201);
  }catch(e){return failure(e);}
 }
 if(!detailed||!uuid.test(detailed[1]))return fail('Không tìm thấy điểm bán tiềm năng',404);
 const id=detailed[1],action=detailed[2]??'';
 const permitted=async()=>{
  const rows=await db`SELECT p.id,p.owner_sub,p.province,p.district FROM public.field_prospects p
    WHERE p.id=${id}::uuid AND p.province IS NOT NULL AND
     public.sales_market_prospect_allowed(${actor.sub},p.id)`;
  return rows.length>0;
 };
 if(req.method==='GET'&&action===''){
  if(!await permitted())return fail('Không tìm thấy điểm bán hoặc không có quyền',404);
  const rows=await db`SELECT p.*,
    (SELECT count(*)::int FROM public.field_prospect_visits v WHERE v.prospect_id=p.id) + CASE WHEN p.area_visit_id IS NULL THEN 0 ELSE 1 END AS visit_count
    FROM public.field_prospects p WHERE p.id=${id}::uuid`;
  return respond({item:rows[0]});
 }
 if(req.method==='PATCH'&&action===''){
  let b:Record<string,unknown>;try{b=await body(req);}catch{return fail('JSON không hợp lệ');}
  const name=clean(b.name,240),address=clean(b.address_line,500);
  const code=tax(b.tax_code),phone=clean(b.phone,20);
  const category=b.category??'khac',note=clean(b.note,2000)??'';
  if(!Number.isInteger(b.version)||Number(b.version)<1||!name||name.length<2||
   !address||address.length<3||code===undefined||
   !['tap_hoa','sieu_thi','dai_ly','npp','nha_sach','van_phong_pham','cua_hang','khac'].includes(String(category))||
   (b.phone!==null&&b.phone!==undefined&&b.phone!==''&&(!phone||phone.length<8)))
   return fail('Thông tin chỉnh sửa không hợp lệ');
  try{
   const rows=await db`SELECT public.sales_market_prospect_update(
    ${actor.sub},${id}::uuid,${Number(b.version)},${name},${address},
    ${String(category)},${phone||null},${code??null},${note}) AS item`;
   return respond({item:rows[0]?.item});
  }catch(e){return failure(e);}
 }
 if(req.method==='GET'&&action==='visits'){
  if(!await permitted())return fail('Không tìm thấy điểm bán hoặc không có quyền',404);
  const rows=await db`SELECT x.id,x.owner_sub,x.checked_at,x.latitude,x.longitude,x.accuracy_m,x.note
    FROM (
     SELECT id,owner_sub,checked_at,latitude,longitude,accuracy_m,note
      FROM public.field_prospect_visits WHERE prospect_id=${id}::uuid
     UNION ALL
     SELECT a.id,a.owner_sub,a.checkin_at,a.latitude,a.longitude,a.accuracy_m,a.note
      FROM public.field_area_visits a
      JOIN public.field_prospects p ON p.area_visit_id=a.id WHERE p.id=${id}::uuid
    ) x ORDER BY x.checked_at DESC LIMIT 100`;
  return respond({items:rows});
 }
 if(req.method==='POST'&&action==='visits'){
  let b:Record<string,unknown>;try{b=await body(req);}catch{return fail('JSON không hợp lệ');}
  const ref=b.client_ref,when=b.captured_at,lat=b.latitude,lon=b.longitude,acc=b.accuracy_m;
  const note=clean(b.note,2000)??'';
  if(typeof ref!=='string'||!uuid.test(ref)||typeof when!=='string'||
    !Number.isFinite(Date.parse(when))||b.location_consent!==true||
    typeof lat!=='number'||!Number.isFinite(lat)||lat < -90||lat>90||
    typeof lon!=='number'||!Number.isFinite(lon)||lon < -180||lon>180||
    typeof acc!=='number'||!Number.isFinite(acc)||acc<0||acc>100)return fail('Cần GPS thực tế chính xác ≤100m');
  try{
   const rows=await db`SELECT public.sales_market_prospect_visit(
    ${actor.sub},${id}::uuid,${ref}::uuid,${new Date(when).toISOString()}::timestamptz,
    ${lat},${lon},${acc},${note}) AS item`;
   return respond({item:rows[0]?.item},201);
  }catch(e){return failure(e);}
 }
 if(req.method==='POST'&&(action==='convert'||action==='close')){
  let b:Record<string,unknown>={};
  if(action==='convert'){try{b=await body(req);}catch{return fail('JSON không hợp lệ');}}
  const customer=b.customer_id??null;
  if(customer!==null&&(typeof customer!=='string'||!uuid.test(customer)))return fail('Mã khách không hợp lệ');
  try{
   const rows=action==='convert'
    ?await db`SELECT public.sales_market_prospect_convert(${actor.sub},${id}::uuid,${customer}::uuid) AS item`
    :await db`SELECT public.sales_market_prospect_close(${actor.sub},${id}::uuid) AS item`;
   return respond({item:rows[0]?.item});
  }catch(e){return failure(e);}
 }
 return fail('Method not allowed',405);
}
