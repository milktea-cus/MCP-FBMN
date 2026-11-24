import test from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
const sql=await readFile(new URL('../migrations/236_notification_inbound_email.sql',import.meta.url),'utf8');
const js=await readFile(new URL('../src/mail_webhooks.ts',import.meta.url),'utf8');
const index=await readFile(new URL('../src/index.ts',import.meta.url),'utf8');
test('N4 inbound requires signed Svix, authentic inbox mapping and no raw mail content',()=>{
 assert.match(js,/verifyResendSignature/);assert.match(js,/Math\.abs\(Number\(timestamp\)-now\)>300/);
 assert.match(js,/payload.type!=='inbox.email.received'/);assert.match(js,/email_address/);
 assert.match(js,/await fetch\('https:\/\/api.resend.com\/inboxes\//);
 assert.match(js,/return ok\(401\)/);assert.match(index,/resendInboundWebhook\(req,env\)/);
 assert.match(sql,/JOIN public.staff_members s ON s.user_sub=mb.user_sub/);
 assert.match(sql,/public.sales_identity_exists\(s.user_sub\)/);
 assert.match(sql,/GROUP_COUNT|group_count/i);
 assert.doesNotMatch(sql,/sender|subject|content_body|mail_text/i);
});
test('N4 inbox webhook is at-most-once per message and at-most-one push per thread group',()=>{
 assert.match(sql,/PRIMARY KEY\(mailbox,email_id\)/);
 assert.match(sql,/pg_advisory_xact_lock/);
 assert.match(sql,/created_at>now\(\)-interval '15 minutes'/);
 assert.match(sql,/EXISTS\(SELECT 1 FROM public.field_notification_outbox o WHERE o.notification_id=v_notice\)/);
 assert.match(sql,/v_mode='digest'/);
 assert.match(sql,/p_received<now\(\)-interval '24 hours'/);
});
