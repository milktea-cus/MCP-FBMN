import {neon} from '@neondatabase/serverless';

// App's existing 5-minute Cloudflare Cron invokes this exactly once per slot.
// SQL owns clock-locality, recipient identity checks, idempotency and all writes.
export async function runScheduledSummaries(env:{DATABASE_URL:string}):Promise<number> {
 const sql=neon(env.DATABASE_URL);
 const rows=await sql`SELECT public.sales_n3_tick() AS emitted`;
 return Number(rows[0]?.emitted??0);
}
