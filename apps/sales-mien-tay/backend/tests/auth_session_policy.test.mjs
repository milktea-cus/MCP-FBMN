import assert from 'node:assert/strict';
import test from 'node:test';
import {classifySessionProviderFailure,classifySessionSnapshot} from '../src/auth_session_policy.ts';

test('Neon Auth session validator only reports a definitive 401 as invalid',()=>{
  assert.equal(classifySessionProviderFailure(401),401);
});

test('throttling and maintenance do not sign Android users out',()=>{
  for(const status of [400,403,408,409,425,429,500,502,503,504]){
    assert.equal(classifySessionProviderFailure(status),503,
      `HTTP ${status} must be considered transient/unconfirmed`);
  }
});

test('only explicitly revoked, expired or unverified sessions invalidate cookie',()=>{
  const now=Date.parse('2026-11-15T00:00:00Z');
  assert.deepEqual(classifySessionSnapshot(null,now),{kind:'invalid'});
  assert.deepEqual(classifySessionSnapshot({user:null,session:null},now),{kind:'invalid'});
  assert.deepEqual(classifySessionSnapshot({
    user:{id:'staff-1',emailVerified:false},
    session:{expiresAt:'2026-11-22T00:00:00Z'}
  },now),{kind:'invalid'});
  assert.deepEqual(classifySessionSnapshot({
    user:{id:'staff-1',emailVerified:true},
    session:{expiresAt:'2026-11-14T23:59:59Z'}
  },now),{kind:'invalid'});
});

test('schema errors and partial/malformed upstream responses do not delete Android credentials',()=>{
  for(const payload of [undefined,false,{},[],{error:'upstream failed'},
    {user:{},session:{}},
    {user:{id:'staff-1',emailVerified:true},session:{expiresAt:'invalid'}}]){
    assert.deepEqual(classifySessionSnapshot(payload),{kind:'unavailable'});
  }
});

test('valid verified session accepts unchanged opaque subject',()=>{
  const result=classifySessionSnapshot({
    user:{id:'staff-1',emailVerified:true},
    session:{expiresAt:'2099-01-01T00:00:00Z'}
  },Date.parse('2026-11-15T00:00:00Z'));
  assert.deepEqual(result,{kind:'valid',subject:'staff-1'});
});
