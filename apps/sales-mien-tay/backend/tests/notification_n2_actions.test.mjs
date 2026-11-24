import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const migration=await readFile(new URL('../migrations/228_notification_action_producers.sql',import.meta.url),'utf8');
test('N2 action notifications occur on immutable audited mutation boundaries',()=>{
 for(const [table,trigger] of [
  ['sales_target_mutations','trg_n2_target_notification'],
  ['staff_permission_events','trg_n2_staff_notification'],
  ['sales_scoped_record_audit','trg_n2_support_notification'],
  ['field_order_ops','trg_n2_order_notification']]){
  assert.match(migration,new RegExp('CREATE TRIGGER '+trigger+' AFTER INSERT ON public\\.'+table));
 }
 assert.match(migration,/b\.item->>'amount'\) IS DISTINCT FROM/);
 assert.match(migration,/old_staff->>'role'/);
 assert.match(migration,/NEW\.before_state->'data'->>'status'/);
 assert.match(migration,/NEW\.before_data->>'status' NOT IN \('exported','imported'\)/);
});
test('N2 no duplicate legacy target publishing and no guessed self-plan assignee',async()=>{
 const target=await readFile(new URL('../src/targets.ts',import.meta.url),'utf8');
 assert.doesNotMatch(target,/publishNotification/);
 assert.match(migration,/Plans\/trips remain self-owned/);
 assert.doesNotMatch(migration,/UPDATE public\.field_notification_categories SET producer_enabled/);
});
test('N2 resolver remains fail-closed, validates support owner and order customer',()=>{
 assert.match(migration,/p_category='support'/);
 assert.match(migration,/r\.kind='support' AND r\.id::text=p_entity_key AND r\.owner_sub=p_recipient/);
 assert.match(migration,/public\.sales_can_access\(p_actor,o\.owner_sub,c\.province,c\.district\)/);
 assert.match(migration,/public\.sales_can_access\(p_recipient,o\.owner_sub,c\.province,c\.district\)/);
 assert.match(migration,/IF p_category='target' THEN/);
});
