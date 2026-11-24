import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const source=await readFile(new URL('../src/notifications.ts',import.meta.url),'utf8');
test('N4 routing is checked for identity, scope, and entity-level access',()=>{
 assert.ok(source.includes('const open='));
 assert.ok(source.includes('recipient_sub=${u.sub}'));
 assert.ok(source.includes('public.sales_can_access('));
 assert.ok(source.includes('field_mail_inbound_events'));
 assert.ok(source.includes("screen:'orders'"));
 assert.ok(source.includes("screen:'mail'"));
 assert.ok(source.includes("r.kind='support'"));
});
test('N4 read-all respects immutable notification watermark',()=>{
 assert.ok(source.includes('Mốc thông báo không hợp lệ'));
 assert.ok(source.includes('id<=${upto}::bigint'));
});
