import test from 'node:test';
import assert from 'node:assert/strict';
import {validateFcmDevice} from '../src/fcm.ts';
const sample={DATABASE_URL:'unused'};
const token='a'.repeat(140),binding='6cb11ce0-0cba-41b0-8ca2-55bc382b9e8a';
test('FCM provider dry-run reaches messages:send without real delivery',async()=>{
 let called=0;
 const result=await validateFcmDevice(sample,token,binding,async(url,init)=>{
  called++;
  assert.equal(url,'https://fcm.googleapis.com/v1/projects/mcp-sales-ee068/messages:send');
  assert.equal(init.method,'POST');
  assert.equal(init.redirect,'manual');
  const request=JSON.parse(init.body);
  assert.equal(request.validate_only,true);
  assert.equal(request.message.token,token);
  assert.equal(request.message.data.binding,binding);
  assert.equal(request.message.data.kind,'field_notification');
  assert.equal(init.headers.Authorization,'Bearer dummy-access-for-unit');
  return Response.json({name:'projects/mcp-sales-ee068/messages/dry-run'});
 },async()=> 'dummy-access-for-unit');
 assert.deepEqual(result,{ok:true,code:'validated'});
 assert.equal(called,1);
});
test('FCM dry-run never retries auth errors or follows redirects',async()=>{
 const auth=await validateFcmDevice(sample,token,binding,async()=>{throw Error('unexpected fetch');},
  async()=>{throw Error('oauth_invalid_signature');});
 assert.deepEqual(auth,{ok:false,code:'oauth_invalid_signature'});
 const redirect=await validateFcmDevice(sample,token,binding,async()=>new Response(null,{status:302,headers:{Location:'https://unexpected.invalid'}}),
  async()=> 'test');
 assert.deepEqual(redirect,{ok:false,code:'fcm_redirect_blocked'});
 const unregistered=await validateFcmDevice(sample,token,binding,async()=>Response.json({error:{details:[{errorCode:'UNREGISTERED'}]}},{status:404}),
  async()=> 'test');
 assert.deepEqual(unregistered,{ok:false,code:'UNREGISTERED'});
 const bad=await validateFcmDevice(sample,'bad',binding,async()=>{throw Error('called');},async()=>{throw Error('called');});
 assert.deepEqual(bad,{ok:false,code:'invalid_device'});
});
test('probe is one-off, admin-only and never logs token',async()=>{
 const {readFile}=await import('node:fs/promises');
 const source=await readFile(new URL('../src/notification_probe.ts',import.meta.url),'utf8');
 assert.match(source,/n1_fcm_provider_validation_rc16/);
 assert.match(source,/s\.role='admin'/);
 assert.match(source,/attempts<3/);
 assert.doesNotMatch(source,/console\.log/);
 const api=await readFile(new URL('../src/notifications.ts',import.meta.url),'utf8');
 assert.match(api,/fcm_provider_validation:provider\[0\]/);
});
