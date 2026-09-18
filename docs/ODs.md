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
| OD-02 | Framework de frontend y hosting estático | `decision` | DECIDED | **SvelteKit + adapter-static en modo SPA** → [ADR-017](ADRs.md#adr-017--el-frontend-es-sveltekit-con-adapter-static-en-modo-spa). El hosting, que se había dejado abierto a propósito, cerró el 2026-09-15 en **Cloudflare Workers con activos estáticos** → [ADR-021](ADRs.md#adr-021--el-hosting-es-cloudflare-workers-sirviendo-solo-activos-estáticos). **Reserva:** Pages quedó descartado por decisión del propio Cloudflare, no nuestra |
| OD-03 | Migración del histórico de la planilla | `decision` | DECIDED | **No se migra** → [ADR-015](ADRs.md#adr-015--no-se-migra-el-histórico-de-la-planilla). **Cerrado del todo el 2026-09-15**: el usuario tampoco quiere aportar filas de muestra — *"no quiero tomarla como ejemplo para este nuevo desarrollo"*. **Reserva:** el modelo se valida entonces solo contra los 13 casos de uso de [modelo-de-datos.md](modelo-de-datos.md) §5 y contra el uso real, no contra datos históricos | — |
| OD-04 | Qué tipo de cambio se usa y si se guarda el real de cada operación | `decision` | DECIDED | El de la operación **se deduce de los montos** → [ADR-010](ADRs.md#adr-010--el-tipo-de-cambio-de-una-operación-se-deduce-de-sus-montos-no-se-guarda). El de valuación **es propiedad de la cuenta** → [ADR-011](ADRs.md#adr-011--la-fuente-de-cotización-es-una-propiedad-de-la-cuenta-no-de-la-fecha). Los CEDEARs, que eran la excepción, cerraron en [ADR-024](ADRs.md#adr-024--un-cedear-se-mide-al-ccl-porque-es-el-dólar-que-su-propio-precio-lleva-adentro) — ver OD-17 | — |
| OD-05 | Qué instrumentos de inversión tiene realmente | `decision` | DECIDED | Inventario 2026-09-15: **CEDEARs** (Balanz), **cripto** (Binance) y **cuentas remuneradas** (Mercado Pago). Son **tres mecánicas distintas**, no tres ejemplos de lo mismo. Abre OD-17 y OD-18 | Etapa 5 — desbloqueada |
| OD-06 | Precios de activos: carga manual o automática | `decision` | DECIDED | **Automática**, y desde el 2026-09-16 **construida**: [ADR-025](ADRs.md#adr-025--los-precios-se-traen-solos-todos-los-días-porque-el-de-hoy-no-se-recupera-mañana). Estuvo tres horas decidida y sin existir, que es como no estar decidida. **No aplica a los plazos fijos**: no cotizan, devengan. La carga manual queda como respaldo para lo que ninguna fuente cubre | — |
| OD-07 | Invariante de suma cero en transacciones multi-moneda | `decision` | DECIDED | **Suma cero por unidad, salvo intercambios**, donde las dos unidades quedan relacionadas por el cociente de sus montos → [ADR-010](ADRs.md#adr-010--el-tipo-de-cambio-de-una-operación-se-deduce-de-sus-montos-no-se-guarda). **Reserva:** vale para exactamente 2 unidades; con 3 o más hay que rechazar la transacción, no suponer que no pasa | Modelo de datos — **desbloqueado** |
| OD-08 | Método de autenticación | `decision` | DECIDED | Email+contraseña, Google y TOTP opcional — los tres → [ADR-008](ADRs.md#adr-008--la-autenticación-ofrece-email-contraseña-google-y-totp-opcional). **Reserva:** tres caminos de acceso son tres cosas que probar y mantener | — |
| OD-09 | Moneda de medición del rendimiento | `decision` | DECIDED | **USD** → [ADR-009](ADRs.md#adr-009--el-rendimiento-de-las-inversiones-se-mide-en-usd). **Reserva:** el dólar tampoco es vara estable en términos reales; medir en USD es mejor que en ARS nominal, no es medir en términos reales | — |
| OD-10 | El free tier elegido puede pausar el proyecto por inactividad | `risk` | OPEN | **Riesgo aceptado, con el alcance ya medido.** Supabase pausa tras 7 días sin actividad y **la restauración es manual** (OD-15). Con uso diario de 3 personas no se dispara; se dispara tras vacaciones o abandono. Textual de la doc: *"Upgrade to Pro to guarantee that we won't pause your project"* — US$25/mes, hoy no se justifica. **No se mitiga con pings artificiales**: si nadie la usa una semana, el problema es que nadie la usa | Nada. Se revisa con uso real |
| OD-11 | La fricción de cargar cada consumo con tarjeta puede matar la adopción | `risk` | OPEN | Consecuencia asumida de [ADR-004](ADRs.md#adr-004--la-tarjeta-de-crédito-se-modela-como-cuenta-de-pasivo). El proyecto existe porque cargar era costoso, y esta decisión lo aumenta. Mitigación en interfaz, no en modelo. **Solo se puede evaluar con uso real** | Revisión post-MVP |
| OD-12 | La apuesta de online-only puede fallar en el caso de uso central | `risk` | DECIDED | **Riesgo aceptado explícitamente por el usuario el 2026-09-15**, y con buen argumento: si justo en ese momento no hay señal, **se espera** — registrar el gasto cinco minutos después no rompe nada. No justifica montar cola de sincronización, resolución de conflictos e IDs de cliente. Confirma [ADR-006](ADRs.md#adr-006--la-app-requiere-conexión-pwa-instalable-pero-no-offline-first). **Reserva:** si el olvido resulta frecuente, se reabre |
| OD-13 | La interfaz debe declarar que los saldos son estimados | `decision` | DECIDED | **Cumplido del todo el 2026-09-15**: el aviso *"≈ Saldos estimados"* aparece en Inicio y Cuentas, y el **ajuste de saldo** ya está en la interfaz — se toca una cuenta, se escribe el saldo real y se registra un movimiento contra la categoría *Ajustes*. **La deriva queda medida, no escondida**: si Ajustes crece mes a mes, algo se está cargando mal | — |
| OD-14 | El repositorio no tiene remoto ni primer commit | `debt` | DECIDED | **Cerrado el 2026-09-15**: remoto privado en GitHub (`jmarine-sys/kipo`) y 13 commits en `main` con conventional commits. Destraba OD-16. **Reserva:** todavía sin `push` — los commits son locales |
| OD-15 | ¿Un proyecto Supabase pausado revive solo o exige clic manual? | `risk` | DECIDED | **VERIFICADO 2026-09-15, y es la peor de las dos opciones: la restauración es MANUAL.** Textual de la doc oficial: *"You can restore paused projects from the Supabase dashboard"* — no documenta ningún despertar automático. No cambia [ADR-007](ADRs.md#adr-007--el-backend-es-supabase), cambia cómo se opera: tras 7 días sin uso alguien tiene que entrar al panel | — |
| OD-16 | Sin backups automáticos en el plan gratuito de Supabase | `debt` | DECIDED | **Cerrado el 2026-09-15, y funcionando de verdad**: el flujo corrió solo, volcó la base, la restauró en una base limpia, comprobó las tablas y commiteó `backups/kipo-2026-09-15.sql.gz` (50 KB). El volcado contiene **las 11 políticas de RLS**, así que restaurar devuelve también el aislamiento. Conserva los últimos 30 días. **Reserva:** el volcado vive en el mismo repositorio; si se perdiera la cuenta de GitHub se pierden ambos |
| OD-17 | Los CEDEARs mezclan dos fuentes de rendimiento en un solo precio | `decision` | DECIDED | Se miden al **CCL**, que es el dólar que su propio precio lleva adentro → [ADR-024](ADRs.md#adr-024--un-cedear-se-mide-al-ccl-porque-es-el-dólar-que-su-propio-precio-lleva-adentro). La división cancela el CCL y deja el rendimiento de la acción, **sin precio del exterior ni ratio**. Al revisarlo apareció que [ADR-011](ADRs.md#adr-011--la-fuente-de-cotización-es-una-propiedad-de-la-cuenta-no-de-la-fecha) estaba declarado y no cumplido: las vistas convertían todo con la fuente del libro. **Reserva:** el número ya no dice cuántos dólares se sacan al vender — esa es otra pregunta | — |
| OD-18 | Cómo se modela una cuenta remunerada | `decision` | DECIDED | **Es una cuenta bancaria, no una inversión** — corrección del propio usuario → [ADR-013](ADRs.md#adr-013--la-cuenta-remunerada-es-una-cuenta-bancaria-su-interés-es-un-ingreso-mensual). Interés como ingreso mensual. Reencuadró la taxonomía entera → [ADR-012](ADRs.md#adr-012--las-cuentas-se-clasifican-por-cómo-se-valúan-no-por-cómo-las-llama-el-banco). **Reserva:** simplificación deliberada — técnicamente es un FCI con cuotapartes | — |
| OD-19 | Vencimientos de plazo fijo y gastos recurrentes son la misma funcionalidad | `decision` | DECIDED | **Se unifican** en `scheduled_event` → [ADR-016](ADRs.md#adr-016--los-vencimientos-y-los-gastos-recurrentes-comparten-una-sola-tabla). **Reserva:** `frequency` queda en null para los vencimientos — una columna que no aplica a la mitad de las filas, acotada por `CHECK` | — |
| OD-20 | Método de costo para la ganancia realizada | `decision` | OPEN | Al vender un activo, la ganancia realizada es precio de venta menos **costo de compra** — pero con compras a distintos precios hay que elegir FIFO o promedio ponderado, y dan números distintos. **No afecta al esquema**: ambos se reconstruyen del historial de entries ([modelo-de-datos.md](modelo-de-datos.md) §5.8). **Falta decidir** cuál, y la app debe poder explicar el número que muestre | Etapa 6 (rendimiento) |
| OD-21 | La base no puede validar que un tipo de cambio sea razonable | `risk` | DECIDED | **Cerrado el 2026-09-18.** La base no puede: [ADR-010](ADRs.md#adr-010--el-tipo-de-cambio-de-una-operación-se-deduce-de-sus-montos-no-se-guarda) hace del tipo de cambio un cociente, y todo cociente es válido. La comprobación vive en `plausibilidad.ts` —puro y con 10 pruebas sobre cotizaciones reales del respaldo— y compara el implícito contra la banda del día. **Avisa, no bloquea**: un arreglo por fuera del mercado puede ser real y el usuario es quien sabe; pide una confirmación que se invalida sola si cambiás el monto. **Reserva:** sin cotizaciones cargadas no hay referencia y el aviso no aparece | — |
| OD-22 | Nada impide correr el reseteo después de la puesta en marcha | `risk` | OPEN | [ADR-018](ADRs.md#adr-018--la-puesta-en-marcha-separa-dos-regímenes-de-datos) define dos regímenes de datos, pero **la línea la marca una persona, no el sistema**: no hay bandera de producción en la base. `reset_ledger.sql` con su confirmación explícita borra todo, el día que sea. La mitigación descartada por ahora es una bandera `is_production` en el libro. **Se vuelve real el día de la puesta en marcha**, no antes | Todos los datos, a partir de la puesta en marcha |
| OD-23 | Las cuotas no tienen calendario: solo se conoce el saldo total de deuda | `decision` | OPEN | **Verificado 2026-09-15**: una compra en cuotas se registra como un solo gasto contra la tarjeta y los pagos del resumen bajan la deuda — funciona sin cambios. Pero el saldo dice *cuánto* debés, no *cuándo*: con varias compras en cuotas no se puede anticipar el resumen del mes que viene. **Una cuota futura es un evento futuro con fecha y monto conocidos**, o sea el mismo objeto de [ADR-016](ADRs.md#adr-016--los-vencimientos-y-los-gastos-recurrentes-comparten-una-sola-tabla): entra gratis en `scheduled_event` | Etapa 3, junto con recurrentes y vencimientos |
| OD-24 | Una compra en cuotas distorsiona el resultado del mes | `risk` | OPEN | El mes de la compra se lleva el total y los siguientes se ven artificialmente buenos (verificado: octubre −120.000 por una heladera de la que se pagaron 10.000). Es **honesto** —ese día el patrimonio bajó 120.000— pero distorsiona la comparación mes contra mes, que es el corazón de la app. Agravante local: con inflación alta el total nominal **sobreestima** el costo real de las cuotas sin interés. **Sin decidir** si se muestra el resultado de otra forma, o solo se aclara | Lectura del resultado mensual. Solo evaluable con uso real |
| OD-25 | Un preview apunta a la base de PRODUCCIÓN, no a un sandbox | `risk` | OPEN | Los builds de ramas no productivas usan **las mismas variables de entorno** que producción, así que una rama de prueba escribe en la base real. Sirve para probar interfaz; **no** para probar migraciones ni nada destructivo. Un sandbox de verdad exigiría un segundo proyecto de Supabase con sus propias variables — hoy desproporcionado. **Se vuelve real el día que se pruebe algo que escribe distinto** | Integridad de los datos reales al experimentar |
| OD-29 | Gráficos de evolución y distribución | `decision` | OPEN | **Diferido explícitamente por el usuario**: primero los filtros, que ya están (OD-28). Un gráfico necesita además 3 a 6 meses de datos para decir algo — hoy hay uno. **Sin decidir** cuáles: la regla del brief es que cada visualización exista porque ayuda a decidir algo, no por adorno | Etapa 4 |
| OD-30 | Qué fuente de cotizaciones usar, y si se guarda la serie | `decision` | DECIDED | **BYMA** directo para CEDEARs en pesos y **Binance** para cripto, ambas sin clave y verificadas en vivo el 2026-09-16 → [ADR-025](ADRs.md#adr-025--los-precios-se-traen-solos-todos-los-días-porque-el-de-hoy-no-se-recupera-mañana). **Sí se guarda la serie**, una fila por día: es la única de las dos preguntas que no se puede contestar después. data912 queda anotada como respaldo si BYMA cierra el endpoint | — |
| OD-31 | El historial de precios no se puede reconstruir hacia atrás | `risk` | DECIDED | **Detenido el 2026-09-16** con el flujo diario → [ADR-025](ADRs.md#adr-025--los-precios-se-traen-solos-todos-los-días-porque-el-de-hoy-no-se-recupera-mañana). **Corregido el 2026-09-18:** no era parejo para todos los activos. Binance publica el cierre diario de cualquier fecha (`/api/v3/klines`, verificado), así que **cripto SÍ se recupera** con `precios.mjs desde <fecha>`. BYMA no: su histórico da 401. **Reserva, ahora acotada:** lo irrecuperable son los CEDEARs y las acciones anteriores al 2026-09-16 | OD-29, que necesita esta serie |
| OD-32 | Instrumentos ajustados por inflación (plazo fijo UVA, bonos CER) | `decision` | OPEN | **Anotado como mejora futura** por el usuario el 2026-09-16. Hoy se pueden cargar como plazo fijo con monto final estimado y corregir al vencer, **con una reserva seria**: durante todo el plazo el patrimonio queda subestimado, y en un UVA a doce meses con inflación alta ese salto es enorme. La salida correcta ya se entrevé: un UVA es en realidad **unidades de UVA por su valor del día**, o sea la familia `market` disfrazada de plazo fijo, y modelarlo así haría que el patrimonio se actualice solo | Exactitud del patrimonio si alguna vez abre uno |
| OD-33 | El rendimiento se mide por posición, no por portafolio | `decision` | DECIDED | **Portafolio explícito**, firmado por el usuario el 2026-09-16 → [ADR-026](ADRs.md#adr-026--el-portafolio-es-el-borde-es-flujo-solo-lo-que-lo-cruza). Una entidad `portfolio` y las cuentas apuntan a ella; pertenecer es opcional, que es lo que lo distingue de agrupar por `institution`. Es flujo solo lo que tiene la contraparte afuera, y eso cierra los tres agujeros sin casos especiales. **Reserva:** una cuenta que se olvida de apuntar a su portafolio no rompe nada, mide mal en silencio — mismo modo de falla que [ADR-025](ADRs.md#adr-025--los-precios-se-traen-solos-todos-los-días-porque-el-de-hoy-no-se-recupera-mañana) | — |
| OD-34 | Una pantalla terminada puede quedar sin camino, y nadie se entera | `debt` | DECIDED | **Tercera vez que pasa** (recurrentes, y la cartera a tres clicks detrás de *Cuentas*). La auditoría anterior contaba **enlaces por ruta**, que no es lo mismo que recorrer caminos: un enlace puede estar dentro de un `{#if}` que nadie cumple, o colgar de una pantalla a la que tampoco se llega. `scripts/navegacion.mjs` recorre el grafo desde la barra y falla si algo queda a más de 2 clicks; corre dentro de `verificar.sh`. **Verificado por mutación:** sacando la pestaña Cartera, sale 1 | — |
| OD-35 | La app habla como quien la construyó, no como quien la usa | `risk` | DECIDED | **Primera pasada hecha el 2026-09-18**, sobre lo que engaña y lo que está siempre a la vista. **«Ajustes» era lo peor**: en la pantalla principal, con el significado de *Configuración* en cualquier otra app — y encima escrito a mano, así que renombrar la categoría no cambiaba el rótulo. Ahora Inicio muestra **el nombre real** de la categoría, que en los libros nuevos nace como *Ajuste de saldo*. También: la pestaña *Cartera* → **Inversiones**, *Posiciones* → **Lo que tenés**, *Portafolios* → **Dónde invertís**, *Nueva obligación* → **Algo que se repite**, *Capital* → **Cuánto ponés**. **Reserva:** los formularios de inversión siguen en jerga (*Moneda de cotización*, *Acción que representa*) — se dejaron porque los ve solo quien invierte | — |
| OD-36 | No hay forma de compartir un libro entre dos personas | `debt` | OPEN | `ledger_member` está en el esquema desde el día uno, con sus políticas de RLS, y **en la interfaz no hay nada**: ni invitar, ni aceptar, ni ver quién más está. Hoy cada usuario queda con su libro aislado, que es lo que se buscaba para este caso. **Falta decidir** si alguna vez se abre, y si un invitado puede borrar o solo cargar | Uso compartido (pareja, familia) |
| OD-37 | Las cuentas no se agrupan por institución | `decision` | DECIDED | **Un interruptor, no una elección**: `/cuentas` ofrece *Por tipo* —que contesta «¿cuánto puedo gastar hoy?», el punto 8 del brief— y *Por banco* —«¿cuánto tengo en Macro?»—. El campo `institution` ya existía **y `account_balance` ya lo exponía**: no hizo falta nada de esquema. Contra el texto libre, un `datalist` con los bancos ya usados. **Sin entidad `institution` por ahora**: se agregaría el día que haga falta renombrar en un lugar o darle una fuente de dólar propia. **No se confunde con `portfolio` (ADR-026):** institución es *dónde está*, portafolio es *qué se mide junto* | — |
| OD-38 | Las fechas de la agenda se cargan una por una, sin atajos | `decision` | OPEN | **Propuesto por el usuario el 2026-09-18**: atajos tipo *primera quincena* o *fin de mes* al agendar. No ensucia el diseño —nadie piensa *«el 2026-10-31»*, piensa *«a fin de mes»*— pero **verificado el 2026-09-18 contra PostgreSQL 16**, un atajo que solo escribe una fecha miente: `31-ene + 1 mes` da `28-feb`, y de ahí en adelante `28-mar`, `28-abr`. **Se degrada al 28 y no vuelve nunca.** **Falta decidir** entre atajos que solo escriben la fecha (gratis, honestos salvo el último día del mes) o una regla de verdad en `scheduled_event` —*último día*, *día 15*— que sobreviva al avance | Fidelidad de los vencimientos a fin de mes |
| OD-26 | El arte del ícono trae su propio fondo: debería ser una capa aparte | `decision` | DECIDED | **Resuelto el 2026-09-16.** Se quitan del vector las dos capas de relleno —el rectángulo blanco y el cuadrado menta— y se compone de nuevo: el bolsillo con la moneda es el frente, el menta es fondo generado. Verificado aplicando el recorte circular **al 80% y al 100%**: no se corta nada. El favicon pasa además a ser cuadrado y recortado al dibujo, porque el original es vertical y a 16 px eso dejaba aire donde menos lugar hay | — |
| OD-27 | La lista de movimientos corta los nombres de categoría | `decision` | DECIDED | **Resuelto el 2026-09-15.** Se muestra solo la subcategoría y la madre pasa a ser un punto de color, derivado de su nombre con un hash estable. Se quitó además el texto *"no afecta el resultado"* de cada renglón: el color del monto ya lo dice, y el lugar de enseñarlo es el formulario, no una lista que se lee cientos de veces | — |
| OD-28 | Faltan filtros en movimientos | `decision` | DECIDED | **Resuelto el 2026-09-16.** Filtro por **período** (mes con navegación, 3 y 6 meses, año, o entre dos fechas) y por **categoría madre**, con selección múltiple y el mismo código de color de la lista. Muestra cuántos movimientos quedan y cuánto suman. **Los gráficos NO entran acá**: quedan en OD-29 | — |

---

## The state of the project, read off the register

Actualizado 2026-09-18 (vigesimoquinta revisión). Treinta y ocho ítems: **27 `DECIDED`**,
**11 `OPEN`**, **0 `LEANING`** y **0 `NEEDS-INPUT`**.

**Veintisiete decisiones** en [ADRs.md](ADRs.md), veinte migraciones verificadas contra PostgreSQL 16
con 115 aserciones, y una aplicación SvelteKit con trece pantallas, en producción y en uso.

El 2026-09-18 la usó por primera vez **alguien que no la había construido** —el padre del usuario— y
se perdió. Ese solo hecho produjo más hallazgos que cualquier auditoría: el alta imponía veinte
categorías ajenas, no existía ninguna pantalla de primer uso, y la aplicación habla en vocabulario de
contador. Nada de eso lo veían las pruebas, **porque todas preguntan si lo construido funciona y
ninguna pregunta si se entiende**.

De los 11 `OPEN`, ninguno impide usar la aplicación:

- **Esperan datos que todavía no existen (2):** OD-20 método de costo, OD-29 gráficos.
- **Riesgo solo evaluable con uso real (4):** OD-10 pausa por inactividad, OD-11 la fricción de la
  tarjeta, OD-22 el reseteo tras la puesta en marcha, OD-25 el preview que apunta a producción.
- **Diferidos por el usuario (3):** OD-23 y OD-24 las cuotas, OD-32 los instrumentos UVA.
- **Propuesto por el usuario usándola (1):** OD-38, atajos de fecha en la agenda.
- **Deuda: una.** OD-36, compartir un libro: el esquema lo soporta y la interfaz no lo expone.

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
