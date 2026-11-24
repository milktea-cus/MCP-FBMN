import test from 'node:test';
import assert from 'node:assert/strict';
test('only database owner may enable new notification producers',async()=>{
 const {readFile}=await import('node:fs/promises');
 const source=await readFile(new URL('../migrations/226_notification_least_privilege.sql',import.meta.url),'utf8');
 assert.match(source,/REVOKE INSERT,UPDATE,DELETE ON TABLE public\.field_notification_categories FROM sales_api/);
 assert.match(source,/GRANT SELECT ON TABLE public\.field_notification_categories TO sales_api/);
});
