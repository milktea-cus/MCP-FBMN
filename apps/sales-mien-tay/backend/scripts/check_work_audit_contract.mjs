// Build-time guard for a production-breaking schema mismatch found 2026-11-14.
// Migration 046 emits field_route_audit(action='cancel'); earlier CHECK only
// allowed ('create','update'), causing SQLSTATE 23514 and full DELETE rollback.
// Fail Vercel build if this invariant is removed from the migration chain.
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';
const root=join(dirname(fileURLToPath(import.meta.url)),'..');
const read=p=>readFileSync(join(root,p),'utf8');
const archive=read('migrations/046_archive_work_schedule.sql');
const fix=read('migrations/047_route_audit_cancel_action.sql');
const router=read('src/monthly_plans.ts');
const routeRouter=read('src/day_routes.ts');
const checks=[
 ['archive function records distinct cancel audit action',
  /INSERT INTO public\.field_route_audit[\s\S]*?VALUES\(p_actor,'route',old_route\.id,'cancel'/.test(archive)],
 ['schema migration explicitly permits create/update/cancel',
  /ADD CONSTRAINT field_route_audit_action_check[\s\S]*?CHECK\s*\(action IN\s*\('create','update','cancel'\)\)/.test(fix)],
 ['public DELETE route uses versioned DB function',
  /req\.method==='DELETE'[\s\S]*?sales_archive_monthly_plan/.test(router)],
 ['route creation protects idempotent already-saved trips',
  /saved\.plan_status==='cancelled'[\s\S]*?already_saved:true/.test(routeRouter)],
 ['stop creation protects idempotent already-saved stops',
  /duplicate\.length\)return reply\(\{item:duplicate\[0\],already_saved:true\},200\)/.test(routeRouter)],
];
for(const [name,pass] of checks){
 if(!pass){console.error('FAIL work audit contract: '+name);process.exitCode=1;}
 else console.log('PASS work audit contract: '+name);
}
