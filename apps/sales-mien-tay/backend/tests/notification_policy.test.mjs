import test from 'node:test';
import assert from 'node:assert/strict';
import {quietUntil,validMinute,validMode,effectiveMode,pageSize,validCursor,transientPushError} from '../src/notification_policy.ts';
test('Vietnam quiet hours cross midnight and end exactly at 07:00',()=>{
 for(const x of ['2026-11-24T14:00:00Z','2026-11-24T23:59:59Z'])
  assert.equal(quietUntil(new Date(x)).toISOString(),'2026-11-25T00:00:00.000Z');
 for(const x of ['2026-11-24T13:59:59Z','2026-11-25T00:00:00Z'])
  assert.equal(quietUntil(new Date(x)).getTime(),Date.parse(x));
 assert.equal(quietUntil(new Date('2026-12-31T16:00:00Z')).toISOString(),'2027-01-01T00:00:00.000Z');
});
test('same-day quiet hours and disabled equal boundaries',()=>{
 const x=new Date('2026-11-24T05:00:00Z');
 assert.equal(quietUntil(x,600,780).toISOString(),'2026-11-24T06:00:00.000Z');
 assert.equal(quietUntil(x,600,600),x);
 for(const n of [-1,1440,1.2,'420',null])assert.equal(validMinute(n),false);
});
test('mandatory events cannot be disabled; pagination bounds bigint safely',()=>{
 assert.equal(effectiveMode('off',true),'in_app');
 assert.equal(effectiveMode('off',false),'off');
 assert.equal(validMode('invalid'),false);
 assert.equal(pageSize(null),60);assert.equal(pageSize('100'),100);
 for(const x of ['0','101','1e2','-1',''])assert.equal(pageSize(x),null);
 assert.equal(validCursor('9223372036854775807'),true);
 for(const x of ['9223372036854775808','0','1e5','-1'])assert.equal(validCursor(x),false);
});
test('retry only transient provider failures',()=>{
 for(const x of ['network_error','oauth_network_failed','QUOTA_EXCEEDED','http_429','http_503','oauth_http_500'])assert.equal(transientPushError(x),true);
 for(const x of ['oauth_invalid_signature','oauth_redirect_blocked','UNREGISTERED','http_400','http_401','SENDER_ID_MISMATCH'])assert.equal(transientPushError(x),false);
});
