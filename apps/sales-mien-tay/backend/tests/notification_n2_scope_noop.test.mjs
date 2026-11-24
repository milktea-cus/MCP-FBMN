import test from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
test('N2 repeated org saves never change scope_revision or create audit triggers',async()=>{
 const s=await readFile(new URL('../migrations/231_notification_scope_noop_revision.sql',import.meta.url),'utf8');
 for(const name of ['sales_set_staff_territories','sales_set_staff_business_assignment','sales_set_scope_grant','sales_set_customer_binding'])
  assert.match(s,new RegExp('CREATE OR REPLACE FUNCTION public\\.'+name+'\\('));
 assert.match(s,/previous IS NOT DISTINCT FROM \(/);
 assert.equal((s.match(/previous->>'active' IS NOT DISTINCT FROM p_active::text/g)||[]).length,3);
 assert.match(s,/RETURN jsonb_build_object\('scopes',previous/);
});
