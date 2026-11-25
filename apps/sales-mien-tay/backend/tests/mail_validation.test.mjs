import test from 'node:test';
import assert from 'node:assert/strict';
import {validateAttachments,renderBrandedMail,SIGNATURE_TEMPLATE,attachmentRoute,parseMailBody,mailProviderStatus,mailText,mailRows,validMailId} from '../src/mail.ts';

const file=(name='invoice.pdf',bytes='aGVsbG8=')=>({filename:name,content:bytes});

test('published Resend signature centrally brands outbound HTML without trusting input',()=>{
 assert.equal(SIGNATURE_TEMPLATE,'fbmn-fieldwork-signature');
 const footer='<table><tr><td>FUTUREBOOK MIỀN NAM<br>1092A Lê Đức Anh (QL01A), P. Tân Tạo, TP. Hồ Chí Minh<br><a href="https://www.fbmn.vn">Website</a></td></tr></table>';
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
 assert.match(rendered.html,/&lt;\/script&gt;<br>Lần 2/);
 assert.equal(rendered.text,'Xin chào <script>alert(1)</script>\nLần 2\n\n'+template.text);
 for(const tag of ['script','iframe','form','object','embed']){
  assert.equal(renderBrandedMail('Hello',{...template,html:template.html.replace(footer,footer+'<'+tag+'>x</'+tag+'>')}),null);
 }
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

test('attachment route validates exactly three identifiers for web and native',()=>{
 const id='11111111-1111-4111-8111-111111111111';
 const path='/api/v1/mail/threads/'+id+'/emails/'+id+'/attachments/'+id;
 assert.deepEqual(attachmentRoute(path),{thread:id,email:id,attachment:id,redirect:false});
 assert.equal(attachmentRoute(path+'/download')?.redirect,true);
 assert.equal(attachmentRoute(path.replace(id,'invalid')),null);
});
test('reply and send share the same bounded JSON envelope including a 5 MiB attachment',()=>{
 const content=Buffer.alloc(5*1024*1024,65).toString('base64');
 const raw=JSON.stringify({text:'reply',request_id:'11111111-1111-4111-8111-111111111111',attachments:[file('large.pdf',content)]});
 const body=parseMailBody(raw);
 assert.ok(body);assert.equal(validateAttachments(body.attachments)?.length,1);
 assert.equal(parseMailBody('[]'),null);
 assert.equal(parseMailBody('null'),null);
 assert.equal(parseMailBody('x'.repeat(9*1024*1024+1)),null);
});
test('provider resource errors are distinct from app authentication failures',()=>{
 for(const status of [400,404,409,413,415,422,429])assert.equal(mailProviderStatus(status),status);
 for(const status of [401,403,500,502])assert.equal(mailProviderStatus(status),503);
});

test('HTML-only mail becomes inert readable text, preserving paragraphs and Unicode',()=>{
 const html='<html><head><title>Hidden title</title><style>hidden css</style></head><body>'+
  '<p>Xin chào &amp; cảm ơn &#x1F44B;<br>Hẹn gặp lại</p>'+
  '<script>bad script</script><div hidden>hidden content</div>'+
  '<div style="display:none">tracking</div><img src="https://example.test/pixel">'+
  '<p>Đơn <b>hàng</b></p><ul><li>Kho A</li><li>Kho B</li></ul>'+
  '<p><a href="https://example.test/private">Xem tài liệu</a></p></body></html>';
 const plain=mailText({html,text:''});
 assert.match(plain,/Xin chào & cảm ơn 👋\nHẹn gặp lại/);
 assert.match(plain,/Đơn hàng\n• Kho A\n• Kho B/);
 assert.match(plain,/Xem tài liệu/);
 assert.doesNotMatch(plain,/hidden|bad script|tracking|https:|<img/i);
 assert.equal(mailText({text:'original\nbody',html}), 'original\nbody');
 assert.equal(mailText({html:'<script>hidden</script>'}),null);
 assert.equal(mailText({html:'<p>'+'x'.repeat(130000)+'</p>'})?.length,120000);
});
test('malformed provider success becomes a non-2xx error and invalid rows fail closed',()=>{
 for(const status of [200,201,204,302])assert.equal(mailProviderStatus(status),503);
 const id='11111111-1111-4111-8111-111111111111';
 assert.equal(validMailId(id),true);assert.equal(validMailId('unexpected'),false);
 assert.equal(mailRows(null),null);assert.equal(mailRows([null]),null);
 assert.equal(mailRows([{id:'bad'}]),null);
 assert.deepEqual(mailRows([]),[]);
 assert.equal(mailRows([{id,html:'<p>Nội dung</p>'}])?.[0].text,'Nội dung');
});
