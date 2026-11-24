import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import typescript from 'typescript';

const source=await readFile(new URL('../src/mail_webhooks.ts',import.meta.url),'utf8');
const compiled=typescript.transpileModule(source,{compilerOptions:{
 target:typescript.ScriptTarget.ES2022,module:typescript.ModuleKind.CommonJS
}}).outputText;
const resultModule={exports:{}};
new Function('require','module','exports',compiled)(
 name=>{if(name==='@neondatabase/serverless')return {neon:()=>{throw Error('no DB in provider fixture')}};
 throw Error('Unexpected dependency '+name);},resultModule,resultModule.exports);
const {verifyResendEventWithProvider}=resultModule.exports;
const id='msg_3MLTi3N2ooph2ARWn9xANdiEChr';
const now=Math.floor(Date.now()/1000);
const headers=new Headers({'svix-id':id,'svix-timestamp':String(now)});
const canonical={type:'inbox.email.received',created_at:new Date().toISOString(),
 data:{inbox_id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 thread_id:'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 email_id:'cccccccc-cccc-4ccc-8ccc-cccccccccccc'}};

test('N4 accepts only current provider-fetched canonical payload, never callback body',async()=>{
 const original=globalThis.fetch;let requests=0;
 try{
  globalThis.fetch=async(url,options)=>{
   requests++;
   assert.equal(url,
    'https://api.resend.com/webhooks/6256051c-8bf0-4f74-ab41-711c17e35bba/events/'+id);
   assert.equal(options.redirect,'manual');
   assert.equal(options.headers.Authorization,'Bearer provider-fixture');
   return new Response(JSON.stringify({id,type:'inbox.email.received',
    created_at:new Date().toISOString(),payload:canonical}),{status:200});
  };
  const result=await verifyResendEventWithProvider(headers,'provider-fixture',now);
  assert.deepEqual(result,canonical);
  assert.equal(requests,1);
 }finally{globalThis.fetch=original;}
});

test('N4 rejects forged IDs and expired timestamps without provider network access',async()=>{
 const original=globalThis.fetch;let requests=0;
 try{
  globalThis.fetch=async()=>{requests++;throw Error('should not call provider');};
  assert.equal(await verifyResendEventWithProvider(new Headers({
   'svix-id':'attack','svix-timestamp':String(now)}),'fixture',now),null);
  assert.equal(await verifyResendEventWithProvider(new Headers({
   'svix-id':id,'svix-timestamp':String(now-600)}),'fixture',now),null);
  assert.equal(requests,0);
 }finally{globalThis.fetch=original;}
});

test('N4 rejects unrelated provider event and missing event',async()=>{
 const original=globalThis.fetch;
 try{
  globalThis.fetch=async()=>new Response(JSON.stringify({id,type:'email.sent',
   created_at:new Date().toISOString(),payload:canonical}),{status:200});
  assert.equal(await verifyResendEventWithProvider(headers,'fixture',now),null);
  globalThis.fetch=async()=>new Response('{}',{status:404});
  assert.equal(await verifyResendEventWithProvider(headers,'fixture',now),null);
 }finally{globalThis.fetch=original;}
});
