import test from 'node:test';
import assert from 'node:assert/strict';
import {validateAttachments,validSignature,withSignature} from '../src/mail.ts';

const file=(name='invoice.pdf',bytes='aGVsbG8=')=>({filename:name,content:bytes});

test('company mailbox signature is appended once by the server',()=>{
 assert.equal(withSignature('Xin chào','Công ty FBMN'),'Xin chào\n\nCông ty FBMN');
 assert.equal(withSignature('Xin chào','  '),'Xin chào');
 assert.equal(validSignature('A'.repeat(3000)),true);
 assert.equal(validSignature('A'.repeat(3001)),false);
 assert.equal(validSignature('bad\0signature'),false);
 assert.equal(validSignature({value:'not a string'}),false);
});

test('only bounded business documents and images can be sent',()=>{
 assert.deepEqual(validateAttachments([file()]),[{
  filename:'invoice.pdf',content:'aGVsbG8=',content_type:'application/pdf'
 }]);
 assert.deepEqual(validateAttachments(undefined),[]);
 assert.equal(validateAttachments([file('../private.pdf')]),null);
 assert.equal(validateAttachments([file('virus.exe')]),null);
 assert.equal(validateAttachments([file('empty.pdf','')]),null);
 assert.equal(validateAttachments([file('bad.pdf','not_base64')]),null);
 assert.equal(validateAttachments([file(),file(),file(),file(),file()]),null);
});

test('total attachment bytes are limited, including multiple files',()=>{
 const oneMeg='YQ=='; // one byte
 assert.equal(validateAttachments([file('one.pdf',oneMeg)])?.length,1);
 const oversized='YQ=='.repeat(2*1024*1024);
 assert.equal(validateAttachments([file('oversize.pdf',oversized)]),null);
 const threeMeg='Y'.repeat(4*1024*1024); // 3 MiB
 assert.equal(validateAttachments([file('a.pdf',threeMeg),file('b.pdf',threeMeg)]),null);
});
