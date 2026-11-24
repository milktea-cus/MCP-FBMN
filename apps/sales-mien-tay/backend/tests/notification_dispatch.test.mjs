import test from 'node:test';
import assert from 'node:assert/strict';
import {deviceDigest} from '../src/notification_dispatch.ts';
import {safeNotice} from '../src/notification_events.ts';
test('event validation suppresses self notification and malformed event',()=>{
 const n={eventKey:'target:batch:abc',category:'target',entityKey:'abc',actor:'manager',recipient:'sales',title:'Thông báo',body:'Có cập nhật'};
 assert.equal(safeNotice(n),true);
 assert.equal(safeNotice({...n,recipient:'manager'}),false);
 assert.equal(safeNotice({...n,eventKey:'x'.repeat(161)}),false);
 assert.equal(safeNotice({...n,title:'X\nY'}),false);
});
test('delivery stores only stable digests, no device credentials',async()=>{
 const a=await deviceDigest('fcm_private_test_device_token');
 assert.match(a,/^[0-9a-f]{64}$/);
 assert.equal(await deviceDigest('fcm_private_test_device_token'),a);
 assert.notEqual(await deviceDigest('different_token'),a);
});
test('worker schedule is present with feature producers initially disabled',async()=>{
 const {readFile}=await import('node:fs/promises');
 const cfg=await readFile(new URL('../wrangler.toml',import.meta.url),'utf8');
 const migration=await readFile(new URL('../migrations/222_notification_engine_foundation.sql',import.meta.url),'utf8');
 assert.match(cfg,/crons = \["\*\/5 \* \* \* \*"\]/);
 assert.match(migration,/producer_enabled boolean NOT NULL DEFAULT false/);
});
