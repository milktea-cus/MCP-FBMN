/** Canonical selections shared by weekly and monthly local templates. */
export type LocalScope={
 scope_kind:'territory'|'customer'|'chain';
 scope_key:string;
 province:string|null;
 district:string|null;
 label:string;
};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function normalizeLocalScopes(input:unknown):LocalScope[]|null{
 if(!Array.isArray(input)||input.length<1||input.length>50)return null;
 const seen=new Set<string>(),out:LocalScope[]=[];
 for(const val of input){
  if(!val||typeof val!=='object'||Array.isArray(val))return null;
  const o=val as Record<string,unknown>,kind=o.scope_kind,key=o.scope_key,
   label=o.label;
  if(!['territory','customer','chain'].includes(String(kind))||
   typeof key!=='string'||key.length<1||key.length>240||
   typeof label!=='string'||label.trim().length<1||label.length>240)return null;
  let province:string|null=null,district:string|null=null;
  if(kind==='territory'){
   if(typeof o.province!=='string'||o.province.trim().length<1||
    o.province.length>120||typeof o.district!=='string'||o.district.length>120||
    o.province.includes('|')||o.district.includes('|')||
    key!==o.province+'|'+o.district)return null;
   province=o.province;district=o.district;
  }else if(!uuid.test(key)||o.province!=null||o.district!=null)return null;
  const fingerprint=String(kind)+':'+key;
  if(seen.has(fingerprint))return null;
  seen.add(fingerprint);
  out.push({scope_kind:kind as LocalScope['scope_kind'],
   scope_key:key,province,district,label:label.trim()});
 }
 return out;
}
export function legacyWeeklyScope(v:Record<string,unknown>):LocalScope[]|null{
 if(typeof v.province!=='string'||!v.province.trim()||
  typeof v.district!=='string')return null;
 return normalizeLocalScopes([{
  scope_kind:'territory',scope_key:v.province+'|'+v.district,
  province:v.province,district:v.district,
  label:v.district?String(v.district)+' · '+v.province:'Toàn tỉnh · '+v.province,
 }]);
}
export function legacyMonthlyScope(v:Record<string,unknown>):LocalScope[]|null{
 return normalizeLocalScopes([{
  scope_kind:v.scope_kind,scope_key:v.scope_key,
  province:v.province??null,district:v.district??null,
  label:v.scope_label,
 }]);
}
