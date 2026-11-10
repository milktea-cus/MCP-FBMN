# FBMN UI — canonical source and Flutter adoption

Verified source: https://github.com/meyecarpenter23842/fbmn/tree/1ad3970a3c7f133932b47fb81d27c104c12deb5d
Owner-approved common contract dated 2026-11-03. Retrieved 2026-11-10.
The archived source files are unchanged references, not runnable React code.
- `docs/futurebook-ui-contract.md`: blob `f357fbb7178c8ec6ceaa667c455d0625ba3bfb48`
- `docs/admin-ui-design-system.md`: blob `ffe81fe6be518556c57bebb6a9932d75a752a664`
- `docs/web-component-design-system.md`: blob `1478f980b0b3dbe6731093ce01c2c17076d569f7`
- `docs/ui-system.md`: blob `2fd5e2316521010efda8e8a291f1f7bd98faf0c6`
- `docs/web-glass-g02-components.md`: blob `946f9ac333f1d53f7066673807b8c4461619cc21`
- `AGENTS.md`: blob `8202de0f9b2699db49918e8f44113311bfb5671e`
- `apps/admin/AGENTS.md`: blob `5b6d26fce835e342c8dbc01c80b4f1b982436660`
- `app/AGENTS.md`: blob `ef5ec9378da30b887a1b4190bb2f054c977318a8`

Authority: source/docs/futurebook-ui-contract.md wins over older documents.
Sales uses the common control/interaction contract and enterprise admin-style surfaces; website-only glass, public CTA red and Đại Việt theme do not apply. MCP Field is a workflow reference only. QR-app files are historical references, not normative.

Implemented: Flutter shared theme, purple accent, neutral canvas, button minimum heights responsive at 780 logical px, 13px controls, radius 9, input density, lavender table header, card borders and button transition duration. Flutter logical pixels approximate CSS px; accessibility and larger text may expand controls.
Not yet implemented/verified: exact 40px field geometry with labels, top-right animated toast, modal/drawer primitive and motion, typography font assets (do not copy fonts), full component states, screenshot UAT at 1440/1280/390/360 and Android. Do not label entire app FBMN compliant until tests and real screenshots pass.
