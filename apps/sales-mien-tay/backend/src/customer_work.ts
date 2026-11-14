import {neon} from '@neondatabase/serverless';
import type {AuthEnv} from './auth';
import {validateSurveyAnswers} from './surveys';

type Actor={sub:string;admin:boolean;manager:boolean};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const json=(v:unknown,status=200)=>new Response(JSON.stringify(v),{
 status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const fail=(error:string,status=400)=>json({error},status);
const isUuid=(v:unknown):v is string=>typeof v==='string'&&uuid.test(v);
type Body=Record<string,unknown>;
function when(v:unknown):string|null{
 if(typeof v!=='string'||v.length>40||v.length<20||
  !/(Z|[+-][0-9]{2}:[0-9]{2})$/.test(v)||!Number.isFinite(Date.parse(v)))return null;
 return new Date(v).toISOString();
}
export function validateCustomerWorkInput(v:Body):string|null{
 if(!isUuid(v.client_ref)||!isUuid(v.customer_id)||!isUuid(v.route_stop_id)||
  !['form','photo','order'].includes(String(v.kind))||!when(v.captured_at)||
  (v.template_id!==null&&v.template_id!==undefined&&!isUuid(v.template_id))||
  !v.answers||typeof v.answers!=='object'||Array.isArray(v.answers)||
  typeof(v.note??'')!=='string'||String(v.note??'').length>2000)return 'Hoạt động khách hàng không hợp lệ';
 const names=v.market_brands;
 if(names!==null&&names!==undefined&&(!Array.isArray(names)||names.length>50||
  names.some(x=>typeof x!=='string'||!x.trim()||x.length>100)))return 'Nhãn hàng không hợp lệ';
 if(v.kind==='photo'&&!isUuid((v.answers as Body).photo_id)||
    v.kind==='order'&&!isUuid((v.answers as Body).order_id))
  return 'Thiếu mã ảnh hoặc đơn hàng được xác nhận';
 if(v.kind==='form'&&!String(v.note??'').trim()&&
  !Object.keys(v.answers as Body).length&&names==null)
  return 'Hãy nhập ghi chú, chọn nhãn hàng hoặc một hạng mục công việc';
 return null;
}
export async function customerWorkRoutes(req:Request,env:AuthEnv,actor:Actor,url:URL):Promise<Response|null>{
 const hit=/^\/api\/v1\/day-routes\/([a-f0-9-]{36})\/customer-work$/i.exec(url.pathname);
 if(!hit)return null;
 const routeId=hit[1];
 if(!isUuid(routeId))return fail('Tuyến không hợp lệ');
 const db=neon(env.DATABASE_URL);
 if(req.method==='GET'){
  const allowed=await db`SELECT 1 FROM public.field_day_routes r
   WHERE r.id=${routeId}::uuid AND
    (r.owner_sub=${actor.sub} OR ${actor.admin} OR
     (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},r.owner_sub)))`;
  if(!allowed.length)return fail('Không có quyền xem công tác',403);
  const items=await db`SELECT a.id,a.day_route_id,a.route_stop_id,a.customer_id,
   a.owner_sub,a.kind,a.template_id,a.answers,a.market_brand_names,
   a.note,a.captured_at,a.created_at
   FROM public.field_customer_work_actions a
   WHERE a.day_route_id=${routeId}::uuid AND
    public.sales_customer_allowed(${actor.sub},a.customer_id,'view')
   ORDER BY a.captured_at DESC,a.id DESC LIMIT 1000`;
  return json({items,truncated:items.length===1000});
 }
 if(req.method!=='POST')return fail('Method not allowed',405);
 let body:Body;
 try{
  if(!req.headers.get('Content-Type')?.includes('application/json'))throw Error('JSON');
  const raw=await req.text();if(raw.length>14000)throw Error('size');
  const v:unknown=JSON.parse(raw);
  if(!v||typeof v!=='object'||Array.isArray(v))throw Error('object');
  body=v as Body;
 }catch{return fail('JSON không hợp lệ');}
 const invalid=validateCustomerWorkInput(body);
 if(invalid)return fail(invalid);
 const templateId=body.template_id??null;
 if(templateId!==null){
  const templates=await db`SELECT questions FROM public.field_survey_templates
    WHERE id=${templateId as string}::uuid LIMIT 1`;
  if(!templates.length)return fail('Mẫu công việc không còn tồn tại',409);
  const qs=(templates[0].questions as Array<Record<string,unknown>>).map(q=>({...q,required:false}));
  const check=validateSurveyAnswers(qs as Parameters<typeof validateSurveyAnswers>[0],body.answers);
  if(check)return fail(check);
  const names=body.market_brands;
  if(names!==null&&names!==undefined){
   const configured=(templates[0].questions as Array<Record<string,unknown>>)
    .filter(q=>q.catalog_source==='brands')
    .flatMap(q=>Array.isArray(q.options)?q.options as string[]:[]);
   if((names as string[]).some(n=>!configured.includes(n)))
    return fail('Nhãn hàng phải thuộc cấu hình đã phát hành',409);
  }
 }else if((body.market_brands as unknown[]|null|undefined)?.length)
  return fail('Chưa thiết lập danh sách nhãn hàng cho địa bàn',409);
 try{
  const rows=await db`SELECT public.sales_save_customer_work(
   ${actor.sub},${String(body.client_ref)}::uuid,${routeId}::uuid,
   ${String(body.route_stop_id)}::uuid,${String(body.customer_id)}::uuid,
   ${String(body.kind)},${templateId as string|null}::uuid,
   ${JSON.stringify(body.answers)}::jsonb,
   ${body.market_brands==null?null:JSON.stringify(body.market_brands)}::jsonb,
   ${String(body.note??'')},${when(body.captured_at)!}::timestamptz) AS item`;
  const item=rows[0].item as Record<string,unknown>;
  return json({item,idempotent:item.already_saved===true},item.already_saved===true?200:201);
 }catch(e){
  const msg=(e as Error)?.message??'';
  if(msg.includes('CUSTOMER_WORK_FORBIDDEN'))return fail('Ngoài công tác hoặc không có quyền làm việc tại khách',403);
  if(msg.includes('CUSTOMER_WORK_CONFLICT'))return fail('Hoạt động đã có dữ liệu khác, cần đối chiếu',409);
  if(msg.includes('CUSTOMER_WORK_INVALID'))return fail('Hoạt động hoặc mẫu không hợp lệ',400);
  return fail('Không lưu được hoạt động tại khách',503);
 }
}
