import test from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
const text=await readFile(new URL('../migrations/234_notification_n3_digest_recovery.sql',import.meta.url),'utf8');
test('N3 stops route reminders after the route session is done',()=>{
 assert.match(text,/r.route_date=c.d AND r.status='ready' AND p.status='planned'[\s\S]*?w.day_route_id=r.id AND w.state='done'/);
 assert.match(text,/t.closed_at IS NULL/);
});
test('N3 expired digest messages go dead; abandoned lease returns pending, not duplicate push',()=>{
 assert.match(text,/mode='digest' AND expires_at<=now\(\)/);
 assert.match(text,/mode='digest' AND expires_at>now\(\) AND state='processing'/);
 assert.match(text,/lease_until<now\(\)/);
 assert.match(text,/RETURN public.sales_n3_run_at\(now\(\)\)/);
});
