import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';

const source=readFileSync(new URL('../src/customers.ts',import.meta.url),'utf8');
const migration=readFileSync(new URL('../migrations/220_route_customer_auto_promote_prospect_2026.sql',import.meta.url),'utf8');

test('normal route and offline queue customer POST share atomic prospect reconciliation',()=>{
  assert.match(source,/sales_customer_create_reconcile_prospect\(/);
  assert.match(source,/JSON\.stringify\(payload\)/);
  assert.match(source,/converted_from_prospect/);
  assert.match(source,/reused_existing/);
  assert.doesNotMatch(source,/INSERT INTO customers\(client_ref,owner_sub,created_by_sub,name/);
});

test('database checks scope, identity, serializes and audits promotion',()=>{
  assert.match(migration,/sales_can_access\(p_actor,p_actor,v_province,v_district\)/);
  assert.match(migration,/sales_market_prospect_allowed\(p_actor,p\.id\)/);
  assert.match(migration,/pg_advisory_xact_lock/);
  assert.match(migration,/ON CONFLICT\(owner_sub,client_ref\) DO NOTHING/);
  assert.match(migration,/p\.status IN \('new','converted'\)/);
  assert.match(migration,/status='converted',converted_customer_id=saved\.id/);
  assert.match(migration,/field_prospect_events/);
  assert.match(migration,/field_market_prospect_audit/);
  assert.match(migration,/sales_customer_allowed\(p_actor,id,'view'\)/);
  assert.doesNotMatch(migration,/INSERT INTO public\.field_prospect_visits/);
  assert.doesNotMatch(migration,/UPDATE public\.customers SET latitude/);
});
