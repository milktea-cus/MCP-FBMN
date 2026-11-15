import {neon} from '@neondatabase/serverless';

/** Authenticated read-only school directory. Historical province/district
 * names are preserved for Field Work territory filters. */
type Actor={sub:string;admin:boolean;manager:boolean};
type Env={DATABASE_URL:string};
const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{
  status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'private, no-store'}
});
const invalid=(error:string,status=400)=>reply({error},status);

function pageNumber(value:string|null,defaultValue:number,max:number):number|null{
 if(value===null)return defaultValue;
 if(!/^[1-9][0-9]*$/.test(value))return null;
 const n=Number(value);
 return Number.isSafeInteger(n)&&n<=max?n:null;
}

/** Only assigned territory (self/subtree) or an already-viewable customer's
 * district grants access. Chain-only managers do not gain all provinces. */
export async function schoolRoutes(req:Request,env:Env,actor:Actor,url:URL):Promise<Response|null>{
 if(url.pathname!=='/api/v1/schools'&&url.pathname!=='/api/v1/schools/areas')return null;
 if(req.method!=='GET')return invalid('Method not allowed',405);
 const db=neon(env.DATABASE_URL);
 if(url.pathname.endsWith('/areas')){
  const areas=await db`
   SELECT s.province_old AS province,
      jsonb_agg(DISTINCT s.district_old ORDER BY s.district_old) AS districts
   FROM public.schools s
   WHERE (${actor.admin}
    OR EXISTS(SELECT 1 FROM public.staff_scopes ss
       JOIN public.staff_members m ON m.user_sub=ss.user_sub AND m.active
       WHERE ss.province=s.province_old
         AND (ss.district='' OR ss.district=s.district_old)
         AND (ss.user_sub=${actor.sub}
              OR (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},ss.user_sub))))
    OR EXISTS(SELECT 1 FROM public.customers c
       WHERE c.province=s.province_old AND c.district=s.district_old
         AND public.sales_customer_allowed(${actor.sub},c.id,'view'))
   )
   GROUP BY s.province_old ORDER BY s.province_old`;
  return reply({items:areas});
 }
 const province=(url.searchParams.get('province')??'').trim();
 const district=(url.searchParams.get('district')??'').trim();
 const search=(url.searchParams.get('q')??'').trim();
 const page=pageNumber(url.searchParams.get('page'),1,500);
 const size=pageNumber(url.searchParams.get('size'),20,50);
 if(province.length>120||district.length>120||search.length>100||
   !page||!size||(district!==''&&province===''))
  return invalid('Bộ lọc hoặc phân trang không hợp lệ');
 const result=await db`
   WITH visible AS (
    SELECT s.id,s.source_ref,s.name,s.education_level,
      s.province_old,s.district_old,s.ward_old,s.address_text,
      s.maps_search_url,s.latitude,s.longitude,s.gps_verified
    FROM public.schools s
    WHERE (${province}='' OR s.province_old=${province})
      AND (${district}='' OR s.district_old=${district})
      AND (${search}='' OR position(lower(${search}) in lower(s.name))>0)
      AND (
       ${actor.admin}
       OR EXISTS(SELECT 1 FROM public.staff_scopes ss
         JOIN public.staff_members m ON m.user_sub=ss.user_sub AND m.active
         WHERE ss.province=s.province_old
          AND (ss.district='' OR ss.district=s.district_old)
          AND (ss.user_sub=${actor.sub}
            OR (${actor.manager} AND public.sales_staff_in_subtree(${actor.sub},ss.user_sub))))
       OR EXISTS(SELECT 1 FROM public.customers c
          WHERE c.province=s.province_old AND c.district=s.district_old
            AND public.sales_customer_allowed(${actor.sub},c.id,'view'))
      )
   )
   SELECT (SELECT count(*)::int FROM visible) AS total,
     coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM (
       SELECT * FROM visible ORDER BY province_old,district_old,name,source_ref
       LIMIT ${size} OFFSET ${(page-1)*size}
     ) p),'[]'::jsonb) AS items`;
 const total=Number(result[0]?.total??0);
 return reply({items:result[0]?.items??[],total,page,size,
    hasMore:page*size<total});
}
