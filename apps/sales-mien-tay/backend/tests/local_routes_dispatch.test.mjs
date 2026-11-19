import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';

test('weekly and monthly local route endpoints are both dispatched',()=>{
 const source=readFileSync(new URL('../src/index.ts',import.meta.url),'utf8');
 const weeklyImport=source.indexOf("import {localRouteRoutes} from './local_routes'");
 const weeklyCall=source.indexOf('await localRouteRoutes(req,env,user,url)');
 const weeklyResponse=source.indexOf('if(localResponse)return localResponse');
 const monthCall=source.indexOf('await localMonthlyRoutes(req,env,user,url)');
 const fallback=source.indexOf("return bad('Endpoint không tồn tại', 404)");
 assert.ok(weeklyImport>=0,'weekly route handler imported');
 assert.ok(weeklyCall>weeklyImport,'weekly handler must be invoked, not merely imported');
 assert.ok(weeklyResponse>weeklyCall,'weekly handler response must be returned');
 assert.ok(monthCall>weeklyResponse,'monthly handler must remain independent');
 assert.ok(fallback>monthCall,'both routes must dispatch before generic 404');
});
