/** Distinguish a genuinely invalid Neon Auth cookie from upstream
 * throttling, maintenance, redirects and other non-authoritative failures.
 * Only a definite 401 from the session verification endpoint may revoke the
 * local login. Staff deactivation is independently enforced by principal().
 */
export function classifySessionProviderFailure(status:number):401|503 {
  return status===401?401:503;
}
