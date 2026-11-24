import test from 'node:test';
import assert from 'node:assert/strict';
import {validFcmToken,validBinding,fcmConfigured,createFcmAssertion,accessToken,oauthErrorCode} from '../src/fcm.ts';

test('FCM enrollment rejects malformed and oversized tokens',()=>{
 assert.equal(validFcmToken('a'.repeat(32)),true);
 for(const value of [null,42,'short','a'.repeat(2049),'a'.repeat(32)+'\n','https://example.com/token'])assert.equal(validFcmToken(value),false);
});
test('FCM enrollment nonce must be UUID',()=>{
 assert.equal(validBinding('6cb11ce0-0cba-41b0-8ca2-55bc382b9e8a'),true);
 for(const value of [null,'other-user','6cb11ce0-0cba-41b0-8ca2-55bc382b9e8a\n'])assert.equal(validBinding(value),false);
});
test('FCM is disabled when its service account config is absent or for a different project',()=>{
 assert.equal(fcmConfigured({DATABASE_URL:'unused'}),false);
 assert.equal(fcmConfigured({DATABASE_URL:'unused',FCM_SERVICE_ACCOUNT_JSON:'not-json'}),false);
 assert.equal(fcmConfigured({DATABASE_URL:'unused',FCM_SERVICE_ACCOUNT_JSON:JSON.stringify({type:'service_account',project_id:'wrong-project'})}),false);
});

// Ephemeral test-only key, never a production credential.
test('FCM OAuth JWT carries the service key ID and verifies using RSA SHA-256',async()=>{
 const key=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
 const der=Buffer.from(await crypto.subtle.exportKey('pkcs8',key.privateKey)).toString('base64');
 const kid='a'.repeat(40);
 const env={DATABASE_URL:'unused',FCM_SERVICE_ACCOUNT_JSON:JSON.stringify({type:'service_account',project_id:'mcp-sales-ee068',client_email:'test@example.iam.gserviceaccount.com',private_key_id:kid,private_key:'-----BEGIN PRIVATE KEY-----\n'+der+'\n-----END PRIVATE KEY-----'})};
 const jwt=await createFcmAssertion(env,1700000000);
 const [h,p,s]=jwt.split('.');
 assert.equal(JSON.parse(Buffer.from(h,'base64url')).kid,kid);
 assert.deepEqual(JSON.parse(Buffer.from(p,'base64url')),{iss:'test@example.iam.gserviceaccount.com',scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:1699999970,exp:1700000300});
 assert.equal(await crypto.subtle.verify('RSASSA-PKCS1-v1_5',key.publicKey,Buffer.from(s,'base64url'),new TextEncoder().encode(h+'.'+p)),true);
 const token=await accessToken(env,async(url,options)=>{
  assert.equal(url,'https://oauth2.googleapis.com/token');
  assert.equal(options.redirect,'manual');
  assert.equal(options.method,'POST');
  assert.equal(new URLSearchParams(options.body).get('grant_type'),'urn:ietf:params:oauth:grant-type:jwt-bearer');
  return Response.json({access_token:'synthetic-test'});
 });
 assert.equal(token,'synthetic-test');
 await assert.rejects(accessToken(env,async()=>new Response(null,{status:302,headers:{Location:'https://example.invalid'}})),{message:'oauth_redirect_blocked'});
 await assert.rejects(accessToken(env,async()=>Response.json({error:'invalid_grant',error_description:'Invalid JWT Signature.'},{status:400})),{message:'oauth_invalid_signature'});
 await assert.rejects(accessToken(env,async()=>{throw Error('secret test detail');}),{message:'oauth_network_failed'});
});
test('OAuth failures distinguish key, time, account and network without raw provider text',()=>{
 assert.equal(oauthErrorCode(400,{error:'invalid_grant',error_description:'Invalid JWT Signature.'}),'oauth_invalid_signature');
 assert.equal(oauthErrorCode(400,{error:'invalid_grant',error_description:'Check iat and exp'}),'oauth_clock');
 assert.equal(oauthErrorCode(400,{error:'invalid_grant',error_description:'Account not found'}),'oauth_account_invalid');
 assert.equal(oauthErrorCode(401,{error:'invalid_client'}),'oauth_invalid_client');
 assert.equal(oauthErrorCode(500,{error_description:'secret'}),'oauth_http_500');
});

test('both Google calls use Workers-compatible manual redirect without forwarding credentials',async()=>{
 const {readFile}=await import('node:fs/promises');
 const source=await readFile(new URL('../src/fcm.ts',import.meta.url),'utf8');
 assert.ok((source.match(/redirect:'manual'/g)||[]).length>=2);
 assert.ok(!source.includes("redirect:'error',"));
 assert.ok(source.includes("return 'fcm_redirect_blocked'"));
});
