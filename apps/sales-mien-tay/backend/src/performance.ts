import {neon} from '@neondatabase/serverless';
import type {userFromRequest} from './auth';
type User=Awaited<ReturnType<typeof userFromRequest>>;
type Group='employee'|'province'|'customer'|'product'|'month';
type Mode='employee'|'customer'|'product'|'none';
const reply=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const invalid=(reason:string,status=400)=>reply({error:reason},status);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export interface ReportFilters{
 year:number;period:'month'|'quarter'|'year';month:number;quarter:number;
 group:Group;owner:string;province:string;customer:string;product:string;
 startMonth:number;endMonth:number;
}
export function reportTargetMode(f:Pick<ReportFilters,'group'|'province'|'customer'|'product'>):Mode{
 if(f.product&&(f.customer||f.province))return 'none';
 if(f.group==='province'&&!f.customer)return 'none';
 if(f.province&&!f.customer)return 'none';
 if(f.group==='customer'&&f.product)return 'none';
 if(f.group==='product'&&f.customer)return 'none';
 if(f.customer)return 'customer';
 if(f.product)return 'product';
 if(f.group==='customer')return 'customer';
 if(f.group==='product')return 'product';
 return 'employee';
}
export function reportPeriod(y:number,p:string,m:number,q:number){
 if(!Number.isInteger(y)||y<2000||y>2100||!['month','quarter','year'].includes(p))return null;
 if(p==='month'&&(!Number.isInteger(m)||m<1||m>12))return null;
 if(p==='quarter'&&(!Number.isInteger(q)||q<1||q>4))return null;
 const start=p==='year'?1:p==='quarter'?(q-1)*3+1:m;
 return {start,end:p==='year'?13:p==='quarter'?start+3:start+1};
}
export function reportMetric(target:bigint|null,actual:bigint,records:number){
 return {target:target?.toString()??null,actual:actual.toString(),records,
   remaining:target===null?null:(target>actual?target-actual:0n).toString(),
   progress_percent:target!==null&&target>0n&&records>0?
     Math.round(Number(actual*1000n/target))/10:null};
}
function parse(url:URL,sub:string,manager:boolean):ReportFilters|null{
 const period=url.searchParams.get('period')??'month',year=Number(url.searchParams.get('year')??'NaN'),
 month=Number(url.searchParams.get('month')??'NaN'),quarter=Number(url.searchParams.get('quarter')??'NaN');
 const dates=reportPeriod(year,period,month,quarter);
 const group=url.searchParams.get('group')??'employee',owner=url.searchParams.get('owner')??sub,
 province=url.searchParams.get('province')??'',customer=url.searchParams.get('customer')??'',product=url.searchParams.get('product')??'';
 if(!dates||!['employee','province','customer','product','month'].includes(group)||
 owner.length>150||province.length>100||(!manager&&owner!==sub)||
 (customer!==''&&!uuid.test(customer))||(product!==''&&!uuid.test(product)))return null;
 return {year,period:period as ReportFilters['period'],month,quarter,group:group as Group,owner,
   province,customer,product,startMonth:dates.start,endMonth:dates.end};
}
type Db=ReturnType<typeof neon>;
async function validateScope(sql:Db,u:User,f:ReportFilters):Promise<string|null>{
 const ownerList=await sql`SELECT user_sub FROM staff_members WHERE active AND public.sales_can_access(${u.sub},user_sub,NULL,NULL)`;
 if(f.owner==='all'&&!u.admin&&!u.manager)return 'Không có quyền xem toàn đội';
 if(f.owner!=='all'&&!ownerList.some(x=>x.user_sub===f.owner))return 'Không có quyền nhân viên';
 if(f.customer){
  const rows=await sql`SELECT 1 FROM customers c WHERE c.id=${f.customer}::uuid
  AND (${f.owner==='all'} OR c.owner_sub=${f.owner})
  AND public.sales_can_access(${u.sub},c.owner_sub,c.province,c.district)
  AND (${!f.province} OR c.province=${f.province})`;
  if(!rows.length)return 'Không có quyền khách hàng hoặc địa bàn';
 }
 if(f.province&&!u.admin){
  const areas=await sql`SELECT 1 FROM staff_scopes sc WHERE sc.province=${f.province}
     AND EXISTS(SELECT 1 FROM staff_members st WHERE st.user_sub=sc.user_sub AND st.active
       AND public.sales_can_access(${u.sub},st.user_sub,sc.province,sc.district)) LIMIT 1`;
  if(!areas.length)return 'Không có quyền tỉnh được chọn';
 }
 if(f.product){
  const rows=await sql`SELECT 1 FROM catalog_products WHERE id=${f.product}::uuid AND active`;
  if(!rows.length)return 'Mã CTY không hợp lệ';
 }
 return null;
}
function aggregateRows(actualRows:Record<string,unknown>[],targets:Record<string,unknown>[],group:Group,mode:Mode){
 const grouped=new Map<string,{id:string,label:string,code:string,actual:bigint,records:number,quantity:bigint,target:bigint|null}>();
 const put=(id:string,label:string,code:string)=>{
  let entry=grouped.get(id);if(!entry){entry={id,label,code,actual:0n,records:0,quantity:0n,target:mode==='none'?null:0n};grouped.set(id,entry);}
  return entry;
 };
 for(const r of actualRows){
  const id=String(r.id),entry=put(id,String(r.label??id),String(r.code??''));
  entry.actual+=BigInt(String(r.amount));entry.quantity+=BigInt(String(r.quantity));entry.records+=Number(r.records);
 }
 for(const t of targets){
  const owner=String(t.owner_sub),entity=String(t.entity_id),mo=String(t.month).slice(0,7);
  const id=group==='month'?mo:group==='employee'?owner:group==='province'?String(t.province):entity;
  const label=group==='employee'?String(t.employee_name):group==='month'?mo:
   group==='customer'?String(t.customer_name??entity):group==='product'?String(t.product_name??entity):String(t.province);
  const code=group==='employee'?String(t.employee_code??''):
   group==='customer'?String(t.customer_code??''):group==='product'?String(t.company_code??''):'';
  const entry=put(id,label,code);entry.target=(entry.target??0n)+BigInt(String(t.amount));
 }
 const rows=[...grouped.values()].sort((x,y)=>x.actual===y.actual?x.label.localeCompare(y.label,'vi'):(x.actual>y.actual?-1:1))
  .map(x=>({id:x.id,label:x.label,code:x.code,quantity:x.quantity.toString(),...reportMetric(x.target,x.actual,x.records)}));
 return rows;
}
export async function performanceRoutes(req:Request,env:{DATABASE_URL:string},u:User,url:URL):Promise<Response|null>{
 const path=url.pathname;
 if(!path.startsWith('/api/v1/reports/performance'))return null;
 if(req.method!=='GET')return invalid('Chỉ cho phép GET',405);
 const sql=neon(env.DATABASE_URL),manager=u.admin||u.manager;
 if(path==='/api/v1/reports/performance/options'){
  const kind=url.searchParams.get('kind')??'',owner=url.searchParams.get('owner')||u.sub,q=(url.searchParams.get('q')??'').trim().slice(0,120);
  if(!['employee','province','customer','product'].includes(kind))return invalid('Loại bộ lọc không hợp lệ');
  if(kind==='employee'){
   const rows=await sql`SELECT user_sub AS id,employee_code AS code,full_name AS name
     FROM staff_members WHERE active AND public.sales_can_access(${u.sub},user_sub,NULL,NULL)
     AND (employee_code ILIKE '%'||${q}||'%' OR full_name ILIKE '%'||${q}||'%') ORDER BY full_name LIMIT 200`;
   return reply({items:rows,can_view_team:manager});
  }
  if(kind==='province'){
   const rows=await sql`SELECT DISTINCT c.province AS id,c.province AS name,'' AS code FROM customers c
     WHERE public.sales_can_access(${u.sub},c.owner_sub,c.province,c.district)
     AND (${owner==='all'&&manager} OR c.owner_sub=${owner}) AND c.province ILIKE '%'||${q}||'%'
     ORDER BY name LIMIT 100`;
   return reply({items:rows});
  }
  if(kind==='customer'){
   if(owner==='all'&&!manager)return invalid('Không có quyền toàn đội',403);
   const rows=await sql`SELECT c.id::text AS id,c.code, c.name FROM customers c
     WHERE public.sales_can_access(${u.sub},c.owner_sub,c.province,c.district)
     AND (${owner==='all'&&manager} OR c.owner_sub=${owner})
     AND (c.name ILIKE '%'||${q}||'%' OR c.code ILIKE '%'||${q}||'%')
     ORDER BY name LIMIT 100`;
   return reply({items:rows});
  }
  const rows=await sql`SELECT id::text AS id,company_code AS code,name FROM catalog_products
     WHERE active AND (name ILIKE '%'||${q}||'%' OR company_code ILIKE '%'||${q}||'%')
     ORDER BY company_code LIMIT 100`;
  return reply({items:rows});
 }
 const action=path==='/api/v1/reports/performance'?'overview':
  path==='/api/v1/reports/performance/detail'?'detail':
  path==='/api/v1/reports/performance/export'?'export':'';
 if(!action)return invalid('Không tìm thấy endpoint',404);
 const f=parse(url,u.sub,manager);if(!f)return invalid('Kỳ, nhóm hoặc bộ lọc không hợp lệ');
 const forbidden=await validateScope(sql,u,f);if(forbidden)return invalid(forbidden,403);
 const start=f.startMonth,end=f.endMonth,year=f.year,owner=f.owner,province=f.province,customer=f.customer,product=f.product,group=f.group;
 const mode=reportTargetMode(f);
 if(action==='detail'||action==='export'){
  const key=action==='detail'?(url.searchParams.get('key')??''):'';
  const offset=action==='detail'?Number(url.searchParams.get('offset')??'0'):0;
  if(action==='detail'&&(key.length>150||!Number.isInteger(offset)||offset<0||offset>9900))return invalid('Trang hoặc mã nhóm không hợp lệ');
  const limit=action==='export'?10001:101;
  const rows=await sql`SELECT a.id::text AS id,to_char(a.sale_date,'YYYY-MM-DD') AS sale_date,
     s.employee_code,s.full_name AS employee_name,c.code AS customer_code,c.name AS customer_name,
     c.province,c.district,p.company_code,p.name AS product_name,
     a.quantity,a.amount::text AS amount,a.source,a.external_ref,a.line_ref
   FROM sales_actuals a JOIN customers c ON c.id=a.customer_id AND c.owner_sub=a.owner_sub
   JOIN staff_members s ON s.user_sub=a.owner_sub JOIN catalog_products p ON p.id=a.product_id
   WHERE a.status='active' AND a.sale_date>=make_date(${year},${start},1) AND a.sale_date<make_date(${year},${end},1)
     AND (${owner==='all'&&manager} OR a.owner_sub=${owner})
     AND (${!province} OR c.province=${province})
     AND (${!customer} OR a.customer_id::text=${customer}) AND (${!product} OR a.product_id::text=${product})
     AND public.sales_can_access(${u.sub},a.owner_sub,c.province,c.district)
     AND (${!key} OR CASE
        WHEN ${group}='employee' THEN a.owner_sub
        WHEN ${group}='province' THEN c.province
        WHEN ${group}='customer' THEN a.customer_id::text
        WHEN ${group}='product' THEN a.product_id::text
        ELSE to_char(a.sale_date,'YYYY-MM') END=${key})
   ORDER BY a.sale_date DESC,a.id LIMIT ${limit} OFFSET ${offset}`;
  if(action==='export'){
   if(rows.length>10000)return invalid('Hơn 10.000 dòng. Chọn kỳ ngắn hơn trước khi xuất Excel.',413);
   return reply({items:rows,exact:true,limit:10000,filters:f});
  }
  return reply({items:rows.slice(0,100),has_more:rows.length>100,offset});
 }
 const [actuals,summary,targetRows]=await Promise.all([
  sql`SELECT CASE WHEN ${group}='employee' THEN a.owner_sub
      WHEN ${group}='province' THEN c.province
      WHEN ${group}='customer' THEN a.customer_id::text
      WHEN ${group}='product' THEN a.product_id::text
      ELSE to_char(a.sale_date,'YYYY-MM') END AS id,
      MAX(CASE WHEN ${group}='employee' THEN s.full_name
      WHEN ${group}='province' THEN c.province
      WHEN ${group}='customer' THEN c.name WHEN ${group}='product' THEN p.name
      ELSE to_char(a.sale_date,'YYYY-MM') END) AS label,
      MAX(CASE WHEN ${group}='employee' THEN s.employee_code
      WHEN ${group}='customer' THEN c.code WHEN ${group}='product' THEN p.company_code ELSE '' END) AS code,
      sum(a.amount)::text AS amount,sum(a.quantity)::text AS quantity,count(*)::int AS records
    FROM sales_actuals a JOIN customers c ON c.id=a.customer_id AND c.owner_sub=a.owner_sub
    JOIN staff_members s ON s.user_sub=a.owner_sub JOIN catalog_products p ON p.id=a.product_id
    WHERE a.status='active' AND a.sale_date>=make_date(${year},${start},1) AND a.sale_date<make_date(${year},${end},1)
      AND (${owner==='all'&&manager} OR a.owner_sub=${owner})
      AND (${!province} OR c.province=${province}) AND (${!customer} OR a.customer_id::text=${customer})
      AND (${!product} OR a.product_id::text=${product})
      AND public.sales_can_access(${u.sub},a.owner_sub,c.province,c.district)
    GROUP BY 1 ORDER BY 1 LIMIT 2001`,
  sql`SELECT coalesce(sum(a.amount),0)::text AS amount,count(*)::int AS records,coalesce(sum(a.quantity),0)::text AS quantity
    FROM sales_actuals a JOIN customers c ON c.id=a.customer_id AND c.owner_sub=a.owner_sub
    WHERE a.status='active' AND a.sale_date>=make_date(${year},${start},1) AND a.sale_date<make_date(${year},${end},1)
      AND (${owner==='all'&&manager} OR a.owner_sub=${owner})
      AND (${!province} OR c.province=${province}) AND (${!customer} OR a.customer_id::text=${customer})
      AND (${!product} OR a.product_id::text=${product})
      AND public.sales_can_access(${u.sub},a.owner_sub,c.province,c.district)`,
  mode==='none'?Promise.resolve([]):sql`SELECT t.owner_sub,t.entity_id,to_char(t.month,'YYYY-MM') AS month,t.amount::text AS amount,
      s.full_name AS employee_name,s.employee_code,
      c.province,c.code AS customer_code,c.name AS customer_name,p.company_code,p.name AS product_name
     FROM sales_targets t JOIN staff_members s ON s.user_sub=t.owner_sub
     LEFT JOIN customers c ON t.dimension='customer' AND c.id::text=t.entity_id AND c.owner_sub=t.owner_sub
     LEFT JOIN catalog_products p ON t.dimension='product' AND p.id::text=t.entity_id
     WHERE t.dimension=${mode} AND t.month>=make_date(${year},${start},1) AND t.month<make_date(${year},${end},1)
       AND (${owner==='all'&&manager} OR t.owner_sub=${owner})
       AND public.sales_can_access(${u.sub},t.owner_sub,NULL,NULL)
       AND (${mode!=='customer'} OR (c.id IS NOT NULL AND public.sales_can_access(${u.sub},t.owner_sub,c.province,c.district)))
       AND (${mode!=='customer'||!customer} OR t.entity_id=${customer})
       AND (${mode!=='customer'||!province} OR c.province=${province})
       AND (${mode!=='product'||!product} OR t.entity_id=${product})
       AND (${mode==='customer'} OR ${u.admin} OR t.owner_sub=${u.sub} OR NOT EXISTS(
          SELECT 1 FROM staff_scopes sc WHERE sc.user_sub=t.owner_sub
          AND NOT public.sales_can_access(${u.sub},t.owner_sub,sc.province,sc.district)))
     ORDER BY t.owner_sub,t.month,t.entity_id`
 ]);
 if(actuals.length>2000)return invalid('Có trên 2.000 nhóm, hãy thu hẹp bộ lọc.',413);
 const rows=aggregateRows(actuals,targetRows as Record<string,unknown>[],group,mode);
 const amount=BigInt(String(summary[0]?.amount??'0')),records=Number(summary[0]?.records??0);
 const target=mode==='none'?null:(targetRows as Record<string,unknown>[]).reduce((sum,t)=>sum+BigInt(String(t.amount)),0n);
 return reply({filters:f,target_dimension:mode,can_view_team:manager,
   metric:{...reportMetric(target,amount,records),quantity:String(summary[0]?.quantity??'0')},
   rows,group,has_data:rows.length>0,limit:2000,
   target_note:mode==='none'?'Không có Target so sánh phù hợp với tổ hợp bộ lọc.':mode==='employee'?'Target tổng của nhân viên; không cộng phân bổ khách/SKU.':mode==='customer'?'Target phân bổ khách hàng (không phải tổng Target nhân viên).':'Target phân bổ SKU (không phải tổng Target nhân viên).'});
}
