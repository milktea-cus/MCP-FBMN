import assert from 'node:assert/strict';
import test from 'node:test';
import {classifySessionProviderFailure} from '../src/auth_session_policy.ts';

test('Neon Auth session validator only reports a definitive 401 as invalid',()=>{
  assert.equal(classifySessionProviderFailure(401),401);
});

test('throttling and maintenance do not sign Android users out',()=>{
  for(const status of [400,403,408,409,425,429,500,502,503,504]){
    assert.equal(classifySessionProviderFailure(status),503,
      `HTTP ${status} must be considered transient/unconfirmed`);
  }
});
