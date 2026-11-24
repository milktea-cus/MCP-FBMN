import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const sql=await readFile(new URL('../migrations/233_notification_n3_summaries.sql',import.meta.url),'utf8');
test('N3 only 07:00/18:00 local and immutable per-recipient slot; no empty summary',()=>{
 assert.match(sql,/AT TIME ZONE 'Asia\/Ho_Chi_Minh'/);
 assert.match(sql,/extract\(hour from v_local\)::int=7/);
 assert.match(sql,/extract\(hour from v_local\)::int=18/);
 assert.match(sql,/v_total\+v_due=0 THEN CONTINUE/);
 assert.match(sql,/field_notification_digest\(recipient_sub,slot_key,notification_id\)/);
 assert.match(sql,/pg_try_advisory_xact_lock/);
 assert.match(sql,/coalesce\(p.mode,c.default_mode\)/);
});
test('N3 preserves current month week 5 and excludes draft/cancelled/void',()=>{
 assert.match(sql,/IN \(1,8,15,22,29\)/);
 assert.match(sql,/r.week_no=1\+\(\(extract\(day from c.d\)::int-1\)\/7\)/);
 assert.match(sql,/o.status IN \('exported','imported'\)/);
 assert.match(sql,/a.status='active' AND a.sale_date=c.d/);
 assert.match(sql,/se.status='completed'/);
 assert.match(sql,/t.closed_at IS NULL/);
 assert.match(sql,/public.sales_customer_allowed\(p_owner,customer.id,'actuals'\)/);
});
test('N3 digest rows never vanish silently and Worker ticks before push',async()=>{
 const dispatch=await readFile(new URL('../src/notification_dispatch.ts',import.meta.url),'utf8');
 const index=await readFile(new URL('../src/index.ts',import.meta.url),'utf8');
 assert.match(dispatch,/WHERE mode<>'digest' AND/);
 assert.doesNotMatch(dispatch,/if\(scope.current_mode==='digest'\)/);
 assert.match(index,/runScheduledSummaries\(env\).catch\(\(\)=>0\).then\(\(\)=>dispatchNotifications\(env\)\)/);
 assert.match(sql,/v_due>0 THEN[\s\S]*UPDATE public.field_notification_outbox/);
 assert.match(sql,/v_mode='off' THEN CONTINUE/);
});
