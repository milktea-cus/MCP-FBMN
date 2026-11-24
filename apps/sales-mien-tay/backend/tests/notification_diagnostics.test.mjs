import test from 'node:test';
import assert from 'node:assert/strict';
test('bounded FCM OAuth health probe never persists secrets',async()=>{
 const {readFile}=await import('node:fs/promises');
 const source=await readFile(new URL('../src/notification_probe.ts',import.meta.url),'utf8');
 assert.match(source,/attempts<3/);
 assert.match(source,/interval '15 minutes'/);
 assert.match(source,/oauth_network_failed/);
 assert.doesNotMatch(source,/console\.log|private_key|access_token/);
 const api=await readFile(new URL('../src/notifications.ts',import.meta.url),'utf8');
 assert.match(api,/notifications\/diagnostics/);
 assert.match(api,/u\.admin\?\{fcm_oauth_probe/);
});
