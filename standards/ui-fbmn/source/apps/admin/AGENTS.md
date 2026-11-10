# Agent instructions — Futurebook Admin (`apps/admin/**`)

## Mandatory Futurebook-wide UI contract (Owner, 03/11/2026)

**FIRST read `../../docs/futurebook-ui-contract.md` and root `../../AGENTS.md`.** These rules are binding for every Admin change and supersede any approximate values below:
desktop button **36px**; input/select **40px**; mobile button **44px**; control text **13px**; radius **8–10px**; purple accents; **lavender-tinted data table headers**; **small top-right toast**; **create/edit via modal or drawer, never inline in a list**. **Required smooth motion:** button **180–200ms**, menu **180–220ms**, modal enter **280ms** / exit **220ms**, drawer **300ms**, reduced-motion support and real exit animation before unmount. **Required compact modal header:** **52px desktop / 56px mobile**, title **16px**, near-white/lavender with a restrained Futurebook purple accent. Preserve separately approved toast timing. Use shared `apps/admin/app/admin-controls.css`, not screen-scoped duplicate tab/button dimensions. CI test `tests/futurebook-ui-contract.test.mjs` must pass. Do not remove approved tabs, lose multi-channel selection, or disconnect dynamic price lists from their Excel flow as incidental simplifications.

## Mandatory UI design contract
Before editing any Admin frontend TSX/CSS, read **[`docs/admin-ui-design-system.md`](../../docs/admin-ui-design-system.md)**. It is the canonical **component-level** visual contract for Futurebook Admin; `docs/ui-system.md` applies to the public website instead.

Owner's UI intent (03/11/2026):
- **Keep existing layout, information architecture, routes, feature set and approved UX workflows** unless the request expressly changes them.
- Keep **Futurebook purple as a deliberate accent**, not purple everywhere. Improve **card/button/input/dropdown/table/modal/icon craftsmanship and interaction states**, not by adding dashboard cards, banners or charts.
- Prefer semantic tokens, consistent spacing, typography, understated borders/shadows and accessible focus. For every Admin UI PR, check modal/menu/button motion and header against the canonical contract, not screen-specific guessed values. Avoid adding CSS overrides as patches or introducing a UI library without justification.
- Do not infer implementation details from an AI-generated design mockup; no fake SKU, stats, images, prices, catalogue data or brand assets.

## Functional guardrails
- Never auto-allocate a category or variant-group code: the administrator provides memorable custom codes.
- Excel column **Skip** means no change. A mapped column's blank source is intentionally distinct from Skip per Owner's latest UX decision. **Existing P3 documentation may conflict**; never silently change import backend behavior while polishing visuals. Raise/handle discrepancy in a separate testable logic change.
- Preserve company SKU strings and leading zeros. Keep existing roles/auth, API, R2 behavior, permissions, confidential NET pricing and real product data unchanged unless the task specifically authorizes them.
- Do not modify public website UI as a side effect of Admin polish.

## Delivery
- Check the affected TSX/CSS and existing component variants first.
- Work in the current assigned feature branch; coordinate with concurrent PRs rather than editing their files unnecessarily. Avoid sweeping refactors when the task is narrowly scoped.
- For frontend changes, provide actual before/after screenshots at desktop and mobile, test interaction states, keyboard behavior, reduced motion and long text.
- Follow branch → PR → CI green → clean review → squash merge per project policy. **No automatic Vercel deployment**; Owner decides preview/production.
- For this documentation PR alone, there are **no runtime UI changes** and screenshots are not applicable.
