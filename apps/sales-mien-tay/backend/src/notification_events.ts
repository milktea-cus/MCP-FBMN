import {neon} from '@neondatabase/serverless';
export type NotificationCategory=
 'target'|'actuals'|'monthly_plan'|'day_route'|'weekly_route'|'monthly_route'|'trip'|
 'survey'|'customer'|'assignment'|'prospect'|'school'|'support'|'competitor'|
 'order_action'|'order_summary'|'catalog'|'inventory'|'email'|'security'|'sync'|'release';
export type BusinessNotice={eventKey:string;category:NotificationCategory;entityKey:string;
 actor:string;recipient:string;title:string;body:string;occurredAt?:Date};
export function safeNotice(n:BusinessNotice):boolean {
 return n.actor!==n.recipient&&!!n.actor&&!!n.recipient&&!!n.entityKey&&
  n.entityKey.length<=160&&!!n.eventKey&&n.eventKey.length<=160&&
  !!n.title&&n.title.length<=160&&!!n.body&&n.body.length<=500&&
  !/[\x00-\x1f]/.test(n.title+n.body);
}
// Only call this AFTER the business mutation's verified commit, or from within
// the same trusted SQL transaction/RPC for strong transactional outbox semantics.
// N1 categories are OFF in DB; N2 must wire mutation-RPC transactional boundaries.
export async function enqueueBusinessNotice(env:{DATABASE_URL:string},notice:BusinessNotice):Promise<string|null> {
 if(!safeNotice(notice))return null;
 const sql=neon(env.DATABASE_URL);
 const [row]=await sql`SELECT public.sales_notification_enqueue(${notice.eventKey},${notice.category},
  ${notice.entityKey},${notice.actor},${notice.recipient},${notice.title},${notice.body},
  ${notice.occurredAt??new Date()})::text AS id`;
 return row?.id??null;
}
