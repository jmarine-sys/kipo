# Open — what is not decided yet

This is **the project's edge of knowledge**: everything undecided, at risk, or owed, in one place.

It exists for a concrete reason: **without it an agent invents an answer where there is none, and
invents it with complete confidence.** So does a new person.

It is the counterpart of [ADRs.md](ADRs.md): there is **what was decided and why**, here
**what is missing**. Together they are the state of the project.

---

## The rules of this register

1. **The register does not duplicate the analysis: it links to where it lives.** If a *why* starts
   being explained here, it is drifting. Cut it and leave a link.
2. **Four states**, and the third is what makes the rest credible.

   | State | What it means |
   |---|---|
   | `OPEN` | undecided |
   | `LEANING` | there is a recommendation, missing a signature |
   | `NEEDS-INPUT` | **blocked on something we cannot produce ourselves** |
   | `DECIDED` | resolved, with its ref — and with its reservation written down if one remains |

   `NEEDS-INPUT` separates *"we did not decide"* from *"we CANNOT decide"*. Without it, an item that
   depends on another team looks like laziness, **and the agent invents the missing fact.**
3. **Three types:** `decision` · `risk` · `debt`.
4. **No urgency labels.** Priority comes out of the *Blocks* column and **recalculates itself** when
   something resolves. A `P0` set by hand in March still says P0 in September.
5. **If the item does not fit on one line, it is two items.**
6. **An open item that is already resolved but still marked open is worse than an open one:** it
   teaches the reader to distrust the whole register. That includes the count in the header.

---

## The register

| # | Item | Type | State | Note — and what exactly is missing | Blocks |
|---|---|---|---|---|---|
| OD-01 | Proveedor de base de datos y autenticación | `decision` | DECIDED | **Supabase** → [ADR-007](ADRs.md#adr-007--el-backend-es-supabase). **Reserva:** arrastra dos deudas reales, OD-16 (sin backups) y OD-10 (pausa a los 7 días), y OD-15 sigue sin verificar | — |
| OD-02 | Framework de frontend y hosting estático | `decision` | DECIDED | **SvelteKit + adapter-static en modo SPA** → [ADR-017](ADRs.md#adr-017--el-frontend-es-sveltekit-con-adapter-static-en-modo-spa). El **hosting queda abierto a propósito**: la salida estática se publica igual en Cloudflare Pages, Vercel o GitHub Pages, así que no hace falta atarlo ahora. **Reserva:** ecosistema más chico que el de React | — |
| OD-03 | Migración del histórico de la planilla | `decision` | DECIDED | **No se migra** → [ADR-015](ADRs.md#adr-015--no-se-migra-el-histórico-de-la-planilla). **Cerrado del todo el 2026-09-15**: el usuario tampoco quiere aportar filas de muestra — *"no quiero tomarla como ejemplo para este nuevo desarrollo"*. **Reserva:** el modelo se valida entonces solo contra los 13 casos de uso de [modelo-de-datos.md](modelo-de-datos.md) §5 y contra el uso real, no contra datos históricos | — |
| OD-04 | Qué tipo de cambio se usa y si se guarda el real de cada operación | `decision` | DECIDED | El de la operación **se deduce de los montos** → [ADR-010](ADRs.md#adr-010--el-tipo-de-cambio-de-una-operación-se-deduce-de-sus-montos-no-se-guarda). El de valuación **es propiedad de la cuenta** → [ADR-011](ADRs.md#adr-011--la-fuente-de-cotización-es-una-propiedad-de-la-cuenta-no-de-la-fecha). **Reserva:** los CEDEARs no encajan del todo — ver OD-17 | — |
| OD-05 | Qué instrumentos de inversión tiene realmente | `decision` | DECIDED | Inventario 2026-09-15: **CEDEARs** (Balanz), **cripto** (Binance) y **cuentas remuneradas** (Mercado Pago). Son **tres mecánicas distintas**, no tres ejemplos de lo mismo. Abre OD-17 y OD-18 | Etapa 5 — desbloqueada |
| OD-06 | Precios de activos: carga manual o automática | `decision` | OPEN | El esquema ya soporta ambas: `price.source` distingue `manual` de `api` ([modelo-de-datos.md](modelo-de-datos.md) §2.4), así que **la decisión dejó de ser estructural y pasó a ser de producto**. Cripto tiene precio 24/7 y manual es inviable; CEDEARs cotizan en rueda. Apunta a automático para cripto como mínimo | Etapa 5 y 7 — ya no bloquea el esquema |
| OD-07 | Invariante de suma cero en transacciones multi-moneda | `decision` | DECIDED | **Suma cero por unidad, salvo intercambios**, donde las dos unidades quedan relacionadas por el cociente de sus montos → [ADR-010](ADRs.md#adr-010--el-tipo-de-cambio-de-una-operación-se-deduce-de-sus-montos-no-se-guarda). **Reserva:** vale para exactamente 2 unidades; con 3 o más hay que rechazar la transacción, no suponer que no pasa | Modelo de datos — **desbloqueado** |
| OD-08 | Método de autenticación | `decision` | DECIDED | Email+contraseña, Google y TOTP opcional — los tres → [ADR-008](ADRs.md#adr-008--la-autenticación-ofrece-email-contraseña-google-y-totp-opcional). **Reserva:** tres caminos de acceso son tres cosas que probar y mantener | — |
| OD-09 | Moneda de medición del rendimiento | `decision` | DECIDED | **USD** → [ADR-009](ADRs.md#adr-009--el-rendimiento-de-las-inversiones-se-mide-en-usd). **Reserva:** el dólar tampoco es vara estable en términos reales; medir en USD es mejor que en ARS nominal, no es medir en términos reales | — |
| OD-10 | El free tier elegido puede pausar el proyecto por inactividad | `risk` | OPEN | **Riesgo aceptado, con el alcance ya medido.** Supabase pausa tras 7 días sin actividad y **la restauración es manual** (OD-15). Con uso diario de 3 personas no se dispara; se dispara tras vacaciones o abandono. Textual de la doc: *"Upgrade to Pro to guarantee that we won't pause your project"* — US$25/mes, hoy no se justifica. **No se mitiga con pings artificiales**: si nadie la usa una semana, el problema es que nadie la usa | Nada. Se revisa con uso real |
| OD-11 | La fricción de cargar cada consumo con tarjeta puede matar la adopción | `risk` | OPEN | Consecuencia asumida de [ADR-004](ADRs.md#adr-004--la-tarjeta-de-crédito-se-modela-como-cuenta-de-pasivo). El proyecto existe porque cargar era costoso, y esta decisión lo aumenta. Mitigación en interfaz, no en modelo. **Solo se puede evaluar con uso real** | Revisión post-MVP |
| OD-12 | La apuesta de online-only puede fallar en el caso de uso central | `risk` | DECIDED | **Riesgo aceptado explícitamente por el usuario el 2026-09-15**, y con buen argumento: si justo en ese momento no hay señal, **se espera** — registrar el gasto cinco minutos después no rompe nada. No justifica montar cola de sincronización, resolución de conflictos e IDs de cliente. Confirma [ADR-006](ADRs.md#adr-006--la-app-requiere-conexión-pwa-instalable-pero-no-offline-first). **Reserva:** si el olvido resulta frecuente, se reabre |
| OD-13 | La interfaz debe declarar que los saldos son estimados | `decision` | DECIDED | **Cumplido del todo el 2026-09-15**: el aviso *"≈ Saldos estimados"* aparece en Inicio y Cuentas, y el **ajuste de saldo** ya está en la interfaz — se toca una cuenta, se escribe el saldo real y se registra un movimiento contra la categoría *Ajustes*. **La deriva queda medida, no escondida**: si Ajustes crece mes a mes, algo se está cargando mal | — |
| OD-14 | El repositorio no tiene remoto ni primer commit | `debt` | DECIDED | **Cerrado el 2026-09-15**: remoto privado en GitHub (`jmarine-sys/kipo`) y 13 commits en `main` con conventional commits. Destraba OD-16. **Reserva:** todavía sin `push` — los commits son locales |
| OD-15 | ¿Un proyecto Supabase pausado revive solo o exige clic manual? | `risk` | DECIDED | **VERIFICADO 2026-09-15, y es la peor de las dos opciones: la restauración es MANUAL.** Textual de la doc oficial: *"You can restore paused projects from the Supabase dashboard"* — no documenta ningún despertar automático. No cambia [ADR-007](ADRs.md#adr-007--el-backend-es-supabase), cambia cómo se opera: tras 7 días sin uso alguien tiene que entrar al panel | — |
| OD-16 | Sin backups automáticos en el plan gratuito de Supabase | `debt` | OPEN | **El flujo ya existe** (`.github/workflows/backup.yml`): vuelca a diario, **restaura en una base limpia y comprueba las 11 tablas** antes de guardar, conserva los últimos 30. **Falta un solo paso del usuario**: cargar el secreto `SUPABASE_DB_URL` en GitHub. Hasta entonces el historial no tiene red | Nada técnico. Un secreto |
| OD-17 | Los CEDEARs mezclan dos fuentes de rendimiento en un solo precio | `decision` | OPEN | Un CEDEAR cotiza en ARS y su precio incorpora el **CCL implícito**: sube si sube la acción en USD **o** si sube el CCL. Valuarlo con MEP ([ADR-011](ADRs.md#adr-011--la-fuente-de-cotización-es-una-propiedad-de-la-cuenta-no-de-la-fecha)) responde *"cuántos dólares saco si vendo"*, no *"cuánto rindió el activo"*. Además tienen **ratio de conversión** que puede cambiar. **Falta decidir** si se modelan con ratio + precio del subyacente o con precio ARS + CCL | Medición honesta del rendimiento de Balanz (etapa 5-6) |
| OD-18 | Cómo se modela una cuenta remunerada | `decision` | DECIDED | **Es una cuenta bancaria, no una inversión** — corrección del propio usuario → [ADR-013](ADRs.md#adr-013--la-cuenta-remunerada-es-una-cuenta-bancaria-su-interés-es-un-ingreso-mensual). Interés como ingreso mensual. Reencuadró la taxonomía entera → [ADR-012](ADRs.md#adr-012--las-cuentas-se-clasifican-por-cómo-se-valúan-no-por-cómo-las-llama-el-banco). **Reserva:** simplificación deliberada — técnicamente es un FCI con cuotapartes | — |
| OD-19 | Vencimientos de plazo fijo y gastos recurrentes son la misma funcionalidad | `decision` | DECIDED | **Se unifican** en `scheduled_event` → [ADR-016](ADRs.md#adr-016--los-vencimientos-y-los-gastos-recurrentes-comparten-una-sola-tabla). **Reserva:** `frequency` queda en null para los vencimientos — una columna que no aplica a la mitad de las filas, acotada por `CHECK` | — |
| OD-20 | Método de costo para la ganancia realizada | `decision` | OPEN | Al vender un activo, la ganancia realizada es precio de venta menos **costo de compra** — pero con compras a distintos precios hay que elegir FIFO o promedio ponderado, y dan números distintos. **No afecta al esquema**: ambos se reconstruyen del historial de entries ([modelo-de-datos.md](modelo-de-datos.md) §5.8). **Falta decidir** cuál, y la app debe poder explicar el número que muestre | Etapa 6 (rendimiento) |
| OD-21 | La base no puede validar que un tipo de cambio sea razonable | `risk` | OPEN | **Mitigado a medias**: el formulario de cambio ahora muestra el **tipo de cambio implícito** mientras tipeás, así un error de orden de magnitud se ve. Pero mostrar no es validar: falta comparar contra la última `fx_rate` conocida y pedir confirmación si se aparta. Sigue abierto | Calidad de los datos del usuario |
| OD-22 | Nada impide correr el reseteo después de la puesta en marcha | `risk` | OPEN | [ADR-018](ADRs.md#adr-018--la-puesta-en-marcha-separa-dos-regímenes-de-datos) define dos regímenes de datos, pero **la línea la marca una persona, no el sistema**: no hay bandera de producción en la base. `reset_ledger.sql` con su confirmación explícita borra todo, el día que sea. La mitigación descartada por ahora es una bandera `is_production` en el libro. **Se vuelve real el día de la puesta en marcha**, no antes | Todos los datos, a partir de la puesta en marcha |

---

## The state of the project, read off the register

Actualizado 2026-09-15 (duodécima revisión). Veintidós ítems: **14 `DECIDED`**, **8 `OPEN`**,
**0 `LEANING`** y **0 `NEEDS-INPUT`**.

**El MVP está escrito.** Diecinueve decisiones en [ADRs.md](ADRs.md), el esquema en
[modelo-de-datos.md](modelo-de-datos.md), cinco migraciones verificadas contra PostgreSQL 16, y una
aplicación SvelteKit con seis pantallas que pasa el chequeo de tipos salvo por las dos variables de
entorno que faltan. Lo único que impide ejecutarla es que no existe todavía un proyecto de Supabase.

OD-13 cerró del todo: además del aviso de saldos estimados, el **ajuste de saldo** ya está en la
interfaz — la deriva queda medida contra la categoría *Ajustes*, no escondida. OD-21 quedó
**mitigado a medias**: el formulario muestra el tipo de cambio implícito mientras se tipea, pero
mostrar no es validar.

De los diez `OPEN`, ninguno impide usar la aplicación:

- **Etapa 5-6, no tocan el esquema (4):** OD-06 precios, OD-17 el CCL de los CEDEARs, OD-20 método de
  costo, OD-21 plausibilidad del tipo de cambio.
- **Riesgo solo evaluable con uso real (4):** OD-10 pausa por inactividad, OD-11 la fricción de la
  tarjeta, OD-12 la apuesta de online-only, OD-22 el reseteo tras la puesta en marcha.
- **Deuda (1):** OD-14 cerró —hay remoto privado y 13 commits— y con eso **OD-16 quedó a un solo paso
  del usuario**: cargar el secreto `SUPABASE_DB_URL` en GitHub. El flujo de respaldo ya está escrito y
  se verifica a sí mismo restaurando.

---

## How it is maintained — the propagation duty

> **Downward:** if a document contradicts [ADRs.md](ADRs.md) or this register, **the
> register wins.**
>
> **Upward:** if you discover something the register does not have, **the finding goes back into the
> register in the same change. Not later.**

If the second half is not honoured, the register's authority is paper.

**And it is not a phase at the end: it is a condition of done.** A phase gets skipped under delivery
pressure, which is exactly the problem this register exists to solve.
