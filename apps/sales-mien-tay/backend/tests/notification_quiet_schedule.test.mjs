import test from 'node:test';
import assert from 'node:assert/strict';
test('Neon event RPC evaluates custom quiet hours at planned dispatch time',async()=>{
 const {readFile}=await import('node:fs/promises');
 const source=await readFile(new URL('../migrations/227_notification_digest_quiet_hours.sql',import.meta.url),'utf8');
 const scheduled=source.indexOf("IF v_mode='digest' THEN");
 const fromScheduled=source.indexOf("v_local:=v_available AT TIME ZONE 'Asia/Ho_Chi_Minh'",scheduled);
 const quiet=source.indexOf('IF v_quiet_start<>v_quiet_end',fromScheduled);
 assert.ok(scheduled>0&&fromScheduled>scheduled&&quiet>fromScheduled);
 assert.match(source,/v_available:=greatest\(v_available/);
 assert.match(source,/interval '1 day'/);
});
