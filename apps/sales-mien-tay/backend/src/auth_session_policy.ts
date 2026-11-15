/** Distinguish a genuinely invalid Neon Auth cookie from upstream
 * throttling, maintenance, redirects and other non-authoritative failures.
 * Only a definite 401 from the session verification endpoint may revoke the
 * local login. Staff deactivation is independently enforced by principal().
 */
export function classifySessionProviderFailure(status:number):401|503 {
  return status===401?401:503;
}

/** Only explicit null/expired/unverified sessions are definitive. A malformed
 * 200 response may indicate an upstream outage or schema change, not logout.
 */
export type SessionSnapshot =
  | {kind:'valid';subject:string}
  | {kind:'invalid'}
  | {kind:'unavailable'};

export function classifySessionSnapshot(value:unknown, now=Date.now()):SessionSnapshot {
  if(value===null)return {kind:'invalid'};
  if(!value||typeof value!=='object'||Array.isArray(value))return {kind:'unavailable'};
  const body=value as Record<string,unknown>;
  if(body.user===null||body.session===null)return {kind:'invalid'};
  if(!body.user||!body.session||typeof body.user!=='object'||typeof body.session!=='object'||
     Array.isArray(body.user)||Array.isArray(body.session))return {kind:'unavailable'};
  const user=body.user as Record<string,unknown>;
  const session=body.session as Record<string,unknown>;
  if(typeof user.id!=='string'||!user.id||
     typeof user.emailVerified!=='boolean'||typeof session.expiresAt!=='string'){
    return {kind:'unavailable'};
  }
  const expiry=Date.parse(session.expiresAt);
  if(!Number.isFinite(expiry))return {kind:'unavailable'};
  if(!user.emailVerified||expiry<=now)return {kind:'invalid'};
  return {kind:'valid',subject:user.id};
}
