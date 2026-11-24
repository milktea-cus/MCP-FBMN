// Shared N1 policy. No producer is enabled by this module.
export const modes=['immediate','digest','in_app','off'] as const;
export type Mode=typeof modes[number];
export function validMode(x:unknown):x is Mode {
 return typeof x==='string'&&(modes as readonly string[]).includes(x);
}
export function validMinute(x:unknown):x is number {
 return typeof x==='number'&&Number.isInteger(x)&&x>=0&&x<1440;
}
export function effectiveMode(mode:Mode,mandatory:boolean):Mode {
 return mandatory&&mode==='off'?'in_app':mode;
}
// Vietnam has a fixed UTC+7 offset; UTC arithmetic avoids host timezone drift.
export function quietUntil(now:Date,start=1260,end=420):Date {
 if(!validMinute(start)||!validMinute(end))throw Error('invalid_quiet_hours');
 const local=new Date(now.getTime()+7*3600000);
 const minute=local.getUTCHours()*60+local.getUTCMinutes();
 const quiet=start!==end&&(start<end?minute>=start&&minute<end:minute>=start||minute<end);
 if(!quiet)return now;
 const target=Date.UTC(local.getUTCFullYear(),local.getUTCMonth(),local.getUTCDate(),0,end)
  +(start>end&&minute>=start?86400000:0)-7*3600000;
 return new Date(target);
}
export function pageSize(x:string|null):number|null {
 if(x===null)return 60;
 if(!/^[1-9][0-9]{0,2}$/.test(x))return null;
 const n=Number(x);return n<=100?n:null;
}
export function validCursor(x:string):boolean {
 return /^[1-9][0-9]{0,18}$/.test(x)&&(x.length<19||x<='9223372036854775807');
}
export function transientPushError(code:string):boolean {
 return code==='network_error'||code==='oauth_network_failed'||code==='QUOTA_EXCEEDED'||
  /^(?:oauth_)?http_(?:429|5[0-9]{2})$/.test(code);
}

export async function deviceDigest(value:string):Promise<string> {
 const data=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value));
 return Array.from(new Uint8Array(data)).map(x=>x.toString(16).padStart(2,'0')).join('');
}
