import {neon} from '@neondatabase/serverless';
import districts from './districts_old.json';

interface Actor {sub:string;admin:boolean;manager:boolean}
interface Env {DATABASE_URL:string}
type Json = Record<string,unknown>;
const catalog=districts as Record<string,string[]>;
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ok=(value:unknown,status=200)=>new Response(JSON.stringify(value),{
 status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const bad=(message:string,status=400)=>ok({error:message},status);
const kinds=['support','competitor'];
const messageFor=(v:string):[string,number]=>{
 if(v.includes('SCOPED_VERSION_CONFLICT'))return ['Bản ghi đã được sửa trên thiết bị khác; tải lại trước khi sửa.',409];
 if(v.includes('SCOPED_FORBIDDEN')||v.includes('SCOPED_AREA_FORBIDDEN')||v.includes('SCOPED_CUSTOMER_FORBIDDEN'))
   return ['Không có quyền với tỉnh/huyện hoặc khách hàng đã chọn.',403];
 if(v.includes('SCOPED_TITLE_REQUIRED'))return ['Vui lòng nhập tiêu đề.',400];
 if(v.includes('SCOPED_INVALID_PROVINCE'))return ['Tỉnh không thuộc danh mục.',400];
 if(v.includes('SCOPED_INVALID'))return ['Phạm vi bản ghi không hợp lệ.',400];
 if(v.includes('23505'))return ['Bản ghi đã tồn tại, đồng bộ lại danh sách.',409];
 return ['Không thể lưu bản ghi. Vui lòng thử lại.',500];
};
function normalize(body:Json):{kind:string;provinces:string[];district:string;customers:string[];data:Json;version:number;ref:string}|string{
 const kind=body.kind;
 if(typeof kind!=='string'||!kinds.includes(kind))return 'Loại biểu mẫu không hợp lệ';
 const provinces=body.provinces;
 if(!Array.isArray(provinces)||provinces.length<1||provinces.length>13||
   provinces.some(p=>typeof p!=='string'||!catalog[p])||new Set(provinces).size!==provinces.length)
   return 'Chọn tỉnh hợp lệ, không trùng.';
 const district=body.district??'';
 if(typeof district!=='string'||(district && (provinces.length!==1||!catalog[provinces[0]].includes(district))))
   return 'Nhiều tỉnh không chọn huyện; huyện phải thuộc tỉnh đã chọn.';
 const customerIds=body.customer_ids??[];
 if(!Array.isArray(customerIds)||customerIds.length>1000||customerIds.some(x=>typeof x!=='string'||!uuid.test(x))
   ||new Set(customerIds).size!==customerIds.length)
   return 'Danh sách khách hàng không hợp lệ hoặc bị trùng.';
 if(body.data===null||typeof body.data!=='object'||Array.isArray(body.data))
   return 'Dữ liệu biểu mẫu không hợp lệ.';
 const data=body.data as Json;
 if(typeof data.title!=='string'||data.title.trim().length<1||data.title.trim().length>240)
   return 'Tiêu đề không hợp lệ.';
 const fields=kind==='support'
  ?['title','requestedHelp','expectedOutcome','priority','dueDate','status','department','notes']
  :['title','program','discount','pricing','effectivePeriod','source','recommendation'];
 const cleaned:Json={};
 for(const key of fields){
  const value=data[key]??'';
  if(typeof value!=='string'||value.length>4000)return 'Thông tin vượt quá giới hạn cho phép.';
  cleaned[key]=value.trim();
 }
 const version=body.version;
 const ref=body.client_ref;
 if(!Number.isInteger(version)||(version as number)<0||(version as number)>1000000
   ||typeof ref!=='string'||!uuid.test(ref))return 'Thiếu phiên bản hoặc mã thao tác đồng bộ.';
 return {kind,provinces,district,customers:customerIds,data:cleaned,version:version as number,ref};
}

/** Support and competitor records use the same normalized, versioned write boundary. */
export async function scopedRecordRoutes(req:Request,env:Env,actor:Actor,url:URL):Promise<Response|null>{
 const path=url.pathname;
 const match=/^\/api\/v1\/scoped-records\/([0-9a-f-]{36})$/i.exec(path);
 if(path!=='/api/v1/scoped-records'&&!match)return null;
 const db=neon(env.DATABASE_URL);
 if(path==='/api/v1/scoped-records'&&req.method==='GET'){
  const kind=url.searchParams.get('kind')??'';
  if(!kinds.includes(kind))return bad('Loại biểu mẫu không hợp lệ');
  const province=(url.searchParams.get('province')??'').trim();
  if(province&&!catalog[province])return bad('Tỉnh không hợp lệ');
  const rows=await db`SELECT to_jsonb(r)||jsonb_build_object('data',
    r.data||jsonb_build_object(
      'provinces',coalesce((SELECT jsonb_agg(a.province ORDER BY a.province)
        FROM public.sales_record_areas a WHERE a.record_id=r.id),
        CASE WHEN r.province IS NULL THEN '[]'::jsonb ELSE jsonb_build_array(r.province) END),
      'customerIds',coalesce((SELECT jsonb_agg(x.customer_id ORDER BY c.name)
        FROM public.sales_record_customers x JOIN public.customers c ON c.id=x.customer_id
        WHERE x.record_id=r.id AND public.sales_customer_allowed(${actor.sub},c.id,'view')),'[]'::jsonb)
    )) AS item
    FROM public.sales_records r WHERE r.kind=${kind}
     AND public.sales_staff_action_allowed(${actor.sub},r.owner_sub,'view')
     AND (${province}='' OR EXISTS(SELECT 1 FROM public.sales_record_areas a
       WHERE a.record_id=r.id AND a.province=${province})
       OR (NOT EXISTS(SELECT 1 FROM public.sales_record_areas a WHERE a.record_id=r.id)
         AND r.province=${province}))
    ORDER BY r.updated_at DESC,r.id DESC LIMIT 200`;
  return ok({items:rows.map(r=>r.item)});
 }
 if((path==='/api/v1/scoped-records'&&req.method==='POST')||(match&&req.method==='PATCH')){
  let payload:Json;
  try{
    if(!req.headers.get('content-type')?.toLowerCase().includes('application/json'))return bad('Yêu cầu JSON');
    const raw=await req.text();
    if(raw.length>64000)return bad('Dữ liệu quá lớn',413);
    payload=JSON.parse(raw);
    if(!payload||typeof payload!=='object'||Array.isArray(payload))return bad('JSON không hợp lệ');
  }catch{return bad('JSON không hợp lệ');}
  const v=normalize(payload);
  if(typeof v==='string')return bad(v);
  if(match&&!uuid.test(match[1]))return bad('Mã bản ghi không hợp lệ');
  if(match&&v.version===0)return bad('Cần phiên bản đã lưu');
  if(!match&&v.version!==0)return bad('Bản ghi mới phải có phiên bản 0');
  try{
   const rows=await db`SELECT public.sales_save_scoped_record(
     ${actor.sub},${v.kind},${match?.[1]??null}::uuid,${v.ref}::uuid,${v.version},
     ARRAY(SELECT value FROM jsonb_array_elements_text(${JSON.stringify(v.provinces)}::jsonb)),
     ${v.district},
     ARRAY(SELECT value::uuid FROM jsonb_array_elements_text(${JSON.stringify(v.customers)}::jsonb)),
     ${JSON.stringify(v.data)}::jsonb) AS item`;
   return ok({item:rows[0]?.item},match?200:201);
  }catch(error){
   const e=error as {code?:string;message?:string};
   const [message,status]=messageFor((e.code??'')+' '+(e.message??''));
   return bad(message,status);
  }
 }
 return bad('Phương thức không được hỗ trợ',405);
}
