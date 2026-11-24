import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {quietUntil,validMode,effectiveMode,validMinute,pageSize,validCursor,transientPushError,deviceDigest} from '../src/notification_policy.ts';
import {safeNotice} from '../src/notification_events.ts';

// N5 executable, deterministic policy checks; physical FCM/lock-screen receipt
// and authenticated multi-account UAT remain separate release gates.
test('N5 Vietnam quiet hours cross midnight without delaying 07:00 work',()=>{
 const samples=[
  ['2026-11-24T13:59:00Z','2026-11-24T13:59:00Z'],
  ['2026-11-24T14:00:00Z','2026-11-25T00:00:00Z'],
  ['2026-11-24T16:59:00Z','2026-11-25T00:00:00Z'],
  ['2026-11-24T23:59:00Z','2026-11-25T00:00:00Z'],
  ['2026-11-25T00:00:00Z','2026-11-25T00:00:00Z']
 ];
 for(const [input,expected] of samples)
  assert.equal(quietUntil(new Date(input)).toISOString(),new Date(expected).toISOString(),input);
 assert.equal(quietUntil(new Date('2026-11-24T06:30:00Z'),780,840).toISOString(),'2026-11-24T07:00:00.000Z');
 assert.equal(quietUntil(new Date('2026-11-24T14:20:00Z'),1260,1260).toISOString(),'2026-11-24T14:20:00.000Z');
 for(const x of [-1,1440,NaN,360.5,'420'])assert.equal(validMinute(x),false);
});
test('N5 mandatory security inbox cannot be silenced and cursors are bounded',()=>{
 for(const mode of ['immediate','digest','in_app','off'])assert.equal(validMode(mode),true);
 for(const mode of ['',null,'silent','push'])assert.equal(validMode(mode),false);
 assert.equal(effectiveMode('off',true),'in_app');
 assert.equal(effectiveMode('off',false),'off');
 assert.equal(pageSize(null),60);assert.equal(pageSize('100'),100);
 for(const x of ['0','101','01','-1','999999999999'])assert.equal(pageSize(x),null);
 assert.equal(validCursor('9223372036854775807'),true);
 for(const x of ['9223372036854775808','0','01','-2','1;DROP TABLE',''])assert.equal(validCursor(x),false);
});
test('N5 retry only transient failures; no retry storms on invalid credentials',()=>{
 for(const code of ['network_error','oauth_network_failed','http_429','http_502','oauth_http_503','QUOTA_EXCEEDED'])
  assert.equal(transientPushError(code),true,code);
 for(const code of ['oauth_invalid_grant','oauth_config_invalid','oauth_redirect_blocked','fcm_redirect_blocked',
  'SENDER_ID_MISMATCH','UNREGISTERED','http_401','http_403','not_configured'])
  assert.equal(transientPushError(code),false,code);
});
test('N5 same event replay/self notification is not a second business event',()=>{
 const n={eventKey:'target:batch:offline-client-1',category:'target',entityKey:'target-1',
  actor:'manager-1',recipient:'sales-1',title:'Có công việc mới',body:'Mở ứng dụng để xem'};
 assert.equal(safeNotice(n),true);
 assert.equal(safeNotice({...n,actor:'sales-1'}),false);
 assert.equal(safeNotice({...n,recipient:''}),false);
 assert.equal(safeNotice({...n,eventKey:'x'.repeat(161)}),false);
 assert.equal(safeNotice({...n,body:'x'.repeat(501)}),false);
 assert.equal(safeNotice({...n,title:'Việc\nkhác'}),false);
});
test('N5 provider device fingerprint never contains the original capability',async()=>{
 const token='owner-device-opaque-string';
 const digest=await deviceDigest(token);
 assert.match(digest,/^[a-f0-9]{64}$/);
 assert.equal(digest,await deviceDigest(token));
 assert.notEqual(digest,await deviceDigest('other-account-device'));
 assert.equal(digest.includes(token),false);
});
test('N5 Android screen is generic, requires matching binding and OS permission',async()=>{
 const dir=new URL('../../apps/sales_flutter/android/app/src/main/kotlin/com/example/sales_mien_tay/',import.meta.url);
 const native=await readFile(new URL('FieldMessagingService.kt',dir),'utf8');
 const fcm=await readFile(new URL('../src/fcm.ts',import.meta.url),'utf8');
 assert.match(native,/message\.data\["binding"\] != binding/);
 assert.match(native,/message\.data\["kind"\] != "field_notification"/);
 assert.match(native,/p\.getBoolean\("enabled", false\)/);
 assert.match(native,/POST_NOTIFICATIONS/);
 assert.match(native,/IMPORTANCE_HIGH/);
 assert.match(native,/VISIBILITY_PRIVATE/);
 assert.match(native,/FieldPushDisplay\.show\(this, id, "Bạn có thông báo mới\."/);
 assert.match(fcm,/data:\{kind:'field_notification',binding\}/);
 assert.doesNotMatch(fcm,/notification:\s*\{/);
});
test('N5 recipient isolation and revocation gate both queued and delivered pushes',async()=>{
 const api=await readFile(new URL('../src/notifications.ts',import.meta.url),'utf8');
 const dispatch=await readFile(new URL('../src/notification_dispatch.ts',import.meta.url),'utf8');
 const sql=await readFile(new URL('../migrations/224_notification_recipient_guard.sql',import.meta.url),'utf8');
 assert.match(api,/recipient_sub=\$\{u\.sub\}/);
 assert.match(api,/scope_revision=\$\{String\(u\.staff\.scope_revision\)\}::bigint/);
 assert.match(api,/const open=/);
 assert.match(api,/public\.sales_can_access\(/);
 assert.match(dispatch,/String\(scope\.scope_revision\)!==String\(scope\.queued_revision\)/);
 assert.match(dispatch,/if\(!fresh\?\.active\|\|!fresh\?\.identity_valid\|\|!fresh\?\.valid_scope\)/);
 assert.match(dispatch,/b.expires_at>now\(\)/);
 assert.match(dispatch,/b.state IN \('pending','processing','done'\)/);
 assert.match(dispatch,/else if\(!fresh.within_expiry\)\{code='expired';\}/);
 assert.match(dispatch,/code==='revoked'\|\|code==='expired'\?'cancelled'/);
 assert.match(dispatch,/ON CONFLICT DO NOTHING/);
 assert.match(sql,/pg_advisory_xact_lock/);
 assert.match(sql,/INSERT INTO public\.field_notification_event_recipients\(event_id,recipient_sub\)[\s\S]*?ON CONFLICT DO NOTHING/);
});
