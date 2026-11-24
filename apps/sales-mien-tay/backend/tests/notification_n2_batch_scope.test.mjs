import test from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
test('N2 groups only generic permission alerts across scope revision, refreshes pending leases',async()=>{
 const s=await readFile(new URL('../migrations/230_notification_permission_batch_scope.sql',import.meta.url),'utf8');
 assert.match(s,/scope_revision=v_recipient.scope_revision OR p_category IN \('assignment','security'\)/);
 assert.match(s,/read_at=NULL,scope_revision=CASE WHEN/);
 assert.match(s,/available_at=greatest\(o.available_at,v_available\)/);
 assert.match(s,/d.state='accepted'/);
 const worker=await readFile(new URL('../src/notification_dispatch.ts',import.meta.url),'utf8');
 assert.match(worker,/b.scope_revision AS queued_revision/);
 assert.match(worker,/b.available_at<=now\(\) AS due/);
 assert.match(worker,/if\(!scope.due\)/);
});
