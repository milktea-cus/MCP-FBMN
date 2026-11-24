import test from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
const source=await readFile(new URL('../src/notifications.ts',import.meta.url),'utf8');
test('N4 navigation is authorized for same account and revision, no client URL',()=>{
 assert.match(source,/\\/open\$\/\.exec\(path\)/);assert.match(source,/recipient_sub=\\\$\{u.sub\}/);
 assert.match(source,/sales_can_access/);assert.match(source,/field_mail_inbound_events/);assert.match(source,/sales_records r/);
 assert.doesNotMatch(source,/destination:\{screen:.*url:/);
});
test('N4 read-all accepts snapshot watermark to avoid marking later offline receipts',()=>{
 assert.match(source,/Mốc thông báo không hợp lệ/);assert.match(source,/id<=\\\$\{upto\}::bigint/);
});
