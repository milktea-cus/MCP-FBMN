import test from 'node:test';
import assert from 'node:assert/strict';
test('N1 denied-by-default recipient policy requires verified action and release flag',async()=>{
 const {readFile}=await import('node:fs/promises');
 const base=new URL('../migrations/',import.meta.url);
 const mig=await readFile(new URL('224_notification_recipient_guard.sql',base),'utf8');
 assert.match(mig,/sales_staff_action_allowed\(p_actor,p_recipient,'target'\)/);
 assert.match(mig,/sales_staff_action_allowed\(p_actor,p_recipient,'staff_manage'\)/);
 assert.match(mig,/ELSE\s+RETURN NULL;/);
 const code=await readFile(new URL('../src/notification_dispatch.ts',import.meta.url),'utf8');
 assert.match(code,/valid_scope/);
 const push=await readFile(new URL('../src/notifications.ts',import.meta.url),'utf8');
 assert.match(push,/if\(!validEndpoint\(endpoint\)\)/);
});
