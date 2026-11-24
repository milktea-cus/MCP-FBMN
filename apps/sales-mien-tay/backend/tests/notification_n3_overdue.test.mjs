import test from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
test('N3 overdue tasks remain visible regardless of age until explicit completion',async()=>{
 const s=await readFile(new URL('../migrations/235_notification_n3_unfinished_tasks.sql',import.meta.url),'utf8');
 assert.match(s,/r.route_date<c.d/);
 assert.match(s,/t.end_date<=c.d\+1/);
 assert.match(s,/w.day_route_id=r.id AND w.state='done'/);
 assert.match(s,/t.closed_at IS NULL/);
 assert.doesNotMatch(s,/BETWEEN c.d-7 AND c.d/);
});
