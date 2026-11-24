import test from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
test('N2 staff no-op early return avoids scope_revision bump and preserves staff audit idempotency',async()=>{
 const s=await readFile(new URL('../migrations/232_notification_staff_noop_scope.sql',import.meta.url),'utf8');
 assert.match(s,/old_row\.employee_code IS NOT DISTINCT FROM code/);
 assert.match(s,/old_row\.active IS NOT DISTINCT FROM enabled/);
 assert.match(s,/old_row\.manager_sub IS NOT DISTINCT FROM manager/);
 assert.match(s,/FROM public\.staff_scopes x WHERE x\.user_sub=subject/);
 assert.match(s,/FROM jsonb_to_recordset\(scopes\)/);
 const stop=s.indexOf('THEN RETURN before_json; END IF;'),write=s.indexOf('INSERT INTO public.staff_members');
 assert.ok(stop>0&&write>stop);
 assert.ok(s.trimEnd().endsWith('$function$;'));
});
