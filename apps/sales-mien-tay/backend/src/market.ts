import {neon} from '@neondatabase/serverless';

type Actor={sub:string;admin:boolean;manager:boolean};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const response=(v:unknown,status=200)=>new Response(JSON.stringify(v),{
 status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'},
});
const bad=(error:string,status=400)=>response({error},status);

/** Market footprint derives ONLY from surveyed customer/brand sightings.
 * Each customer-brand is unique and scoped; SKU/order/assortment data is
 * intentionally never joined into these statistics. */
export async function marketRoutes(
 req:Request,env:{DATABASE_URL:string},actor:Actor,url:URL,
):Promise<Response|null>{
 const path=url.pathname;
 if(!path.startsWith('/api/v1/market/'))return null;
 if(req.method!=='GET')return bad('Phương thức không được hỗ trợ',405);
 const db=neon(env.DATABASE_URL);
 if(path==='/api/v1/market/brands'){
  // Brand vocabulary can be shared among sales, but counts only include
  // customers the actor may view. Never expose other-region customer names.
  const items=await db`SELECT b.id::text AS id,b.name,
    count(DISTINCT c.id)::integer AS customers
   FROM public.market_brands b
   LEFT JOIN public.market_customer_brands m
     ON m.brand_id=b.id AND m.present
   LEFT JOIN public.customers c
     ON c.id=m.customer_id
    AND public.sales_customer_allowed(${actor.sub},c.id,'view')
   GROUP BY b.id,b.name ORDER BY b.name LIMIT 500`;
  return response({items,semantics:'Nhãn quan sát tại điểm bán, độc lập SKU Futurebook'});
 }
 if(path==='/api/v1/market/coverage'){
  const province=(url.searchParams.get('province')??'').trim();
  const district=(url.searchParams.get('district')??'').trim();
  if(province.length>120||district.length>120)return bad('Địa bàn không hợp lệ');
  const [items,totals]=await Promise.all([
   db`SELECT c.province,c.district,b.id::text AS brand_id,b.name AS brand,
     count(DISTINCT c.id)::integer AS customers,
     max(m.last_seen_at) AS last_seen_at
    FROM public.market_customer_brands m
    JOIN public.market_brands b ON b.id=m.brand_id
    JOIN public.customers c ON c.id=m.customer_id
    WHERE m.present
     AND public.sales_customer_allowed(${actor.sub},c.id,'view')
     AND (${province}='' OR c.province=${province})
     AND (${district}='' OR c.district=${district})
    GROUP BY c.province,c.district,b.id,b.name
    ORDER BY c.province,c.district,b.name LIMIT 10000`,
   db`SELECT c.province,c.district,count(*)::integer AS customers
    FROM public.customers c
    WHERE public.sales_customer_allowed(${actor.sub},c.id,'view')
     AND (${province}='' OR c.province=${province})
     AND (${district}='' OR c.district=${district})
    GROUP BY c.province,c.district ORDER BY c.province,c.district LIMIT 2000`,
  ]);
  return response({items,customers:totals,
   semantics:'Mỗi khách–nhãn chỉ tính một lần tại địa bàn hiện tại. Khảo sát lại cập nhật lần thấy gần nhất, không cộng lượt.'});
 }
 if(path==='/api/v1/market/customers'){
  const brandId=(url.searchParams.get('brand_id')??'').trim();
  const customerId=(url.searchParams.get('customer_id')??'').trim();
  const province=(url.searchParams.get('province')??'').trim();
  const district=(url.searchParams.get('district')??'').trim();
  const q=(url.searchParams.get('q')??'').trim();
  const limit=Number(url.searchParams.get('limit')??'100');
  if(brandId&&!uuid.test(brandId)||customerId&&!uuid.test(customerId)||
     q.length>120||province.length>120||district.length>120||
     !Number.isInteger(limit)||limit<1||limit>200)
   return bad('Bộ lọc tìm kiếm nhãn hàng không hợp lệ');
  const rows=await db`SELECT c.id::text AS customer_id,c.name AS customer_name,
    c.field_code,c.province,c.district,b.id::text AS brand_id,b.name AS brand,
    m.first_seen_at,m.last_seen_at,m.last_session_id::text AS last_session_id
   FROM public.market_customer_brands m
   JOIN public.market_brands b ON b.id=m.brand_id
   JOIN public.customers c ON c.id=m.customer_id
   WHERE m.present AND public.sales_customer_allowed(${actor.sub},c.id,'view')
    AND (${brandId}='' OR m.brand_id::text=${brandId})
    AND (${customerId}='' OR c.id::text=${customerId})
    AND (${province}='' OR c.province=${province})
    AND (${district}='' OR c.district=${district})
    AND (${q}='' OR c.name ILIKE '%'||${q}||'%'
      OR coalesce(c.field_code,'') ILIKE '%'||${q}||'%'
      OR b.name ILIKE '%'||${q}||'%')
   ORDER BY c.province,c.district,c.name,b.name LIMIT ${limit+1}`;
  return response({items:rows.slice(0,limit),truncated:rows.length>limit});
 }
 return bad('Endpoint không tồn tại',404);
}
