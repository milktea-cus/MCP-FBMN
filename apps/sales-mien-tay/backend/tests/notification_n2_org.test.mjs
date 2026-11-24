import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const s=await readFile(new URL('../migrations/229_notification_org_scope_actions.sql',import.meta.url),'utf8');
test('real org assignment, grant, customer staff binding and team changes are audited',()=>{
 assert.match(s,/CREATE TRIGGER trg_n2_org_notification AFTER INSERT ON public\.scope_change_audit/);
 for(const category of ['grant','business_assignment','team_member','customer_binding'])
  assert.ok(s.includes("'"+category+"'"));
 assert.match(s,/scope_kind'<>'staff'/);
 assert.match(s,/after_active NOT IN \('true','false'\)/);
 assert.match(s,/before_active IS NOT DISTINCT FROM after_active/);
 assert.match(s,/before_active IS NULL AND after_active='false'/);
});
test('direct territory changes notify by real staff audit, not raw scope edits',()=>{
 assert.match(s,/assign_territories/);
 assert.match(s,/kind:='assignment'/);
 assert.match(s,/NEW\.before_state,'\[\]'::jsonb/);
 assert.doesNotMatch(s,/AFTER (INSERT|UPDATE) ON public\.staff_scopes/);
});
test('org notification never broadcasts customer, team or chain details',()=>{
 assert.match(s,/'staff:'\|\|recipient/);
 assert.doesNotMatch(s,/customer\.name|customers\.name|r\.data->>'title'/);
});
