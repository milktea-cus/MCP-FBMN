import test from 'node:test';
import assert from 'node:assert/strict';
import {validFcmToken,validBinding,fcmConfigured} from '../src/fcm.ts';

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
