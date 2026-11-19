import test from 'node:test';
import assert from 'node:assert/strict';
import {validateAttachments,renderBrandedMail,SIGNATURE_TEMPLATE} from '../src/mail.ts';

const file=(name='invoice.pdf',bytes='aGVsbG8=')=>({filename:name,content:bytes});

test('published Resend signature centrally brands outbound HTML without trusting input',()=>{
 assert.equal(SIGNATURE_TEMPLATE,'fbmn-fieldwork-signature');
 const footer='<table><tr><td>FUTUREBOOK MIỀN NAM<br><a href="https://www.fbmn.vn">Website</a></td></tr></table>';
 // The same markers are embedded in the centrally published Resend template.
 const template={
  status:'published',
  html:'<!DOCTYPE html><html><body><!-- FBMN_SIGNATURE_START -->'+footer+
       '<!-- FBMN_SIGNATURE_END --></body></html>',
  text:'FUTUREBOOK MIỀN NAM · info@fbmn.vn'
 };
 const rendered=renderBrandedMail('Xin chào <script>alert(1)</script>\nLần 2',template);
 assert.ok(rendered);
 assert.match(rendered.html,/FUTUREBOOK MIỀN NAM/);
 assert.match(rendered.html,/&lt;script&gt;/);
 assert.doesNotMatch(rendered.html,/<script>/);
 assert.match(rendered.html,/Lần 2/);
 assert.equal(rendered.html.split('FUTUREBOOK MIỀN NAM').length,2);
 assert.match(rendered.text,/info@fbmn.vn/);
 assert.equal(renderBrandedMail('Xin chào',{...template,status:'draft'}),null);
 assert.equal(renderBrandedMail('Xin chào',{...template,html:'<table>no markers</table>'}),null);
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
