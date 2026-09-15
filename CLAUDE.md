# kipo — aplicación de finanzas personales

## Authority order

If two sources contradict each other, **the lower number wins.**

| # | Layer | Where it lives |
|---|---|---|
| 1 | **Why** | `docs/ADRs.md` and `docs/ODs.md` — **they outrank everything, no exceptions** |
| 2 | **How** | `docs/modelo-de-datos.md` — tables, fields, invariants and the use cases resolved against them |
| 3 | **Shape** | `src/lib/types.ts` and `src/lib/ledger/entries.ts` — **the sign convention lives there and nowhere else**: screens express intent, never a sign |
| 4 | **What to build** | `porposal.md` — the product brief written by the developer: scope, goals and constraints |
| 5 | **Evidence** | `analisis-inicial.md` — domain analysis backing the decisions in `docs/ADRs.md` |

<!-- Every layer now points at something real. Layer 3 arrived on 2026-09-15 with the first code. -->

**Read `docs/ODs.md` before deciding anything this project has not decided.** An item marked
`NEEDS-INPUT` is blocked on something this team cannot produce: **do not resolve it by inventing the
missing fact.**

**What you discover while working goes back into those records, in the same change.**

## Idioma

La prosa de los registros está en español, igual que `porposal.md` y `analisis-inicial.md`. La
**estructura** de `docs/ADRs.md` y `docs/ODs.md` se mantiene en inglés — nombres de archivo, nombres
de campo, los cuatro estados (`OPEN`, `LEANING`, `NEEDS-INPUT`, `DECIDED`) y los tres tipos
(`decision`, `risk`, `debt`) — porque es lo que se lee de forma uniforme entre repositorios. **No se
traducen.**
