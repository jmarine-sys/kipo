# Architecture decisions (ADR)

One entry per decision, with **the why and the evidence** — not just the outcome.

**A closed entry is never edited.** If a decision changes, write a new one that replaces it and mark
the old one. **Exception: an entry marked `Open` is a living document until it closes** — load
measurements into it, correct its numbers; it becomes immutable only when it closes.

**Format:** Context -> Decision -> Consequences -> Evidence -> **Verified against what already exists**.

| Field | What it carries |
|---|---|
| **Context** | what pressure existed. **Ideally not a preference but a concrete failure that already happened** |
| **Decision** | what was decided, in the present tense, in one sentence |
| **Consequences** | what is now true, **including the uncomfortable part** |
| **Rejected alternatives** | **mandatory.** It is the field that stops 80% of repeated arguments |
| **Verified against what already exists** | the command you ran and what it returned, or *"not applicable"* with its reason |

**Write ADRs backwards only**, about what has already been argued twice. A preventive ADR of a
decision nobody made is fiction, and an agent will believe it.

| # | Decision | Status |
|---|---|---|
| [ADR-001](#adr-001--el-modelo-registra-origen-y-destino-de-cada-movimiento-partida-doble-oculta) | El modelo registra origen y destino de cada movimiento (partida doble oculta) | Accepted |
| [ADR-002](#adr-002--cada-usuario-ve-solo-sus-propios-datos) | Cada usuario ve solo sus propios datos | Accepted |
| [ADR-003](#adr-003--toda-fila-del-dominio-pertenece-a-un-libro-ledger-no-a-un-usuario) | Toda fila del dominio pertenece a un libro (`ledger`), no a un usuario | Accepted |
| [ADR-004](#adr-004--la-tarjeta-de-crédito-se-modela-como-cuenta-de-pasivo) | La tarjeta de crédito se modela como cuenta de pasivo | Accepted |
| [ADR-005](#adr-005--los-saldos-son-aproximados-no-hay-conciliación-bancaria) | Los saldos son aproximados: no hay conciliación bancaria | Accepted |
| [ADR-006](#adr-006--la-app-requiere-conexión-pwa-instalable-pero-no-offline-first) | La app requiere conexión: PWA instalable pero no offline-first | Accepted |
| [ADR-007](#adr-007--el-backend-es-supabase) | El backend es Supabase | Accepted |
| [ADR-008](#adr-008--la-autenticación-ofrece-email-contraseña-google-y-totp-opcional) | La autenticación ofrece email+contraseña, Google y TOTP opcional | Accepted |
| [ADR-009](#adr-009--el-rendimiento-de-las-inversiones-se-mide-en-usd) | El rendimiento de las inversiones se mide en USD | Accepted |
| [ADR-010](#adr-010--el-tipo-de-cambio-de-una-operación-se-deduce-de-sus-montos-no-se-guarda) | El tipo de cambio de una operación se deduce de sus montos, no se guarda | Accepted |
| [ADR-011](#adr-011--la-fuente-de-cotización-es-una-propiedad-de-la-cuenta-no-de-la-fecha) | La fuente de cotización es una propiedad de la cuenta, no de la fecha | Accepted |
| [ADR-012](#adr-012--las-cuentas-se-clasifican-por-cómo-se-valúan-no-por-cómo-las-llama-el-banco) | Las cuentas se clasifican por cómo se valúan, no por cómo las llama el banco | Accepted |
| [ADR-013](#adr-013--la-cuenta-remunerada-es-una-cuenta-bancaria-su-interés-es-un-ingreso-mensual) | La cuenta remunerada es una cuenta bancaria; su interés es un ingreso mensual | Accepted |
| [ADR-014](#adr-014--el-plazo-fijo-reconoce-su-interés-al-vencimiento) | El plazo fijo reconoce su interés al vencimiento | Accepted |
| [ADR-015](#adr-015--no-se-migra-el-histórico-de-la-planilla) | No se migra el histórico de la planilla | Accepted |
| [ADR-016](#adr-016--los-vencimientos-y-los-gastos-recurrentes-comparten-una-sola-tabla) | Los vencimientos y los gastos recurrentes comparten una sola tabla | Accepted |
| [ADR-017](#adr-017--el-frontend-es-sveltekit-con-adapter-static-en-modo-spa) | El frontend es SvelteKit con adapter-static en modo SPA | Accepted |
| [ADR-018](#adr-018--la-puesta-en-marcha-separa-dos-regímenes-de-datos) | La puesta en marcha separa dos regímenes de datos | Accepted |
| [ADR-019](#adr-019--registrar-un-movimiento-es-una-función-de-base-no-dos-inserciones-del-cliente) | Registrar un movimiento es una función de base, no dos inserciones del cliente | Accepted |
| [ADR-020](#adr-020--los-permisos-del-data-api-son-explícitos-y-anon-no-tiene-ninguno) | Los permisos del Data API son explícitos, y `anon` no tiene ninguno | Accepted |
| [ADR-021](#adr-021--el-hosting-es-cloudflare-workers-sirviendo-solo-activos-estáticos) | El hosting es Cloudflare Workers, sirviendo solo activos estáticos | Accepted |
| [ADR-022](#adr-022--el-patrimonio-incluye-solo-activos-financieros) | El patrimonio incluye solo activos financieros | Accepted |
| [ADR-023](#adr-023--la-unidad-de-medida-es-un-parámetro-dólares-o-poder-adquisitivo) | La unidad de medida es un parámetro: dólares o poder adquisitivo | Accepted |
| [ADR-024](#adr-024--un-cedear-se-mide-al-ccl-porque-es-el-dólar-que-su-propio-precio-lleva-adentro) | Un CEDEAR se mide al CCL, porque es el dólar que su propio precio lleva adentro | Accepted |
| [ADR-025](#adr-025--los-precios-se-traen-solos-todos-los-días-porque-el-de-hoy-no-se-recupera-mañana) | Los precios se traen solos todos los días, porque el de hoy no se recupera mañana | Accepted |
| [ADR-026](#adr-026--el-portafolio-es-el-borde-es-flujo-solo-lo-que-lo-cruza) | El portafolio es el borde: es flujo solo lo que lo cruza | Accepted |
| [ADR-027](#adr-027--el-alta-siembra-estructura-no-taxonomía-y-la-puesta-en-marcha-pregunta-el-resto) | El alta siembra estructura, no taxonomía, y la puesta en marcha pregunta el resto | Accepted |
| [ADR-028](#adr-028--el-libro-activo-vive-en-la-base-y-compartir-uno-se-hace-por-código) | El libro activo vive en la base, y compartir uno se hace por código | Accepted |
| [ADR-029](#adr-029--la-fuente-de-precios-locales-es-data912-con-byma-de-respaldo-y-el-precio-se-guarda-como-se-cotiza) | La fuente de precios locales es data912, con BYMA de respaldo, y el precio se guarda como se cotiza | Accepted |
| [ADR-030](#adr-030--qué-tipo-es-cómo-se-llama-y-dónde-está-son-tres-preguntas-distintas) | Qué tipo es, cómo se llama y dónde está son tres preguntas distintas | Accepted |
| [ADR-031](#adr-031--una-cuenta-puede-estar-en-varias-carteras-y-la-del-broker-se-arma-sola) | Una cuenta puede estar en varias carteras, y la del broker se arma sola | Accepted |
| [ADR-032](#adr-032--aportar-a-otro-libro-es-gastar-y-son-dos-movimientos-uno-por-libro) | Aportar a otro libro es gastar, y son dos movimientos, uno por libro | Accepted |

---

## ADR-001 — El modelo registra origen y destino de cada movimiento (partida doble oculta)

**Context.** El sistema que se está reemplazando es una hoja de cálculo con una tabla plana de
movimientos y una columna `categoría`. Ese diseño falla de forma concreta y verificable en cuatro
casos que el usuario usa a diario:

1. La fórmula mensual de la planilla es `Ingresos - Gastos - Ahorros - Inversiones = resultado`.
   Esa fórmula **resta el ahorro del resultado**: un mes en que se ahorra $300.000 más produce un
   "resultado" $300.000 peor. Mide caja sobrante, no resultado.
2. La columna `categoría` mezcla dos ejes ortogonales — el TIPO de operación (`Gastos fijos`,
   `Ahorros`) y el CONCEPTO (`Supermercado`, `Alquiler`) — por lo que no se puede preguntar cuánto
   se transfirió a ahorro sin contaminar cuánto se gastó.
3. Comprar dólares se registra como gasto, cuando no cambia el patrimonio.
4. El pago del resumen de la tarjeta y las compras con esa tarjeta se cuentan ambos como gasto,
   duplicando el gasto real.

**Decision.** Todo movimiento tiene origen y destino explícitos: una transacción agrupa dos o más
líneas (`Entry`) que apuntan a una cuenta o a una categoría, y la interfaz nunca expone ese
mecanismo.

**Consequences.**
- Es imposible registrar algo inconsistente: la plata no aparece ni desaparece.
- Se separan tres preguntas que la planilla mezclaba: flujo (¿de dónde vino?), stock (¿cuánto tengo
  y dónde?) y valor (¿cuánto valgo?).
- El patrimonio puede cambiar **sin movimientos** (sube el dólar, sube un activo), lo que obliga a
  una capa de valuación separada: precios y cotizaciones con fecha y fuente.
- Las inversiones se guardan en **unidades**, nunca en monto.
- **La parte incómoda:** es más modelo del que un proyecto de este tamaño aparenta necesitar, y el
  usuario pidió explícitamente no sobrearquitectura. La defensa es que la complejidad está en el
  MODELO, no en la arquitectura ni en la interfaz, y que es la mínima que resuelve los cuatro casos
  de arriba. Además es la decisión **más cara de revertir** de todo el proyecto: cambiarla con dos
  años de historia cargada es migrar toda la historia.

**Rejected alternatives.**
- *Tabla plana con `tipo` + `categoría`* (lo que hace la planilla): más simple de arrancar, y colapsa
  exactamente en los cuatro casos que motivan el reemplazo. Descartada.
- *Contabilidad de partida doble completa* (plan de cuentas, debe/haber, asientos de ajuste,
  balance): correcta y desproporcionada para tres usuarios. Descartada.

**Evidence.** [../analisis-inicial.md](../analisis-inicial.md), secciones 0 y 1 — los siete errores
conceptuales y la tabla de cómo se representa cada operación.

**Verified against what already exists.**

```bash
find /home/jlmarine -maxdepth 4 -type d -iname "*kipo*"   # -> solo el directorio vacío y caches
git -C . status                                            # -> fatal: not a git repository
ls -la                                                     # -> únicamente porposal.md
```

Proyecto greenfield: no hay código, ni esquema, ni historia previa que contradiga esta decisión.
No hay framework ni plataforma que ya resuelva esto — es modelado de dominio, no infraestructura.

---

## ADR-002 — Cada usuario ve solo sus propios datos

**Context.** La aplicación la van a usar aproximadamente tres personas con información financiera
privada. Hacía falta decidir si comparten un libro o no **antes** de diseñar el esquema, porque
afecta el modelo de permisos, las tablas y la interfaz.

**Decision.** Cada usuario accede exclusivamente a sus propios datos; no hay libros compartidos, ni
invitaciones, ni permisos por cuenta.

**Consequences.**
- Una única regla de aislamiento, aplicada **en la base de datos** y no en el código de la
  aplicación: un bug de frontend no puede exponer las finanzas de otra persona.
- Desaparece del MVP el bloque completo de permisos, invitaciones y roles.
- **La parte incómoda:** los tres usuarios **nunca** pueden ver una vista combinada. Si aparece la
  necesidad de finanzas de pareja o familiares, hay que cambiar esta decisión. El costo de ese
  cambio se mitiga con [ADR-003](#adr-003--toda-fila-del-dominio-pertenece-a-un-libro-ledger-no-a-un-usuario), no se elimina.

**Rejected alternatives.**
- *Libro compartido* (los tres ven todo): igual de simple de construir, pero no es lo que el usuario
  quiere hoy.
- *Mixto* (cuentas propias + algunas compartidas): cuesta del orden del triple — modelo de permisos
  por cuenta, invitaciones, y resolver qué muestra el dashboard al mezclar lo propio con lo
  compartido. Descartada por desproporcionada para tres personas.

**Evidence.** [../analisis-inicial.md](../analisis-inicial.md), sección 9 (D-01).

**Verified against what already exists.** *No aplica:* no hay usuarios, ni proveedor de
autenticación elegido, ni esquema. La decisión es previa a todo eso — que es exactamente por qué se
tomó ahora.

---

## ADR-003 — Toda fila del dominio pertenece a un libro (`ledger`), no a un usuario

**Context.** [ADR-002](#adr-002--cada-usuario-ve-solo-sus-propios-datos) aísla a los usuarios, y es
la decisión de las cuatro fundacionales que quedó con deuda futura: si cada fila apunta directamente
al usuario dueño, pasar alguna vez a finanzas compartidas obliga a migrar **todas** las filas de la
base y a rehacer las reglas de acceso.

**Decision.** Las filas del dominio pertenecen a un `ledger` (libro); un `ledger` tiene miembros; al
registrarse, cada usuario obtiene automáticamente su libro personal con un único miembro.

**Consequences.**
- Compartir en el futuro pasa a ser un `INSERT` en la tabla de miembros, no una migración.
- La regla de aislamiento pasa de *"soy el dueño de esta fila"* a *"pertenezco a este libro"*: una
  subconsulta más, la misma garantía.
- **El libro NO existe en la interfaz del MVP.** Si el usuario llega a ver la palabra "libro",
  la decisión falló: es una decisión de esquema, no de producto.
- **La parte incómoda:** es una capa de indirección que hoy no se usa, en un proyecto donde el
  usuario pidió explícitamente no agregar cosas "por si acaso". Se acepta conscientemente porque el
  costo hoy es una tabla con tres filas y un `JOIN`, y el beneficio es convertir la decisión más
  cara de revertir en la más barata.

**Rejected alternatives.**
- *`owner_id` apuntando directo al usuario*: lo más simple que existe y perfectamente coherente con
  el principio de no agregar nada por si acaso. Descartada porque el ahorro de hoy es de una columna
  contra un costo futuro de migrar la base entera — mal negocio incluso si la probabilidad de
  compartir es baja.

**Evidence.** [../analisis-inicial.md](../analisis-inicial.md), sección 10 (D-05).

**Verified against what already exists.** *No aplica:* no hay esquema todavía. Esta decisión existe
precisamente para no tener que verificarla contra datos ya cargados más adelante.

---

## ADR-004 — La tarjeta de crédito se modela como cuenta de pasivo

**Context.** En la planilla original el consumo con tarjeta y el pago del resumen se registran ambos
como gasto, lo que **duplica el gasto real**. Además el momento del gasto y el momento del pago son
distintos — se compra en marzo y se paga en abril — por lo que el gasto queda imputado al mes
equivocado. Es el caso concreto que más rompe la planilla que se está reemplazando.

**Decision.** Cada consumo con tarjeta se registra contra una cuenta de pasivo, con su categoría y
en la fecha en que ocurrió; el pago del resumen es una transferencia entre el banco y ese pasivo.

**Consequences.**
- El gasto queda en su mes y con su categoría: la analítica por categoría funciona.
- **Pagar el resumen no es un gasto**: cancela deuda, el patrimonio no cambia en ese momento.
- El patrimonio resta la deuda de tarjeta pendiente, por lo que deja de estar inflado.
- El tipo de cuenta `liability` entra al MVP; no queda para una etapa posterior.
- **La parte incómoda, y es seria:** obliga a cargar **cada** consumo con tarjeta. El problema
  original que motiva todo el proyecto es **la fricción de carga**, y esta decisión la aumenta. Se
  compensa en la interfaz (cuenta por defecto = última usada, categorías frecuentes, repetir
  movimiento), no en el modelo. Queda registrada como riesgo en
  [ODs.md](ODs.md) — OD-11.

**Rejected alternatives.**
- *Registrar únicamente el pago del resumen*: un movimiento por mes, mínima fricción. Descartada
  porque destruye el detalle por categoría (un renglón de $800.000 "Tarjeta" no informa nada) y
  corre el gasto un mes respecto de cuándo ocurrió.
- *Híbrido — compras grandes en detalle y el resto al bulto*: descartada por reunir lo peor de las
  dos: números que no cierran y una regla que hay que recordar en cada carga.

**Evidence.** [../analisis-inicial.md](../analisis-inicial.md), error 4 y sección 9 (D-02).

**Verified against what already exists.** *No aplica:* no hay código. Se verificó en cambio contra
los datos reales del usuario — la planilla tiene el caso y lo registra mal, que es de dónde sale el
*Context*.

---

## ADR-005 — Los saldos son aproximados: no hay conciliación bancaria

**Context.** Un sistema de finanzas personales puede aspirar a cuadrar al peso con el homebanking o
a ser una estimación razonable. La diferencia no es de precisión sino de **disciplina de carga
diaria exigida al usuario**, y el proyecto existe porque la carga era demasiado costosa.

**Decision.** Los saldos son estimaciones: no se implementa conciliación bancaria, y la interfaz lo
declara explícitamente.

**Consequences.**
- No hace falta mecanismo de conciliación, ni importación de extractos, ni marcado de movimientos
  conciliados en el MVP.
- **La interfaz tiene que decir que los saldos son estimados.** Un número que parece exacto y no lo
  es es peor que no tener número — es el principio de transparencia que pidió el usuario, aplicado.
- Hace falta una válvula de escape barata: un movimiento de **ajuste de saldo** contra una categoría
  `Ajustes`, para corregir la deriva sin inventar movimientos falsos.
- **La parte incómoda:** el patrimonio total que muestre la app **no es auditable**. Cualquier
  conclusión financiera derivada de él arrastra ese margen de error, y eso incluye la tasa de ahorro
  y, más adelante, el rendimiento de las inversiones.

**Rejected alternatives.**
- *Conciliación al peso*: da un patrimonio confiable de verdad. Descartada porque exige cargar
  absolutamente todo con disciplina diaria — exactamente la fricción que hizo fracasar la planilla.

**Evidence.** [../analisis-inicial.md](../analisis-inicial.md), sección 9 (D-03).

**Verified against what already exists.** *No aplica:* no hay interfaz ni esquema todavía.

---

## ADR-006 — La app requiere conexión: PWA instalable pero no offline-first

**Context.** El usuario pidió una PWA instalable desde el celular. "PWA instalable" y "funciona sin
señal" son dos cosas distintas y la segunda cuesta varias veces más: obliga a resolver cola de
sincronización, conflictos de edición e identificadores generados en el cliente. Hacía falta
decidirlo antes del esquema, porque los IDs generados en el cliente cambian el diseño de las tablas.

**Decision.** La aplicación requiere conexión para registrar movimientos; el *service worker* cachea
la interfaz, no los datos.

**Consequences.**
- Sin cola de sincronización, sin resolución de conflictos, sin IDs generados en el cliente.
- La app abre rápido e instala en el celular igual.
- Si no hay señal, la app lo dice claramente en vez de fingir que guardó.
- **La parte incómoda:** el caso de uso central es registrar un gasto parado en la caja del
  supermercado, y ahí puede no haber señal. La apuesta es que sí la hay. Si la realidad demuestra lo
  contrario, agregar offline después es caro — pero se prefiere esperar evidencia real antes que
  pagar por una corazonada.

**Rejected alternatives.**
- *Offline-first con sincronización*: multiplica varias veces el costo del MVP y es de las
  decisiones caras de revertir en ambos sentidos. Descartada por falta de evidencia de que haga
  falta.

**Evidence.** [../analisis-inicial.md](../analisis-inicial.md), sección 9 (D-04) y pregunta 8 de la
sección 6.

**Verified against what already exists.** *No aplica:* no hay aplicación todavía. Queda como riesgo
a revisar con uso real — [ODs.md](ODs.md), OD-12.


---

## ADR-007 — El backend es Supabase

**Context.** El proyecto necesita base de datos, autenticación y hosting con costo cercano a cero
para 3 usuarios y ~45 escrituras diarias. El usuario pidió explícitamente comparar antes de elegir y
no asumir ninguna tecnología. Se verificaron los planes gratuitos de seis proveedores contra sus
páginas oficiales el 2026-09-15.

**Decision.** El backend es Supabase: Postgres, autenticación y almacenamiento del mismo proveedor.

**Consequences.**
- RLS de Postgres para el aislamiento de [ADR-002](#adr-002--cada-usuario-ve-solo-sus-propios-datos)
  y [ADR-003](#adr-003--toda-fila-del-dominio-pertenece-a-un-libro-ledger-no-a-un-usuario): la
  garantía vive en la base, no en el código.
- MFA/TOTP disponible sin costo, lo que habilita [ADR-008](#adr-008--la-autenticación-ofrece-email-contraseña-google-y-totp-opcional).
- La salida es `pg_dump`: dificultad **BAJA**, sin capas de abstracción que escribir.
- **La parte incómoda, y son dos deudas reales:** el plan gratuito **no incluye backups ni PITR**
  (deuda OD-16, se cierra con un `pg_dump` programado **cuya restauración hay que probar**), y
  **pausa el proyecto a los 7 días de inactividad** (riesgo OD-10). El primer escalón pago es un
  piso fijo de US$25/mes, más caro que el de Neon.

**Rejected alternatives.**
- *Firebase/Firestore*: descartado **por el modelo, no por el precio**.
  [ADR-001](#adr-001--el-modelo-registra-origen-y-destino-de-cada-movimiento-partida-doble-oculta)
  exige joins, agregaciones e integridad; Firestore no tiene joins y las agregaciones son caras.
  Además es el único con dificultad de salida **ALTA** (NoSQL propietario, sin equivalente a
  `pg_dump`), lo que choca con el principio de datos exportables.
- *Cloudflare D1* y *Turso*: descartados porque corren SQLite y **no tienen RLS** — el aislamiento
  viviría en el código de la aplicación. Tampoco traen autenticación. Cloudflare era superior en
  todo lo demás (egress $0, sin pausa, único con PITR gratis).
- *PocketBase auto-hospedado*: Fly.io **eliminó su free tier persistente** (trial de 2 h o 7 días).
  Piso real ~US$2-3/mes más mantenimiento de servidor.
- *Neon*: el finalista. No pausa nunca y trae 6 h de restauración instantánea. Descartado porque su
  producto de autenticación es mucho más nuevo y **no documenta MFA/TOTP** — un dato verificado le
  gana a uno ausente — y porque la adquisición por Databricks y el rebranding a *Lakebase* agregan
  riesgo de producto. **Es una decisión de qué riesgo se prefiere, no de cuál es mejor.**

**Evidence.** [../analisis-inicial.md](../analisis-inicial.md) §7 — tabla comparativa con fuentes
oficiales y fecha de consulta.

**Verified against what already exists.**

```bash
curl https://supabase.com/pricing          # -> "Free projects are paused after 1 week of inactivity"
curl https://firebase.google.com/docs/firestore/pitr
                                           # -> "PITR storage doesn't have a free tier"
curl https://fly.io/docs/about/free-trial/ # -> "2 hours of machine runtime or 7 days"
```

Verificación pendiente antes de operar: **OD-15** — si un proyecto pausado revive solo con la
primera request o exige clic manual. No cambia la decisión, cambia la operación.

---

## ADR-008 — La autenticación ofrece email+contraseña, Google y TOTP opcional

**Context.** Tres usuarios, datos financieros privados. Hacía falta definir qué nivel de seguridad es
proporcionado y cuál sería overengineering.

**Decision.** Se ofrecen los tres métodos: email+contraseña, Google OAuth, y TOTP como segundo factor
opcional por usuario.

**Consequences.**
- Los tres vienen incluidos en el plan gratuito de [ADR-007](#adr-007--el-backend-es-supabase): no
  hay costo adicional.
- Cada usuario elige si activa el segundo factor; no se impone.
- **La parte incómoda:** tres métodos son tres caminos de acceso que hay que probar y mantener, y
  cada uno puede fallar distinto. Para tres personas es sobreabundante — se acepta porque el costo
  marginal es casi nulo al venir todos del mismo proveedor.

**Rejected alternatives.**
- *Magic link como método único*: descartado. En una PWA el cliente de correo abre el enlace en su
  propio navegador embebido, distinto de aquel donde se inició el flujo, y la sesión falla. Es un
  problema **estructural** del flujo, no un error que se corrija.
- *Registro y autorización de dispositivos*: overengineering para tres personas. Sesiones bien
  configuradas alcanzan.
- *Auditoría de cambios*: se pospone. Con tres usuarios aislados ([ADR-002](#adr-002--cada-usuario-ve-solo-sus-propios-datos)), la pregunta "¿quién borró esto?" tiene una sola respuesta posible.

**Evidence.** [../analisis-inicial.md](../analisis-inicial.md) §7, tabla de mecanismos de seguridad.

**Verified against what already exists.**

```bash
curl https://supabase.com/pricing   # -> MFA/TOTP básico incluido en el plan Free
```

---

## ADR-009 — El rendimiento de las inversiones se mide en USD

**Context.** En un contexto de inflación alta, el rendimiento nominal en pesos es sistemáticamente
engañoso: un plazo fijo que rinde 90% anual con inflación de 100% **perdió poder adquisitivo**, y un
sistema que muestre +90% en verde está mintiendo. Es el equivalente a medir la altura con una regla
que se estira.

**Decision.** La moneda de medición del rendimiento es el dólar; el peso sigue siendo la moneda de
registro del día a día.

**Consequences.**
- Todo número de rendimiento se calcula convirtiendo a USD a la cotización de la fecha
  correspondiente, usando la fuente que define [ADR-011](#adr-011--la-fuente-de-cotización-es-una-propiedad-de-la-cuenta-no-de-la-fecha).
- El rendimiento nominal en pesos puede mostrarse como dato secundario, **nunca como el número
  grande de la pantalla**.
- Toda cifra de rendimiento debe declarar en qué moneda y con qué cotización se calculó — es el
  principio de transparencia del usuario, aplicado.
- **La parte incómoda:** el dólar tampoco es una vara estable en términos reales. Medir en USD es
  mejor que medir en pesos nominales, pero **no es medir en términos reales**.

**Rejected alternatives.**
- *ARS nominal*: cero trabajo y sistemáticamente engañoso. Descartado.
- *Pesos constantes ajustados por IPC*: técnicamente lo más correcto. Descartado por costo — requiere
  incorporar y mantener la serie del INDEC, que además se publica con retraso. Queda disponible si
  alguna vez se justifica.

**Evidence.** [../analisis-inicial.md](../analisis-inicial.md), error 6 y §5.

**Verified against what already exists.** *No aplica:* no hay cálculo de rendimiento implementado.
Esta decisión existe para que cuando se implemente (etapa 6) no arranque con la vara equivocada.

---

## ADR-010 — El tipo de cambio de una operación se deduce de sus montos, no se guarda

**Context.** El usuario declara que cuando compra dólares o activos **anota el valor exacto al que
compró**. Ese dato no es una cotización de referencia: es el precio de su transacción, y sin él es
imposible calcular el rendimiento de sus ahorros en dólares. Al mismo tiempo,
[ADR-001](#adr-001--el-modelo-registra-origen-y-destino-de-cada-movimiento-partida-doble-oculta)
exige que las líneas de una transacción sumen cero, y un cambio ARS→USD tiene líneas en monedas
distintas que **no suman cero entre sí**. Hacía falta resolver esa invariante antes del esquema.

**Decision.** Una transacción de intercambio tiene exactamente dos unidades distintas, y el tipo de
cambio **es el cociente entre sus dos montos**: no se almacena en ningún campo, se deriva.

Comprar mil dólares a 1.450 es, literalmente:

```
-1.450.000 ARS   de  assets:banco-ars
    +1.000 USD   a   assets:efectivo-usd
```

**Consequences.**
- **El tipo de cambio real de cada operación queda registrado siempre**, sin campo extra y sin un
  paso más en la carga. Lo mismo vale para comprar un activo: el precio unitario es el cociente
  entre el monto y las unidades.
- **Es imposible que el tipo de cambio guardado contradiga a los montos**, porque no hay dos datos
  que puedan discrepar. Un campo `rate` separado sí podría quedar desactualizado.
- La invariante del modelo queda enunciable en una línea: **suma cero por unidad, salvo en
  transacciones de intercambio, donde las dos unidades quedan relacionadas por el cociente de sus
  montos.**
- **La parte incómoda:** la regla vale para exactamente **dos** unidades por transacción. Con tres o
  más el cociente es ambiguo y el sistema debe rechazar la transacción. En finanzas personales eso no
  ocurre, pero es un límite explícito del modelo y hay que validarlo, no suponerlo.

**Rejected alternatives.**
- *Campo `rate` en la transacción*: redundante con los montos y por lo tanto capaz de contradecirlos.
  Descartado.
- *Campo `amount_base` en cada línea, con invariante sobre la moneda base*: era la opción hacia la que
  se inclinaba OD-07. Descartada: obliga a elegir una cotización de referencia **en el momento de
  registrar**, lo que mezcla el hecho (lo que pagaste) con la interpretación (a qué cotización se
  valúa), que es justamente lo que [ADR-011](#adr-011--la-fuente-de-cotización-es-una-propiedad-de-la-cuenta-no-de-la-fecha) separa.

**Evidence.** Respuesta del usuario a OD-04 (2026-09-15) y
[../analisis-inicial.md](../analisis-inicial.md) §1.

**Verified against what already exists.** *No aplica:* no hay esquema. El enfoque es el mismo que
usan los sistemas de contabilidad de texto plano (hledger, beancount) para operaciones multi-moneda,
donde el precio se anota en la operación y no como un dato independiente.

---

## ADR-011 — La fuente de cotización es una propiedad de la cuenta, no de la fecha

**Context.** El usuario usa **distintos tipos de cambio según qué está midiendo**: MEP para valuar
los activos de su broker, blue para los dólares que compró en blue. No es inconsistencia — es
correcto: cada cotización responde a una pregunta distinta. Un modelo que guarde "el" tipo de cambio
de una fecha no puede representar eso.

**Decision.** Las cotizaciones se guardan con su fuente (`oficial`, `mep`, `blue`, `ccl`, `manual`),
y cada cuenta declara con qué fuente se valúa; existe una fuente por defecto para el resto.

**Consequences.**
- La misma fecha puede tener varias cotizaciones válidas a la vez, porque lo son.
- El patrimonio total en dólares es la suma de cada cuenta valuada **con su propia fuente**.
- Toda pantalla que muestre un total en dólares debe poder decir **qué cotización usó** — principio
  de transparencia.
- **La parte incómoda:** un patrimonio total calculado con varias fuentes distintas es correcto pero
  más difícil de explicar que uno calculado con una sola. Y esta decisión **no** vuelve comparables
  entre sí a dos cuentas valuadas con fuentes distintas.

**Rejected alternatives.**
- *Una sola cotización global por fecha*: más simple y no representa lo que el usuario realmente
  hace. Descartada por incorrecta, no por simple.
- *Elegir la fuente en cada consulta*: traslada al usuario una decisión que él ya tomó una vez por
  cuenta. Descartada por fricción.

**Evidence.** Respuesta del usuario a OD-04 (2026-09-15).

**Verified against what already exists.** *No aplica:* no hay esquema todavía. Queda abierto **OD-17**
— los CEDEARs incorporan el CCL en su precio en pesos, lo que puede requerir tratarlos aparte.


---

## ADR-012 — Las cuentas se clasifican por cómo se valúan, no por cómo las llama el banco

**Context.** El inventario de OD-05 y la observación del usuario sobre las cuentas remuneradas
revelaron que la taxonomía heredada de la planilla —*ahorro*, *inversión*, *banco*— **clasifica por
intención, no por mecánica**. Dos cuentas que el usuario llama "inversión" pueden necesitar cálculos
completamente distintos, y una que llama "inversión" puede comportarse exactamente como una cuenta
bancaria.

Cita textual del usuario: *"a una cuenta remunerada la tomo más como otra cuenta bancaria más que
como inversión"*. Tiene razón, y la taxonomía tenía que reflejarlo.

**Decision.** Las cuentas se clasifican según **cómo se responde "¿cuánto vale esto hoy?"**, en tres
familias:

| Familia | ¿Cuánto vale hoy? | Casos |
|---|---|---|
| **Saldo** | Lo que dice el saldo | Efectivo, banco, billetera virtual, **cuenta remunerada**, efectivo sin invertir en el broker, tarjeta de crédito (negativo) |
| **Saldo + devengamiento** | El saldo más lo acumulado y no cobrado | **Plazo fijo** |
| **Unidades × precio** | Hay que consultar un precio de mercado | **CEDEARs**, **cripto** |

**Consequences.**
- La familia determina el cálculo; la etiqueta que el usuario le ponga a la cuenta es solo una
  etiqueta. Se puede renombrar sin romper nada.
- **La palabra "inversión" deja de ser una categoría del modelo** y pasa a ser una vista: "inversiones"
  es simplemente el conjunto de cuentas que el usuario decide mirar juntas.
- Agregar un instrumento nuevo se reduce a una pregunta: ¿a cuál de las tres familias pertenece? Si
  no pertenece a ninguna, es una familia nueva y hay que pensarla — no forzarla.
- **La parte incómoda:** la clasificación del sistema puede no coincidir con la intuición del usuario.
  Un plazo fijo "se siente" más parecido a un ahorro que a un CEDEAR, pero mecánicamente está más
  cerca de una cuenta que de una posición. La interfaz tendrá que agrupar por intuición aunque el
  modelo calcule por mecánica.

**Rejected alternatives.**
- *Clasificar por intención (ahorro / inversión / gasto corriente)*: es lo que hacía la planilla y es
  la causa del error 2 del análisis — mezclar ejes ortogonales. Descartada.
- *Tratar toda cuenta que rinda como una posición con unidades y precio*: técnicamente uniforme y
  falso en la práctica. Una cuenta remunerada no tiene precio de mercado, y una cuenta de la que
  gastás con tarjeta de débito no es una posición. Descartada.

**Evidence.** Inventario de OD-05 y observación del usuario del 2026-09-15.

**Verified against what already exists.** *No aplica:* no hay esquema. Es la decisión que **habilita**
escribirlo — sin ella, las tablas de cuentas y posiciones no se pueden separar bien.

---

## ADR-013 — La cuenta remunerada es una cuenta bancaria; su interés es un ingreso mensual

**Context.** El diseño previo proponía tratar la cuenta remunerada de Mercado Pago como una inversión
con interés devengado. El usuario corrigió el encuadre con dos argumentos: funcionalmente la usa como
una cuenta bancaria más, y **hoy casi todos los bancos ofrecen lo mismo**, así que la distinción
"cuenta vs. cuenta remunerada" está desapareciendo del mercado.

Además fue explícito sobre la frecuencia de carga: *"no lo cargaría todos los días, no hay forma,
casi que preferiría no cargarlo si esa fuera la única alternativa"*.

**Decision.** La cuenta remunerada es una cuenta de la familia **Saldo** de
[ADR-012](#adr-012--las-cuentas-se-clasifican-por-cómo-se-valúan-no-por-cómo-las-llama-el-banco), y
su rendimiento se registra como un **ingreso mensual** a la categoría *Intereses*.

**Consequences.**
- Un movimiento por mes y por cuenta, no uno por día. Es lo máximo que el usuario va a sostener, y
  una carga que no se sostiene equivale a no tener el dato.
- El interés queda separado del sueldo: *Intereses* es su propia categoría de ingreso, así que no
  ensucia la proyección de ingresos.
- La plata sigue siendo gastable directamente, que es lo que la distingue de un plazo fijo.
- **La parte incómoda, y es doble:** entre una carga mensual y la siguiente el saldo queda
  subestimado — aceptable bajo [ADR-005](#adr-005--los-saldos-son-aproximados-no-hay-conciliación-bancaria).
  Y hay una simplificación deliberada: la cuenta remunerada de Mercado Pago **es técnicamente un fondo
  común de dinero** con cuotapartes y precio diario. Se modela como saldo igual, porque modelar el
  mecanismo del proveedor en vez de la realidad del usuario agregaría cuotapartes y precios diarios a
  algo de lo que se paga el supermercado con tarjeta de débito.

**Rejected alternatives.**
- *Tratarla como inversión con unidades y precio (cuotaparte del FCI)*: técnicamente más fiel al
  instrumento y desproporcionado para su uso real. Descartada.
- *Devengar el interés diariamente*: descartada por el usuario de forma explícita. Correcto:
  el sistema tiene que poder ser usado.
- *No registrar el interés*: descartada. Perdería la respuesta a "¿cuánto ahorré este mes?" y
  subestimaría el patrimonio de forma creciente.

**Evidence.** Respuestas del usuario a OD-05 y OD-18 (2026-09-15).

**Verified against what already exists.** *No aplica:* no hay esquema todavía.

---

## ADR-014 — El plazo fijo reconoce su interés al vencimiento

**Context.** El usuario anticipó que va a abrir plazos fijos próximamente. Es la única de sus
posiciones que **inmoviliza la plata**: no se puede gastar, tiene fecha de vencimiento, y su interés
está pactado de antemano. No tiene precio de mercado, así que no es una posición; pero tampoco es
plata disponible, así que no es una cuenta común.

**Decision.** El plazo fijo es una cuenta de la familia **Saldo + devengamiento** de
[ADR-012](#adr-012--las-cuentas-se-clasifican-por-cómo-se-valúan-no-por-cómo-las-llama-el-banco), con
fecha de vencimiento y monto esperado; el interés se reconoce como ingreso **al vencimiento**, en un
solo movimiento.

**Consequences.**
- Dos movimientos por plazo fijo: uno al constituirlo (transferencia desde el banco) y uno al
  vencimiento (capital de vuelta al banco + interés como ingreso). Fricción mínima.
- La plata queda visiblemente inmovilizada: responde a *"¿cuánto tengo disponible?"* del punto 8 del
  brief, que con una cuenta común no se podía distinguir.
- **Descubrimiento con valor propio:** un plazo fijo tiene **fecha y monto conocidos de antemano**, o
  sea que es exactamente el mismo tipo de objeto que un gasto recurrente — un evento futuro conocido,
  con el signo opuesto. La proyección de vencimientos del punto 10 del brief y la de plazos fijos son
  **la misma funcionalidad**. Registrado como OD-19.
- **La parte incómoda:** durante el plazo, el patrimonio queda subestimado por el interés todavía no
  reconocido, y al vencimiento **pega un salto**. Es honesto —hasta el vencimiento esa plata no era
  tuya— pero hay que anticiparlo para no leerlo como un ingreso extraordinario. Es el precio de no
  devengar mes a mes.

**Rejected alternatives.**
- *Devengar el interés mensualmente*: patrimonio más preciso mes a mes y sin salto al vencimiento.
  Descartada por fricción — es un movimiento mensual por cada plazo fijo vigente, y contradice la
  preferencia que el usuario ya expresó sobre la cuenta remunerada.
- *Modelarlo como posición con unidades y precio*: no tiene precio de mercado. Descartada por
  incorrecta.
- *Tratarlo como una cuenta común*: perdería la distinción entre plata disponible e inmovilizada, que
  es justamente lo que lo hace distinto. Descartada.

**Evidence.** Mensaje del usuario del 2026-09-15 anticipando la apertura de plazos fijos.

**Verified against what already exists.** *No aplica:* no hay esquema. Se decide ahora justamente
porque el usuario anunció que el instrumento va a existir pronto — el esquema debe preverlo aunque la
interfaz llegue en la etapa 5.

---

## ADR-015 — No se migra el histórico de la planilla

**Context.** El usuario guarda como máximo un año de historia en la planilla, y esa planilla arrastra
los errores conceptuales que el proyecto corrige — el ahorro restado del resultado, el pago del
resumen de la tarjeta contado como gasto, la compra de dólares como gasto. Importarla significaría
traducir cada fila de un modelo incorrecto a uno correcto.

Textual del usuario: *"prefiero un programa nuevo limpio que perder el tiempo en una migración
innecesaria"*.

**Decision.** No se migra el histórico ni se construye funcionalidad de importación. La aplicación
arranca vacía.

**Consequences.**
- El MVP se achica: desaparece el diseño de importación, el mapeo de categorías viejas y la
  validación de datos heredados.
- No entra basura conceptual al modelo nuevo.
- **La parte incómoda:** los primeros meses no hay historia, y cualquier gráfico de evolución no dice
  nada hasta acumular tres a seis meses. El usuario lo aceptó explícitamente al decir que el dashboard
  vacío no le preocupa. Esto **refuerza** la decisión de dejar el dashboard fuera del MVP.
- Se mantiene el pedido de una **muestra de 20-30 filas** de la planilla — para someter el modelo a
  los casos reales antes de escribirlo, no para importarlas. Es una prueba de diseño, no una
  migración.

**Rejected alternatives.**
- *Importación como funcionalidad de la aplicación*: desproporcionado para un año de datos de un solo
  usuario. Descartada.
- *Script de una sola vez al cerrar el MVP*: se ofreció y el usuario lo descartó explícitamente.
  Queda disponible si alguna vez cambia de opinión — el modelo no lo impide.

**Evidence.** Respuesta del usuario a OD-03 (2026-09-15).

**Verified against what already exists.** *No aplica:* no hay aplicación ni datos cargados.


---

## ADR-016 — Los vencimientos y los gastos recurrentes comparten una sola tabla

**Context.** Al modelar el plazo fijo
([ADR-014](#adr-014--el-plazo-fijo-reconoce-su-interés-al-vencimiento)) quedó a la vista que un
vencimiento y un gasto recurrente son **el mismo objeto**: un evento futuro con fecha conocida y
monto conocido o estimable. El brief los pedía como dos funcionalidades distintas —la proyección de
gastos recurrentes en el punto 10, el seguimiento de inversiones en el punto 12— y construirlos por
separado significaría escribir dos veces el mismo motor de fechas, avisos y proyección.

**Decision.** Una sola tabla `scheduled_event` con un campo `kind` que distingue `recurring` de
`maturity`.

**Consequences.**
- Un solo motor de fechas, un solo lugar donde se calcula "qué se viene", una sola pantalla de
  próximos eventos que mezcla *"seguro anual — $XXX"* con *"vence tu plazo fijo — $1.090.000"*.
- La proyección de caja del mes suma ambos con su signo y sale gratis.
- El usuario ve una sola idea —*lo que se viene*— en vez de dos listas que hay que mirar por
  separado.
- **La parte incómoda:** un recurrente se repite con una frecuencia y un vencimiento ocurre una sola
  vez, así que `frequency` queda en null para los vencimientos. Es una columna que no aplica a la
  mitad de las filas — el precio de la unificación, pagado con un `CHECK` que la exige solo cuando
  `kind = 'recurring'`.

**Rejected alternatives.**
- *Dos tablas separadas*: cada una con su motor de fechas, su cálculo de proyección y su pantalla.
  Descartada por duplicación — y porque la duplicación se paga cada vez que se toca la lógica de
  fechas, que es de las más propensas a errores.
- *Generar el vencimiento como una transacción futura*: contaminaría los saldos con movimientos que
  todavía no ocurrieron. Descartada: un evento previsto no es un hecho.

**Evidence.** [modelo-de-datos.md](modelo-de-datos.md) §2.6 y §5.11.

**Verified against what already exists.** *No aplica:* no hay código. El hallazgo salió de modelar
dos casos de uso del brief y notar que producían la misma estructura.


---

## ADR-017 — El frontend es SvelteKit con adapter-static en modo SPA

**Context.** El caso de uso que define el producto es registrar un gasto parado en la caja del
supermercado, desde el celular, en menos de diez segundos
([analisis-inicial.md](../analisis-inicial.md) §4). Eso convierte al **peso del bundle y al tiempo
hasta que la pantalla es usable** en el criterio técnico dominante, por encima de cualquier
consideración de ecosistema.

[ADR-006](#adr-006--la-app-requiere-conexión-pwa-instalable-pero-no-offline-first) descarta
offline-first y [ADR-007](#adr-007--el-backend-es-supabase) pone toda la lógica de datos en Supabase
con RLS. **No queda servidor propio que escribir**: el frontend habla directo con Supabase desde el
navegador. Por lo tanto el renderizado del lado del servidor no aporta nada — no hay nada que
renderizar en un servidor que no existe.

**Decision.** SvelteKit compilado con `@sveltejs/adapter-static` en modo SPA (`fallback: '200.html'`,
`ssr = false` en el layout raíz), con `@vite-pwa/sveltekit` para el manifiesto y el service worker.

**Consequences.**
- La salida es HTML, CSS y JS estáticos: se publica gratis en Cloudflare Pages, Vercel o GitHub Pages
  sin cambiar nada, lo que mantiene abierta la opción de OD-02 sobre hosting.
- Svelte compila a JavaScript sin framework en tiempo de ejecución: es el bundle más chico de los
  candidatos, que es exactamente el criterio dominante.
- Enrutado, layouts y carga de datos vienen resueltos; no hay que ensamblarlos.
- **La parte incómoda:** el ecosistema de Svelte es más chico que el de React. Para componentes poco
  comunes hay menos opciones hechas y más probabilidad de escribirlos a mano. Es un costo real y se
  acepta: esta aplicación tiene formularios, listas y totales, no componentes exóticos.
- **Sigue siendo la decisión más barata de revertir de todo el proyecto.** Cambiar de framework es
  reescribir pantallas sobre el mismo modelo de datos y el mismo backend. Nada de lo decidido en
  [ADR-001](#adr-001--el-modelo-registra-origen-y-destino-de-cada-movimiento-partida-doble-oculta) a
  [ADR-016](#adr-016--los-vencimientos-y-los-gastos-recurrentes-comparten-una-sola-tabla) depende de
  esta elección.

**Rejected alternatives.**
- *Next.js*: sus fortalezas —renderizado en servidor, componentes de servidor, rutas de API— son
  justamente lo que este proyecto no usa, y el bundle base es mayor. Descartado por pagar
  complejidad que no se aprovecha.
- *React con Vite, sin framework*: bundle razonable y máxima familiaridad, pero obliga a ensamblar
  enrutado y carga de datos a mano. Descartado por trabajo evitable.
- *Renderizado del lado del servidor, en cualquier framework*: no hay servidor propio
  ([ADR-007](#adr-007--el-backend-es-supabase)) y los datos están detrás de autenticación por
  usuario, así que no hay nada prerrenderizable que valga la pena. Descartado por inaplicable.

**Evidence.** [analisis-inicial.md](../analisis-inicial.md) §4 y §7.

**Verified against what already exists.**

```
context7 /websites/svelte_dev_kit — "adapter-static configuration for fully static SPA"
  -> adapter({ fallback: '200.html' }) + `export const ssr = false` en el layout raíz
     produce una SPA estática. Confirmado en la documentación oficial de SvelteKit.
  -> @vite-pwa/sveltekit existe y es un plugin de configuración cero para PWA.
```

El framework **ya resuelve** enrutado, layouts y generación estática: no hay que construir nada de
eso. Y la PWA se resuelve con un plugin, no a mano.


---

## ADR-018 — La puesta en marcha separa dos regímenes de datos

**Context.** El usuario anticipó que va a **reemplazar las categorías por completo** cuando termine la
etapa de prueba y ponga la aplicación a andar en serio, y que en ese momento probablemente pida
borrarlas.

Eso choca de frente con un principio que él mismo escribió en el brief (§20, *Historial*): *"No quiero
destruir información histórica cuando se modifiquen categorías, activos o cuentas"*. Las dos cosas son
razonables, pero **no en el mismo momento**: durante la prueba los datos son descartables; después de
la puesta en marcha son historia.

**Decision.** Existe una línea explícita —la puesta en marcha— que separa dos regímenes. Antes: los
datos son descartables y borrarlos es una operación legítima, vía `supabase/reset_ledger.sql`.
Después: las categorías, cuentas y activos **se remapean y se archivan, nunca se borran**.

**Consequences.**
- Reorganizar las categorías **sigue siendo posible después de la puesta en marcha**, y por completo:
  se crean las nuevas, se reasignan los movimientos y se archivan las viejas. No se pierde ni un
  número — verificado el 2026-09-15 contra PostgreSQL 16.
- La base ya impone la mitad de esto por sí sola: la clave foránea de `entry.category_id` **bloquea**
  borrar una categoría con movimientos. El principio del brief está hecho constraint, no confiado a
  la disciplina de nadie.
- El script de reseteo exige una confirmación explícita (`-v reset_confirm=BORRAR_TODO`) y sin ella
  aborta sin tocar nada. Verificado: con 13 transacciones cargadas, el intento sin confirmación las
  dejó en 13.
- El reseteo **conserva el libro y el usuario**: se vacía el contenido, no la identidad.
- **La parte incómoda:** la línea la marca una persona, no el sistema. No hay ninguna bandera en la
  base que diga "esto ya es producción", así que **nada impide correr el reseteo un día después de la
  puesta en marcha y perder todo**. Ponerle un candado automático requeriría un estado de libro que
  hoy no existe, y se decidió no agregarlo: sería infraestructura para un usuario que sabe lo que
  hace. Queda registrado como riesgo en [ODs.md](ODs.md) — OD-22.

**Rejected alternatives.**
- *Prohibir el borrado siempre, desde el día uno*: obligaría a arrastrar categorías de prueba a la
  base definitiva o a recrear el proyecto entero. Descartada por absurda en la etapa de prueba.
- *Permitir el borrado siempre, con borrado en cascada de los movimientos*: destruiría historia en
  silencio. Descartada: viola directamente el principio del brief.
- *Una bandera `is_production` en el libro que bloquee el reseteo*: es el candado que falta. Descartada
  **por ahora** por desproporcionada — un usuario que corre un script llamado `reset_ledger.sql` con
  una confirmación explícita sabe lo que está haciendo. Reconsiderable si OD-22 se vuelve real.

**Evidence.** Mensaje del usuario del 2026-09-15 y [modelo-de-datos.md](modelo-de-datos.md) §9.

**Verified against what already exists.**

```
PostgreSQL 16, 2026-09-15 — con 13 transacciones cargadas:
  delete de categoria CON movimientos      -> BLOQUEADO por foreign_key_violation
  delete de categoria SIN movimientos      -> permitido
  archivar categoria CON movimientos       -> permitido
  remapear movimientos a otra categoria    -> permitido, los 18.000 llegaron intactos
  reset sin confirmacion                   -> abortado, las 13 transacciones siguen ahi
  reset con confirmacion                   -> 0 transacciones, 20 categorias resembradas,
                                              libro y miembro conservados
```

La base **ya hacía** lo correcto antes de esta decisión: la clave foránea sin `on delete` protege la
historia sola. Esta ADR no agrega un mecanismo, nombra la línea y escribe las dos rutas.


---

## ADR-019 — Registrar un movimiento es una función de base, no dos inserciones del cliente

**Context.** Registrar un movimiento significa escribir en `transaction` y en `entry`. Hecho desde el
navegador con el cliente de Supabase son **dos llamadas independientes**, y eso trae tres problemas
concretos:

1. **No es atómico.** Si la segunda falla, queda un movimiento huérfano sin líneas.
2. **Son dos viajes de red** en el único flujo que tiene un objetivo medido: registrar un gasto en
   menos de diez segundos, desde un celular, posiblemente con mala señal.
3. **Obliga al cliente a conocer el `ledger_id`**, y
   [ADR-003](#adr-003--toda-fila-del-dominio-pertenece-a-un-libro-ledger-no-a-un-usuario) dice que el
   libro no debe existir para la interfaz.

**Decision.** La escritura pasa por `create_transaction(...)`, una función de PostgreSQL declarada
`SECURITY INVOKER` que inserta el movimiento y sus líneas en una sola transacción de base.

**Consequences.**
- **Atomicidad real.** El trigger diferido de
  [ADR-010](#adr-010--el-tipo-de-cambio-de-una-operación-se-deduce-de-sus-montos-no-se-guarda)
  dispara al confirmar: si las líneas no balancean, no queda nada — ni el movimiento ni las líneas.
  Verificado el 2026-09-15 con dos intentos fallidos consecutivos que no dejaron huérfanos.
- **Un solo viaje** en vez de dos.
- **El cliente nunca nombra el libro.** Se agregó `my_ledger()` como `DEFAULT` de la columna
  `ledger_id` en las nueve tablas del dominio: la base lo completa y RLS lo verifica.
  [ADR-003](#adr-003--toda-fila-del-dominio-pertenece-a-un-libro-ledger-no-a-un-usuario) pasa de
  intención a hecho.
- `SECURITY INVOKER` es **explícito y no negociable**: la función corre con los permisos de quien la
  llama, así que RLS sigue aplicando. Con `SECURITY DEFINER` sería un agujero que saltearía todo el
  aislamiento de [ADR-002](#adr-002--cada-usuario-ve-solo-sus-propios-datos).
- **La parte incómoda:** hay lógica de escritura en la base, no solo en el cliente. Cambiar la forma
  de un movimiento ahora exige una migración además de tocar el frontend, y para alguien que lea solo
  el código de la aplicación esa lógica es invisible. Es el precio de la atomicidad, y se paga.

**Rejected alternatives.**
- *Dos llamadas desde el cliente*: funciona para el caso feliz —las líneas van en un solo `INSERT`, así
  que el balance se verifica bien— pero deja huérfanos cuando falla la segunda, y son dos viajes.
  Descartada.
- *Insertar las líneas de a una*: **imposible**. Cada sentencia confirma por separado y una línea sola
  nunca balancea. Descartada por incompatible con
  [ADR-010](#adr-010--el-tipo-de-cambio-de-una-operación-se-deduce-de-sus-montos-no-se-guarda).
- *Que el cliente traiga y guarde su `ledger_id` al iniciar sesión*: resuelve el punto 3 y ninguno de
  los otros dos, y expone en la interfaz un concepto que ADR-003 quiere invisible. Descartada.

**Evidence.** `supabase/migrations/20260915110000_rpc.sql`, `supabase/tests/05_rpc.sql`.

**Verified against what already exists.**

```
PostgreSQL 16, 2026-09-15:
  registra y devuelve id, sin que el cliente nombre el libro   -> ok
  el ledger_id lo puso la base                                  -> ok
  2 intentos fallidos (desbalanceado, una sola linea)           -> 0 huerfanos
  lineas sueltas tras los fallos                                -> 0
  entry_detail respeta RLS: un extranio ve                      -> 0 lineas

Prueba de mutacion: eliminando el trigger de balance, el test DETECTA la regresion
  -> "FALLO FUGA: habia 14 y ahora hay 15"
```

Un test que no puede fallar no prueba nada. Este falla cuando debe.


---

## ADR-020 — Los permisos del Data API son explícitos, y `anon` no tiene ninguno

**Context.** Supabase trae tres interruptores que deciden cómo se expone la base al navegador.
Dos vienen activados de fábrica y uno apagado, y **la combinación por defecto deja un solo candado
entre un desconocido y los datos financieros**:

| Interruptor | De fábrica | Qué hace |
|---|---|---|
| *Enable Data API* | activado | Genera la API REST sobre el esquema público |
| *Automatically expose new tables* | activado | Otorga privilegios a `anon`, `authenticated` y `service_role` sobre **toda tabla nueva** |
| *Enable automatic RLS* | **apagado** | Dispara un trigger que activa RLS en toda tabla nueva del esquema público |

Con la configuración de fábrica, `anon` —un pedido **sin autenticar**— tiene privilegios sobre las
tablas, y lo único que lo detiene es RLS. Si alguna vez se crea una tabla y se olvida la política,
queda legible para cualquiera con la URL y la clave publicable, que es pública por diseño.

**Decision.** El Data API queda activado; la exposición automática de tablas nuevas se **apaga** y los
permisos se otorgan explícitamente en una migración; el RLS automático se **enciende**.

**Consequences.**
- **Dos candados en vez de uno.** `anon` no tiene ningún privilegio: un pedido sin autenticar **no
  llega ni a la tabla**, mucho antes de que RLS tenga que decidir nada. `authenticated` llega a la
  tabla, y ahí RLS decide qué filas ve.
- **Los permisos quedan en el repositorio**, no en un interruptor de un panel. Se revisan en una
  revisión de código y se reproducen en cualquier entorno.
- **`ledger` y `ledger_member` no se otorgan a nadie.** El cliente nunca las consulta y `my_ledgers()`
  las lee como `SECURITY DEFINER`. Con esto
  [ADR-003](#adr-003--toda-fila-del-dominio-pertenece-a-un-libro-ledger-no-a-un-usuario) deja de ser
  una intención de diseño y pasa a ser un permiso denegado: el libro **no existe** para el cliente.
- Encender el RLS automático hace **imposible** crear una tabla en el esquema público sin RLS. Es la
  clase de refuerzo que se busca siempre: que lo correcto sea lo único posible.
- **La parte incómoda:** cada tabla nueva necesita ahora su `GRANT` explícito en una migración. Si
  alguien agrega una tabla y se olvida, la aplicación falla con *permiso denegado* — un error ruidoso
  en desarrollo. Es el modo correcto de fallar: se rompe visible en vez de exponer datos en silencio.

**Rejected alternatives.**
- *Dejar los tres interruptores como vienen*: menos trabajo y deja a `anon` con privilegios sobre todo
  el esquema, con RLS como única defensa. Descartada: para datos financieros privados, un solo candado
  es poco cuando el segundo es gratis.
- *Apagar el Data API*: imposible. `supabase-js` lo necesita, y
  [ADR-017](#adr-017--el-frontend-es-sveltekit-con-adapter-static-en-modo-spa) no tiene servidor propio
  por el que pasar.
- *Otorgar `select` a `anon` "por si acaso"*: no hay ningún caso. La aplicación es privada de punta a
  punta, no tiene ni una pantalla pública.

**Evidence.** `supabase/migrations/20260915120000_grants.sql`, `supabase/tests/06_grants.sql`.

**Verified against what already exists.**

```
PostgreSQL 16, 2026-09-15:
  anon -> select de la tabla transaction      -> insufficient_privilege
  anon -> select de la vista entry_detail     -> insufficient_privilege
  authenticated -> sus transacciones          -> 14, como debe
  authenticated -> select de la tabla ledger  -> insufficient_privilege

El rol de prueba se corrigio para heredar SOLO de 'authenticated'. Antes tenia
permisos directos, y por eso no medía lo que la aplicacion realmente tiene.
```


---

## ADR-021 — El hosting es Cloudflare Workers, sirviendo solo activos estáticos

**Context.** [ADR-017](#adr-017--el-frontend-es-sveltekit-con-adapter-static-en-modo-spa) dejó el
hosting deliberadamente abierto (OD-02): la salida es estática y anda igual en cualquier lado. Al ir
a publicar apareció un dato que invalida el plan original — **Cloudflare Pages dejó de ser el camino
para proyectos nuevos**. Textual de su propia documentación, consultada el 2026-09-15:

> *"Are you sure you want to use Pages? Workers supports most Pages use cases and offers a broader
> feature set. It is Cloudflare's primary platform for building applications. **Start new projects
> with Workers.**"*

Pages sigue funcionando, pero está en mantenimiento y el panel se reorganizó en consecuencia — al
punto de que la sección "Workers & Pages" que indicaba la guía **ya no existe**.

**Decision.** Se publica en Cloudflare Workers con activos estáticos, **sin script de Worker**:
`wrangler.jsonc` declara `assets.directory` y `assets.not_found_handling: "single-page-application"`.

**Consequences.**
- Ancho de banda ilimitado en el plan gratuito, y **cero invocaciones facturables**: al no haber
  `main`, no se ejecuta ningún código de Cloudflare, solo se sirven archivos.
- `not_found_handling` resuelve el ruteo de la SPA de forma nativa. Sin eso, entrar por la home
  funciona pero **recargar en cualquier otra ruta devuelve 404**.
- El fallback de `adapter-static` pasó de `200.html` a **`index.html`**, que es el archivo que
  Workers sirve en modo SPA. SvelteKit desaconseja `index.html` cuando hay una home prerrenderizada;
  acá `prerender = false`, así que no hay conflicto posible.
- Se mantiene `static/_redirects` aunque en Workers sea redundante: es el mecanismo **portable**, y
  es lo único que haría falta para publicar en Netlify. Mudarse sigue costando casi nada.
- **La parte incómoda:** Cloudflare mueve las etiquetas de su panel seguido —esta guía ya quedó
  desactualizada una vez antes de usarse— así que la documentación incluye un camino por línea de
  comandos que no depende de ningún nombre de menú. Es más trabajo de mantener y es lo que evita que
  la guía envejezca mal.

**Rejected alternatives.**
- *Cloudflare Pages*: era el plan original. Descartado porque **Cloudflare mismo dice que no se
  empiecen proyectos nuevos ahí**.
- *`adapter-cloudflare`*: es lo que recomienda la guía de SvelteKit de Cloudflare, y genera un
  `_worker.js`. Descartado por dos motivos: no hay una sola línea de código de servidor que ejecutar,
  y ataría la salida a Cloudflare, que es exactamente lo que
  [ADR-017](#adr-017--el-frontend-es-sveltekit-con-adapter-static-en-modo-spa) quiso evitar.
- *Vercel Hobby o GitHub Pages*: sirven igual, pero sus términos **prohíben el uso comercial**.
  Hoy es irrelevante y es una atadura innecesaria cuando la alternativa no la tiene.

**Evidence.** `wrangler.jsonc`, [puesta-en-marcha.md](puesta-en-marcha.md) §10.

**Verified against what already exists.**

```
developers.cloudflare.com/pages/            (2026-09-15)
  -> "Start new projects with Workers."
developers.cloudflare.com/workers/static-assets/routing/single-page-application/
  -> not_found_handling: "single-page-application" sirve /index.html con 200 OK
     cuando el pedido no coincide con ningun archivo.

El plan original de esta guia apuntaba a "Workers & Pages" en el panel. Esa
seccion ya no existe: lo reporto el usuario al no encontrarla.
```


---

## ADR-022 — El patrimonio incluye solo activos financieros

**Context.** Al planificar la etapa de inversiones apareció la pregunta de si el patrimonio que
muestra la aplicación debe incluir bienes no financieros —un inmueble, un auto—. Para mucha gente la
casa es el ítem más grande de su patrimonio, así que excluirla no es un detalle.

El esquema lo permitiría sin cambios: la familia `market` de
[ADR-012](#adr-012--las-cuentas-se-clasifican-por-cómo-se-valúan-no-por-cómo-las-llama-el-banco)
admite precio manual (`price.source = 'manual'`) y el tipo de instrumento `'other'` ya existe.

**Decision.** El patrimonio comprende únicamente activos financieros: plata, inversiones y deudas. Los
bienes no financieros quedan fuera.

**Consequences.**
- Todo lo que la aplicación suma es **comparable y liquidable a un precio conocido**. Una tasación de
  un inmueble es una opinión, no un precio, y mezclarla con saldos bancarios da un total que parece
  exacto y no lo es.
- Desaparece una pantalla de mantenimiento: nadie tiene que acordarse de actualizar cuánto vale su
  casa para que el número del mes cierre.
- **La parte incómoda, y hay que decirla:** si el usuario tiene un inmueble, **el "patrimonio total"
  de la aplicación no es su patrimonio real**. Es su patrimonio financiero, y va a tener que
  recordarlo cada vez que mire ese número. La pantalla debería nombrarlo así el día que la diferencia
  importe.
- Revertirlo es barato: el esquema ya lo soporta, así que es una pantalla y una decisión de cómo
  mostrarlo, no una migración.

**Rejected alternatives.**
- *Incluirlos con precio manual*: técnicamente inmediato. Descartado porque obliga a mantener a mano
  un número subjetivo, y porque contamina el total con una cifra de naturaleza distinta a las demás.
- *Incluirlos en una sección aparte, fuera del total*: es la solución de compromiso y sigue
  disponible. Descartada **por ahora** por no agregar pantalla a algo que el usuario dijo no
  necesitar.

**Evidence.** Decisión del usuario, 2026-09-16. `porposal.md` §8 y §16 describen el patrimonio en
términos de cuentas, monedas e inversiones, sin mencionar bienes.

**Verified against what already exists.** *No aplica:* es una decisión de alcance. Se verificó, eso
sí, que el esquema **no la impone**: revertirla no exige migrar nada.


---

## ADR-023 — La unidad de medida es un parámetro: dólares o poder adquisitivo

**Context.** [ADR-009](#adr-009--el-rendimiento-de-las-inversiones-se-mide-en-usd) fijó el dólar como
moneda de medición para no medir en pesos nominales. Al construir la medición, el usuario preguntó
algo que esa decisión no cubría: *"¿le estamos ganando a la inflación?"*.

**No son la misma pregunta.** Si el dólar sube menos que los precios —atraso cambiario, frecuente en
Argentina— se puede tener un rendimiento de 0% en dólares y estar **perdiendo poder adquisitivo**. Y
al revés cuando el dólar se adelanta. Medir en dólares responde *"¿le gano al dólar?"*, que es una
pregunta legítima pero distinta.

Al buscar la fuente de datos apareció que la serie **UVA** —el índice diario que sigue al IPC— está
disponible con historia completa, verificada: 3823 valores diarios desde 2016.

**Decision.** La unidad de medida es un parámetro de la función de conversión, no una constante. Se
admiten `USD` y `UVA`, y el mecanismo es el mismo: **dividir por la vara de la fecha del movimiento**.

**Consequences.**
- Una sola implementación responde dos preguntas distintas, porque **la unidad de medida es apenas un
  divisor**: para dólares se divide por la cotización de ese día, para poder adquisitivo por la UVA de
  ese día.
- La UVA entra como una fila más en `fx_rate` —"cuántos pesos vale una UVA"— sin tabla nueva, porque
  es exactamente la misma forma de dato.
- El usuario puede ver el mismo rendimiento bajo las dos varas y entender **por qué difieren**, que
  suele ser más informativo que cualquiera de los dos números por separado.
- **La parte incómoda:** duplica el dato que hay que mantener. Si falta la serie UVA de un período, esa
  medición no se puede hacer, y ahora hay dos maneras de quedarse sin poder responder en vez de una.
- Hereda además el principio de
  [ADR-011](#adr-011--la-fuente-de-cotización-es-una-propiedad-de-la-cuenta-no-de-la-fecha): toda
  pantalla que muestre un rendimiento tiene que decir con qué vara lo midió.

**Rejected alternatives.**
- *Solo dólares*: es lo que decía ADR-009 y responde la mitad de la pregunta del usuario. Descartada
  al aparecer que la otra mitad costaba casi lo mismo.
- *Agregar también comparaciones contra un plazo fijo o contra el S&P*: responden *"¿elegí bien?"*, no
  *"¿llegué a mi objetivo?"*. Descartadas por el principio del brief §16: cada visualización existe
  porque ayuda a decidir algo. Cuatro varas sin saber cuál mirar es peor que dos bien entendidas.
- *Usar el IPC del INDEC en vez de la UVA*: el IPC es mensual, sale con retraso y se revisa. La UVA es
  diaria y es la que usan los instrumentos indexados. Descartada por peor dato para el mismo fin.

**Evidence.** `supabase/migrations/20260916140000_medicion.sql`, `supabase/tests/11_medicion.sql`.

**Verified against what already exists.**

```
api.argentinadatos.com  (2026-09-16)
  /v1/finanzas/indices/uva          -> 3823 valores diarios, 2016-03-31 a 2026-09-17
  /v1/cotizaciones/dolares/<casa>/<AAAA>/<MM>/<DD>
     -> devuelve CUALQUIER fecha pasada, con oficial, blue, bolsa (MEP),
        mayorista, contadoconliqui (CCL) y cripto

A diferencia de los precios de los activos (OD-31), las cotizaciones SI se pueden
recuperar hacia atras: son dato publico.
```

La regla de conversión usa **la última cotización anterior o igual**, no la más cercana: un sábado no
cotiza, y el valor que regía ese día es el del viernes. Tomar el lunes sería usar información que en
ese momento no existía.


---

## ADR-024 — Un CEDEAR se mide al CCL, porque es el dólar que su propio precio lleva adentro

**Context.** Un CEDEAR cotiza en pesos, pero su precio en pesos no es una decisión del mercado local:
sale de un arbitraje.

```
precio_cedear_ARS = (precio_acción_USD / ratio) × CCL
```

Eso significa que el precio en pesos sube por DOS motivos distintos, y el número no dice cuál fue: o
subió la acción en dólares, o subió el dólar. Medir esa posición con el MEP —el valor por defecto que
fijó [ADR-011](#adr-011--la-fuente-de-cotización-es-una-propiedad-de-la-cuenta-no-de-la-fecha)— produce
una **ganancia fantasma**: la brecha entre MEP y CCL se cuela dentro de lo que la pantalla llama
"rendimiento del activo". El caso está reproducido en `supabase/tests/13_cedears.sql`: el CCL sube
40%, la acción no se mueve, y al MEP la posición marca +11% de rendimiento que nadie ganó.

Al revisar esto apareció además que ADR-011 estaba **declarado y no cumplido**: `valor_inversion` y
`flujo_inversion` llamaban a `convertir()` sin pasarle el `fx_source` de la cuenta, así que TODAS las
posiciones se medían con la fuente del libro, no con la propia.

**Decision.** Una posición en CEDEARs nace con `fx_source = 'ccl'`, y las vistas de valuación y de
flujo convierten cada cuenta con SU fuente.

**Consequences.**
- La división se hace sola. Convertir al CCL cancela el CCL que el precio traía adentro:
  `valor_USD = precio_ARS × unidades / CCL = (precio_acción_USD / ratio) × unidades`. Lo que queda es
  exactamente el rendimiento de la acción en dólares, que es la pregunta del usuario.
- **No hace falta ninguna fuente de precios del exterior, ni el ratio, para medir bien.** El ratio y
  el símbolo subyacente se guardan como dato informativo —para reconocer el papel— y no entran en la
  cuenta.
- **La parte incómoda:** el número deja de responder *"cuántos dólares me llevo si vendo hoy"*. Si el
  usuario vende el CEDEAR y saca los pesos al MEP, se lleva más (o menos) que lo que la app mostraba.
  Son dos preguntas distintas y la app contesta la del rendimiento. Cada pantalla de rendimiento dice
  con qué dólar midió — la lista de posiciones ahora imprime `al CCL` / `al MEP` junto a las unidades.
- Arrastra un cambio que va más allá de los CEDEARs: cualquier cuenta puede fijar su vara. Una compra
  de dólar blue se mide al blue sin que eso contamine al resto.

**Rejected alternatives.**
- *Guardar el precio de la acción en el exterior y el ratio, y valuar con eso*: exige una fuente de
  precios de EE.UU., mantener el ratio actualizado (cambia por splits y por ajustes del emisor) y
  tener el papel bien mapeado. Más piezas, más cosas que romper, **y el mismo resultado** que sale de
  una división que ya está disponible. Descartada por costo sin beneficio.
- *Registrar el CCL implícito de cada compra a mano*: el usuario ya dijo que no quiere cargar datos
  que el sistema pueda deducir, y volvería a poner un dato duplicado donde ADR-010 sacó uno.
- *Dejarlos en MEP y avisar en la pantalla*: una advertencia no arregla un número mal calculado. El
  usuario miraría el porcentaje, no el cartel.

**Evidence.** `supabase/migrations/20260916170000_cedears.sql`, `supabase/tests/13_cedears.sql`
(6 aserciones, incluida la de la ganancia fantasma), `src/routes/inversiones/+page.svelte`.

**Verified against what already exists.**

```
docker: postgres:16 descartable, suite completa -> 107 aserciones ok

ok  un CEDEAR nace midiendose al CCL, no al dolar del libro
ok  140.000 pesos al CCL de ese dia son 100 dolares invertidos
ok  en pesos la posicion se duplico: 140.000 a 200.000
ok  al CCL vale los mismos 100 dolares: la suba era el dolar
ok  al MEP mostraria 111 dolares: una ganancia fantasma de 11%
ok  si la accion sube 10%, el CEDEAR marca 110 dolares
```

La cuarta y la quinta aserción son el ADR entero: **el mismo día, la misma posición, dos varas y una
diferencia de 11% que no existió.**


---

## ADR-025 — Los precios se traen solos todos los días, porque el de hoy no se recupera mañana

**Context.** OD-06 decía **DECIDED: carga automática** desde el 2026-09-16, y nadie la había
construido: los precios se cargaban a mano, uno por uno, desde `/inversiones`. Una decisión escrita y
no ejecutada es la peor clase de decisión, porque figura como resuelta.

Lo que la volvió urgente no fue la comodidad, sino OD-31. Las cotizaciones del dólar **se piden hacia
atrás** —son dato público— así que si un día falla el flujo, al día siguiente se recupera. Los precios
de los activos **no**:

```
data912.com/historical/*  -> 404          (2026-09-16)
data912.com/hist/*        -> 404
data912.com/live/...?date=2026-09-01 -> 200, pero devuelve el precio de HOY
```

El precio de hoy que no se guarda hoy no se recupera nunca. Cada día sin guardar es un hueco
permanente en el gráfico de evolución que todavía no existe. **Es barato hoy e imposible después.**

**Decision.** Un flujo diario trae el precio de cada instrumento activo: CEDEARs y acciones de BYMA
en pesos, cripto de Binance en USDT. Se pregunta a la base qué instrumentos hay y se piden solo esos.

**Consequences.**
- Se deja de pedir al usuario que cargue precios a mano. La carga manual **queda**: es el respaldo
  para lo que ninguna fuente cubre, y la pantalla dice cuáles son.
- **`underlying_symbol` dejó de ser informativo**: es la llave con la que se le pide el precio a la
  fuente. Un CEDEAR se llama `AAPL-CEDEAR` en el libro y `AAPL` en BYMA. ADR-024 sigue siendo cierto
  —medir al CCL no necesita ese campo— pero ahora el campo tiene un segundo trabajo.
- **La parte incómoda:** un CEDEAR cargado sin ese símbolo **no recibe precio y no se rompe nada**.
  Se queda quieto, que es la peor forma de fallar. Por eso el formulario lo pide, la lista marca
  *a mano* las posiciones que no cotizan solas, y el flujo avisa cuántas quedaron sin precio.
- Se aceptan dos aproximaciones, ambas por el mismo criterio —no sumar una dependencia más para
  corregir décimas—: **USDT se trata como USD** (flota unas décimas alrededor), y de los dos plazos
  de liquidación de BYMA se toma siempre el mismo (difieren menos del 0,1%).
- Cripto se pide a **Binance y no a un índice global** a propósito: el usuario opera ahí, así que ese
  es el precio que efectivamente obtendría. Un índice sería más neutral y menos cierto.

**Rejected alternatives.**
- *data912.com*: un GET simple contra un POST con cabeceras, y la misma data. Descartada por ser un
  intermediario: es una pieza más que puede desaparecer entre BYMA y nosotros. Queda anotada como
  respaldo si BYMA cierra el endpoint público.
- *Pedir la rueda entera y filtrar en SQL*: 2196 filas por día para quedarse con tres o cuatro.
- *Guardar solo el último precio en vez de la serie diaria*: responde *"¿gano o pierdo?"* pero no
  *"¿cómo evolucionó?"*, y la segunda no se puede contestar retroactivamente. Es la mitad de OD-30 y
  la razón entera de OD-31.

**Evidence.** `scripts/precios.mjs`, `.github/workflows/precios.yml`,
`supabase/migrations/20260916190000_llave_de_precio.sql`.

**Verified against what already exists.**

```
Probado de punta a punta contra un postgres descartable con las migraciones y
los datos de prueba cargados:

  instrumentos en la base -> cedear AAPL-CEDEAR AAPL ARS
                             crypto BTC         BTC  USD
  node scripts/precios.mjs -> 2 de 2 precios listos
  psql -f precios.sql      -> AAPL-CEDEAR 26440 ARS byma
                              BTC         75784 USD binance

BYMA devuelve el JSON CORTADO si no se pide comprimido: 2196 filas con
--compressed, y un "Unterminated string" sin el. Un parse que falla es ruidoso
y por eso es seguro; lo grave habria sido que parseara a medias. El script pide
comprimido, reintenta y rechaza cualquier respuesta con menos de 100 filas.

Cada simbolo aparece DOS veces, uno por plazo de liquidacion (AAPL a 26540 y a
26520), y ademas cotiza en USD (AAPLD) y en cable (AAPLC). Filtrar por
denominationCcy = 'ARS' no es un detalle: sin eso se valuaria una posicion en
pesos con un numero en dolares.
```


---

## ADR-026 — El portafolio es el borde: es flujo solo lo que lo cruza

**Context.** El usuario miró la pantalla de inversiones y dijo que esos elementos deberían pertenecer
a un portafolio —Binance, Balanz— y que **lo que importa es el valor del portafolio**. Se verificó
contra `flujo_inversion`, que unía solo cuentas `market` y `accrual`, y la observación resultó ser
más grave de lo enunciado. Tres agujeros, todos el mismo error:

1. **El efectivo quieto en el broker no existía.** Vendés ETH, dejás los dólares ahí: el portafolio
   marcaba cero. La cuenta de efectivo del broker es `valuation = 'balance'` y quedaba fuera.
2. **La plata depositada que espera no penalizaba.** El aporte se fechaba en la COMPRA, no en el
   depósito. Si la plata entró en enero y se compró en julio, seis meses ociosos desaparecían **y el
   rendimiento salía mejor de lo que fue.**
3. **Comprar adentro contaba como aporte nuevo.** Cambiar USDT por ETH no es plata que entró: es la
   misma plata cambiando de forma.

**Decision.** Un portafolio agrupa cuentas. Su valor son sus posiciones **más su efectivo**, y es
flujo únicamente lo que tiene la contraparte fuera del portafolio.

**Consequences.**
- Una sola condición cierra los tres agujeros, sin ningún caso especial:
  `where contraparte.portfolio_id is distinct from p.id`.
- **Una contraparte sin cuenta es una categoría, y no es flujo.** El interés que paga el broker no
  es plata que aportaste: es rendimiento generado adentro. Sube el valor, no el aporte.
- Se mide sobre la pata de AFUERA, no la de adentro: cuando comprás un CEDEAR con pesos, lo que cruzó
  son los pesos, y los pesos se convierten con la cotización del día. Convertir la pata de adentro
  exigiría el precio del activo en esa fecha, que puede no existir.
- **Generaliza hacia arriba:** tu patrimonio entero es el portafolio que contiene todo. *"¿Le gané a
  la inflación?"* es la misma cuenta con el borde corrido. Y el rendimiento por posición es la misma
  función con el borde en una sola cuenta. **Una máquina, tres preguntas.**
- Pertenecer es **opcional**, y ahí está la diferencia con agrupar por institución: la cuenta
  remunerada de Mercado Pago no tiene por qué entrar, aunque Mercado Pago también sea una
  institución. [ADR-013](#adr-013--la-cuenta-remunerada-es-una-cuenta-bancaria-su-interés-es-un-ingreso-mensual)
  ya había decidido que eso es un banco, no una inversión.
- El portafolio fija su propio dólar: Balanz al CCL, Binance al cripto. La cuenta manda sobre el
  portafolio y el portafolio sobre el libro — tres niveles, un solo `coalesce`.
- **La parte incómoda:** hay un campo más que llenar al crear una cuenta, y una cuenta que se olvida
  de apuntar a su portafolio **no rompe nada**: mide mal en silencio. Es el mismo modo de falla que
  ADR-025 y se mitiga igual, diciéndolo en la pantalla.
- `valor_inversion` dejó de ser una vista propia y pasó a ser un recorte de `valor_cuenta`. Ahora hay
  **una sola definición de cuánto vale una cuenta**. La lección ya había aparecido tres veces en este
  proyecto: cuando algo se define en seis lugares, los seis dejan de coincidir.

**Rejected alternatives.**
- *Agrupar por `institution`, que ya existe*: cero cambios de esquema y funcionaba hoy mismo.
  Descartada por dos razones concretas: es texto libre —`Binance` y `binance` serían dos portafolios—
  y arrastra adentro TODA cuenta de esa institución, incluida la remunerada que ADR-013 excluyó.
- *Medir solo el patrimonio global*: contesta la pregunta central y es gratis, pero no deja comparar
  Binance contra Balanz ni ver cuál de los dos arrastra al otro.
- *Una tabla `holding` con las posiciones adentro*: vuelve a introducir el objeto que el modelo ya
  había eliminado —una posición es una cuenta— para resolver algo que se resuelve agrupando.

**Evidence.** `supabase/migrations/20260916200000_portafolios.sql`, `supabase/tests/14_portafolios.sql`.

**Verified against what already exists.**

```
docker: postgres:16 descartable, suite completa -> 115 aserciones ok

ok  el deposito desde el banco es un aporte de 1000 dolares
ok  el efectivo quieto en el broker VALE: 1000 dolares
ok  comprar ADENTRO no es un aporte nuevo: sigue habiendo 1 flujo
ok  el portafolio vale efectivo MAS posiciones: 500 + 600
ok  el interes que paga el broker NO es aporte: es rendimiento
ok  pero SI sube el valor del portafolio: 1100 a 1120
ok  el retiro cruza el borde: aporte neto 1000 - 300 = 700
ok  el aporte lleva la fecha del DEPOSITO, no la de la compra
```

La tercera y la octava son el ADR entero: **la plata cambió de forma cinco veces adentro y el aporte
sigue siendo uno solo, con la fecha en que cruzó.**


---

## ADR-027 — El alta siembra estructura, no taxonomía, y la puesta en marcha pregunta el resto

**Context.** El usuario le dio la aplicación a su padre y **se perdió**. No es una hipótesis de
diseño: es la primera vez que kipo la usó alguien que no la había construido.

Al revisar por qué, la primera conclusión fue equivocada y conviene dejarla escrita: creí que había
un callejón sin salida —el selector de cuenta de `/nuevo` no tenía `{:else}` y quedaba mudo— y resultó
que el alta **sí** sembraba una cuenta, `Efectivo ARS`. Leí la pantalla y no seguí hasta el trigger
antes de concluir.

Lo que sí apareció, ya con el bootstrap a la vista: el alta sembraba **20 categorías**. Para cargar un
café había que elegir entre doce opciones que nadie eligió — `Alquiler / Expensas`, `Servicios`,
`Seguros`, `Impuestos`, `Suscripciones`, `Supermercado`, `Restaurantes`, `Transporte`,
`Entretenimiento`, `Compras`, `Salud`, `Donaciones` —. Y no había **ninguna** pantalla de primer uso:
`grep` de *onboarding*, *bienvenida*, *primer uso* devolvía cero.

**Decision.** El alta siembra solo lo que es estructura —los dos grupos de gasto, los ingresos
básicos y las dos categorías de sistema— y ninguna cuenta. La puesta en marcha, en `/comenzar`,
pregunta dónde tenés la plata y en qué se te va.

**Consequences.**
- **Los padres son estructura; los hijos son opinión.** `Gastos fijos` y `Gastos variables` no son una
  preferencia: son la corrección del error 2 del análisis —la planilla mezclaba el TIPO de operación
  con el CONCEPTO— y sin ellos el modelo no se entiende. `Restaurantes` era gusto de quien escribió
  el bootstrap metido en el libro de otro. De 20 categorías a 6.
- `Intereses` y `Ajustes` se quedan y no son negociables:
  [ADR-013](#adr-013--la-cuenta-remunerada-es-una-cuenta-bancaria-su-interés-es-un-ingreso-mensual),
  [ADR-014](#adr-014--el-plazo-fijo-reconoce-su-interés-al-vencimiento) y
  [ADR-005](#adr-005--el-ajuste-de-saldo-es-un-movimiento-más-contra-una-categoría-de-sistema)
  dependen de que existan. Ahora se marcan *del sistema* **en la lista**, no solo al abrirlas:
  descubrir que no se pueden borrar recién al intentar borrarlas es descubrirlo tarde.
- Las sugerencias de la puesta en marcha **se tildan, no vienen creadas**. Lo que no elegís no existe.
- **La parte incómoda:** esto revierte una decisión escrita y razonada. El bootstrap decía *"una
  cuenta mínima para que el primer gasto se pueda cargar sin configurar nada: el MVP se mide en que
  registrar un gasto lleve menos de diez segundos"*. Ahora hay dos pasos antes del primer gasto. Se
  acepta porque **no se puede registrar un gasto sin decir de dónde salió**, y preguntarlo una vez es
  más honesto que inventar la respuesta — la cuenta inventada igual había que renombrarla o borrarla.
- Los libros que ya existen no cambian: el trigger solo corre en altas nuevas. Para ver la puesta en
  marcha hace falta registrarse con otro correo.

**Rejected alternatives.**
- *Dejar la cuenta sembrada y que la guía se pueda saltear*: protegía el criterio de los diez
  segundos, pero una guía que no hace falta es una guía que nadie lee, y quedaba una cuenta que el
  usuario no eligió.
- *Que la guía muestre `Efectivo ARS` ya creada para confirmar o renombrar*: nadie arranca sin cuenta
  y nadie se queda con una que no quiso, pero el paso 1 pasa a tener que editar además de crear.
  Descartada por complejidad frente al beneficio.
- *No sembrar ninguna categoría*: deja al usuario frente a una taxonomía en blanco, que es una tarea
  más difícil que elegir de una lista. Y rompería tres ADRs que dependen de las de sistema.

**Evidence.** `supabase/migrations/20260918100000_alta_minima.sql`,
`src/routes/comenzar/+page.svelte`, `supabase/tests/01_use_cases.sql`.

**Verified against what already exists.**

```
Al sacar las categorias sembradas la bateria quedo VERDE con 114 aserciones en
vez de 115. Verde, y con una asercion MENOS.

  ok  category_usage marca en 0 las no usadas    <- apuntaba a 'Transporte'

Sin esa categoria la consulta no devolvia fila, el CASE no se evaluaba nunca y
nadie se enteraba. Se reescribio para que FALLE si la categoria de control no
existe, en vez de desaparecer:

  select case when count(*) = 0 then 'FALLO  la categoria de control no existe'
              when min(movimientos) = 0 then 'ok  ...'
```

La diferencia se encontró comparando la lista de aserciones contra `git stash -u`.
**Un `stash` sin `-u` deja las migraciones nuevas en el disco** y la corrida "antes"
mide el estado equivocado: el primer intento dio un diff de 114 líneas sin sentido.


---

## ADR-028 — El libro activo vive en la base, y compartir uno se hace por código

**Context.** `ledger_member` está en el esquema desde el primer día con sus políticas de RLS, y en la
interfaz no había nada. Parecía faltar una pantalla de invitaciones. Al mirarlo, faltaba algo mucho
más grande:

```sql
create function my_ledger() as $$ select * from my_ledgers() limit 1 $$;
create policy ... using (ledger_id in (select my_ledgers()))
```

El día que alguien perteneciera a dos libros, **sin cambiar una sola línea**:

1. **Toda lectura habría devuelto los dos libros mezclados.** La política filtra por *"alguno de los
   tuyos"*, no por *"el que estás mirando"*: los gastos de dos personas en la misma lista, sumados en
   el mismo resultado del mes.
2. **Toda escritura habría ido a uno arbitrario.** `limit 1` sin `order by` no es *"el primero"*: es
   cualquiera, y puede cambiar entre dos consultas.

**Decision.** Existe un **libro activo por usuario**, guardado en la base, y RLS filtra por él. Las
invitaciones son un **código de un solo uso** que el dueño genera y pasa por donde quiera.

**Consequences.**
- **El libro activo vive en la base y no en el cliente**, por la misma razón de
  [ADR-003](#adr-003--cada-usuario-tiene-su-libro-y-la-interfaz-nunca-lo-nombra): si cada consulta
  tuviera que acordarse de filtrar, alcanza con olvidarse en UNA para volver a mezclar, y consultas
  nuevas se escriben todo el tiempo. Cambiar de libro es un `UPDATE` y la app entera cambia con él,
  incluidas las pantallas que se escriban el año que viene.
- **La línea de permisos está donde duele el error.** Un invitado registra y borra *movimientos*; no
  crea ni borra *cuentas y categorías*, ni invita. Un movimiento mal cargado se corrige; una cuenta
  borrada se lleva su historia.
- **Por código y no por correo.** Buscar a alguien por su correo exige una función que diga si ese
  correo está registrado, y eso es un enumerador de usuarios. Con un código no hace falta saber nada
  del otro. La tabla `ledger_invite` **no tiene grants ni políticas**: si se pudiera leer, se podrían
  listar los códigos vigentes. Solo la tocan dos funciones `SECURITY DEFINER`.
- El mismo mensaje de error para *"no existe"*, *"ya se usó"* y *"venció"*: distinguirlos convertiría
  el endpoint en un oráculo para adivinar códigos.
- **La parte incómoda:** se miran de a uno, nunca juntos. No hay total del hogar. Sumarlos abriría
  preguntas que hoy no tienen respuesta —las categorías de cada libro son distintas, así que *"¿en qué
  se fue?"* no se puede sumar— y un número que mezcla dos economías no es de nadie.
- `my_ledger()` pasó a `SECURITY DEFINER` porque ahora la llaman las políticas de RLS de todas las
  tablas: como invocador, leer `active_ledger` dispararía su propia política y entraría en recursión.

**Rejected alternatives.**
- *Que el cliente filtre por `ledger_id` en cada consulta*: es la opción que no toca el esquema y la
  peor. Una consulta olvidada mezcla los libros **sin fallar**, que es exactamente el modo de falla
  que este proyecto viene persiguiendo.
- *Invitar por correo*: más cómodo, y convierte la app en un verificador de si un correo está
  registrado.
- *Una vista combinada de todos los libros*: descartada por ahora — ver arriba.
- *Un solo rol, "si te invito es porque confío"*: menos código de permisos que pueda tener un agujero,
  pero cualquiera de los dos puede borrar una cuenta con años de historia sin que el otro se entere.

**Evidence.** `supabase/migrations/20260918150000_libros_compartidos.sql`,
`supabase/tests/15_libros.sql`, `src/routes/libros/+page.svelte`.

**Verified against what already exists.**

```
docker: postgres:16 descartable, suite completa -> 146 aserciones ok

ok  el invitado arranca con su propio libro
ok  y no ve NADA del libro ajeno antes de que lo inviten
ok  al aceptar pasa a tener dos libros
ok  y exactamente UNO esta activo
ok  un invitado puede registrar movimientos
ok  un invitado NO puede crear cuentas
ok  un invitado NO puede borrar categorias
ok  un invitado NO puede invitar a nadie mas
ok  un codigo ya usado no sirve de nuevo
ok  al volver a su libro NO ve los movimientos del otro
ok  ni una sola cuenta ajena
```

Las dos últimas son el ADR entero: **el mismo usuario, dos libros, y cero filtración entre ellos.**


---

## ADR-029 — La fuente de precios locales es data912, con BYMA de respaldo, y el precio se guarda como se cotiza

**Context.** [ADR-025](#adr-025--los-precios-se-traen-solos-todos-los-días-porque-el-de-hoy-no-se-recupera-mañana)
eligió BYMA y descartó data912 por ser *"un intermediario más"*. El usuario pegó su cartera real
—dieciséis papeles— y eso alcanzó para dar vuelta la decisión:

```
BYMA /cedears          SPY QQQ MSFT META GOOGL GLD      6 de 16
BYMA /leading-equity   YPFD PAMP BMA ECOG               existe, sin usar
BYMA /public-bonds     AL30 AL29                        existe, sin usar
BYMA (ninguno)         TLCTO PN43O IRCPO DNC7O          no las publica

data912  arg_cedears · arg_stocks · arg_bonds · arg_corp  -> los 16
```

**BYMA no publica obligaciones negociables en su API libre** (`corporate-bonds` y
`negotiable-obligations` devuelven 401). No es una preferencia: con BYMA sola, cuatro papeles de la
cartera del usuario no tienen precio y nunca lo van a tener.

Y apareció algo peor mientras se verificaba: **un bono no cotiza por unidad, cotiza por cada 100
nominales.** `AL30` vale `85100`, y eso es por 100 VN. Guardarlo como precio unitario haría que una
tenencia de 10.000 nominales valiera **cien veces de más** — y no fallaría: mostraría un patrimonio
enorme y perfectamente creíble.

**Decision.** data912 es la fuente principal para todo el mercado local y BYMA queda de respaldo real.
El precio se guarda **tal como se cotiza**, y el instrumento declara a cuántas unidades corresponde
(`quote_size`).

**Consequences.**
- *"BYMA para lo que puede y data912 para el resto"* se descartó por ser lo peor de las dos: **dos
  fuentes para el mismo trabajo son dos formas de romperse y dos formatos que mantener.** data912 va
  primero para todo; si desaparece, BYMA cubre CEDEARs, acciones y bonos públicos, y solo se pierden
  las ON. Verificado apuntando el script a un host inválido.
- **La lámina vive en el modelo, no en el script.** Si la división por 100 estuviera en
  `precios.mjs`, quien cargue un precio a mano escribiría el `85100` que ve en su broker y volvería a
  estar cien veces arriba. `valor = saldo × precio / quote_size`, y un trigger la fija en 100 para los
  bonos —un bono con lámina 1 siempre está mal, así que corregir ese caso no pisa ninguna intención.
- **La parte incómoda:** se depende de un intermediario. data912 es el proyecto de un tercero y puede
  cerrar mañana; BYMA es la fuente. Se acepta porque la alternativa no es *"depender de BYMA"* sino
  *"no medir cuatro de mis papeles"*.

**Rejected alternatives.**
- *Solo BYMA*: es la decisión que esto revierte. Deja sin precio a las obligaciones negociables, para
  siempre.
- *Las dos fuentes en paralelo, cada una para lo suyo*: el doble de superficie de falla para el mismo
  resultado.
- *Dividir por 100 al ingerir el precio*: más simple y rompe la carga manual en silencio.

**Evidence.** `scripts/precios.mjs`, `supabase/migrations/20260918170000_lamina.sql`,
`supabase/tests/10_posiciones.sql`.

**Verified against what already exists.**

```
Los 16 papeles reales del usuario, contra el script:
  16 precios de 16 instrumento/s

Con data912 apuntando a un host invalido (prueba de mutacion):
  SPY   20210  byma
  YPFD   8670  byma
  AL30  85010  byma
  sin precio  TLCTO — ninguna fuente lo cotiza hoy

Y la lamina, contra postgres:
  ok  un bono nace cotizando por 100 nominales
  ok  10.000 nominales a 85.100 por cien valen 8.510.000
  ok  y la lista de posiciones dice lo mismo
  ok  una accion sigue cotizando por unidad
```

Sin la lámina, esa tenencia habría valido **851.000.000** en vez de 8.510.000.


---

## ADR-030 — Qué tipo es, cómo se llama y dónde está son tres preguntas distintas

**Context.** El usuario dijo que los tipos de cuenta estaban mal: *"una cuenta banco como tal no tiene
sentido, tampoco una que sea billetera virtual… si es una caja de ahorro es una caja de ahorro
independientemente de que le quieras poner el nombre «Banco»"*. Al mirarlo, tenía razón y había algo
peor debajo.

El formulario preguntaba **«¿Tengo plata acá o debo plata acá?»** —un eje de los tres que el modelo
tiene— y derivaba el resto:

```ts
const spendable = $derived(kind === 'asset');
```

Con eso, **toda cuenta de activo creada a mano quedaba como plata disponible**, así que **no había
forma de cargar una cuenta comitente**: el efectivo parado en un broker aparecía en *"Disponible"*
junto a la caja de ahorro, siendo justamente la plata que no se puede gastar mañana.

Y la puesta en marcha ofrecía `Efectivo`, `Banco`, `Mercado Pago`, `Tarjeta`, `Dólares`. De esos, dos
no son tipos: *Banco* es el **dónde** y *Mercado Pago* es una **institución**.

**Decision.** Se preguntan tres cosas por separado: **qué tipo es**, **cómo la llamás** y **dónde
está**. Los tipos son los que el modelo ya distinguía, y viven en un solo archivo.

**Consequences.**
- Los tres tipos del formulario general son **caja de ahorro o efectivo**, **cuenta de inversión** y
  **tarjeta de crédito**. El plazo fijo y la posición tienen pantalla propia porque piden datos que
  ninguno de esos necesita: un vencimiento y un instrumento con su precio.
- **La diferencia entre caja de ahorro y cuenta de inversión es `is_spendable`, y es la que faltaba.**
  Las dos guardan dinero; solo una entra en *"cuánto puedo gastar hoy"*, que es el punto 8 del brief.
- **El tipo se deduce de lo que la cuenta ES, nunca de su nombre.** Renombrarla no puede cambiar cómo
  se la trata — mismo criterio que la categoría de ajustes, que se busca por `is_system` y no por
  llamarse *"Ajustes"*.
- La puesta en marcha ahora pregunta el **dónde**, que es lo que después hace que la vista *Por banco*
  tenga algo que agrupar. Antes creaba todo sin institución y esa vista no aparecía nunca.
- **La parte incómoda:** el primer paso tiene más campos que antes. Se acepta porque el que se saltea
  el *dónde* no pierde nada —es opcional— y el que se saltea el **tipo** terminaba con una cuenta
  comitente contada como plata disponible, sin enterarse.

**Rejected alternatives.**
- *Solo agregar la opción "no es gastable" al formulario*: tapa el agujero concreto con el mínimo
  cambio, y deja el tipo y el nombre mezclados, que es lo que hizo que el agujero existiera.
- *Inferir el tipo del nombre* (un nombre que diga "Balanz" es comitente): adivinar sobre texto libre,
  y renombrar la cuenta cambiaría la contabilidad.
- *Un tipo por producto* (billetera virtual, cuenta sueldo, cuenta corriente): son nombres comerciales
  del mismo objeto. Si dos tipos hacen exactamente lo mismo, no son dos tipos.

**Evidence.** `src/lib/ledger/tipos.ts`, `src/routes/cuentas/nueva/+page.svelte`,
`src/routes/comenzar/+page.svelte`.

**Verified against what already exists.**

```
El modelo YA tenia los tres ejes; la pantalla usaba uno:

  kind          asset | liability
  valuation     balance | accrual | market
  is_spendable  boolean

  caja de ahorro      asset  balance  spendable=true    -> Disponible
  cuenta comitente    asset  balance  spendable=FALSE   -> no Disponible
  tarjeta             liability balance                 -> deuda
  plazo fijo          asset  accrual                    -> vence
  posicion            asset  market                     -> unidades x precio

No hizo falta ni una migracion: lo que faltaba era preguntarlo.
```

**Ningún cambio de esquema.** El modelo distinguía las cinco cosas desde el primer día; la interfaz
preguntaba por dos.


---

## ADR-031 — Una cuenta puede estar en varias carteras, y la del broker se arma sola

**Context.** El usuario preguntó cómo se relacionan institución y cartera, y al explicárselo aparecieron
dos huecos. `account.portfolio_id` era **un campo**, así que AAPL podía estar en *"Todo"* o en
*"Tecnología"*, nunca en las dos. Y **no se creaba ninguna cartera sola**: había que armarla y tildar
cuenta por cuenta, y hasta hacerlo el rendimiento se medía mal **en silencio** —
[ADR-026](#adr-026--el-portafolio-es-el-borde-es-flujo-solo-lo-que-lo-cruza) dice que una cuenta suelta
hace que comprar con ese efectivo cuente como aporte nuevo.

**Decision.** La pertenencia pasa a una tabla `portfolio_account`, y una cuenta de broker entra sola a
la cartera de su institución.

**Consequences.**
- **Lo que parecía una contradicción es la respuesta correcta.** Con carteras que se solapan, la misma
  compra puede ser aporte en una y movimiento interno en otra:

  ```
  "Binance"      tiene la posición Y el efectivo del broker
  "Solo cripto"  tiene solo la posición

  comprar LTC con dólares de Binance:
    para "Binance"      las dos patas adentro  -> NO es aporte
    para "Solo cripto"  la plata vino de afuera -> SÍ es aporte, de 500
  ```

  Las dos son ciertas porque **los bordes son distintos**, y ADR-026 define el flujo por borde, no por
  operación. No hubo que cambiar la regla: hubo que dejar de suponer un solo borde por cuenta.
- **Lo que sí se rompía era la fuente de cotización.** `valor_cuenta` resolvía cuenta → cartera →
  libro, y con varias carteras *"la cartera"* es ambiguo. Se bajó un nivel: la **cuenta** se mide con
  su propia fuente o la del libro, y la de la cartera se aplica al valuar **esa** cartera. Cada borde
  convierte con su vara, que es lo que [ADR-023](#adr-023--la-unidad-de-medida-es-un-parámetro-dólares-o-poder-adquisitivo)
  ya decía.
- **La cartera del broker se arma sola** por `institution`: una posición o un efectivo **no gastable**
  que diga dónde está entra a la cartera de ese lugar, creándola si hace falta. Sale gratis porque
  `comprar_activo` ya guardaba el broker ahí.
- **Una caja de ahorro NO crea cartera.** Tener plata en el Macro no es invertir, y meterla adentro
  haría que mover plata del banco al broker dejara de contarse como aporte.
- **La parte incómoda:** aparecen carteras que nadie pidió. Se acepta porque la alternativa era medir
  mal hasta que el usuario se acordara de tildar, y eso no avisa.
- `carteras` reemplaza al campo nulo para saber si una cuenta está suelta: ahora es un contador en
  cero.

**Rejected alternatives.**
- *Dejar un solo portafolio por cuenta y agregar solo la cartera por defecto*: la mitad del pedido, y
  la mitad que no resuelve querer mirar los mismos activos agrupados de otra forma.
- *Crear la cartera por defecto dentro de `comprar_activo`*: habría que copiar esa función entera para
  no perderle nada. Con el trigger la regla vale para cualquier alta de cuenta.
- *Agrupar por `institution` directamente, sin tabla de carteras*: vuelve a mezclar **dónde está** con
  **qué se mide junto**, que [ADR-026](#adr-026--el-portafolio-es-el-borde-es-flujo-solo-lo-que-lo-cruza)
  ya había separado.

**Evidence.** `supabase/migrations/20260918190000_carteras_multiples.sql`,
`supabase/tests/14_portafolios.sql`.

**Verified against what already exists.**

```
docker: postgres:16 descartable, suite completa -> 158 aserciones ok

ok  una posicion puede estar en dos carteras a la vez
ok  el broker entero sigue viendo 2 flujos: deposito y retiro
ok  para la cartera tematica esa compra SI fue un aporte de 500
ok  y vale solo la posicion: 600, sin el efectivo del broker
ok  una cuenta de broker crea sola la cartera de su institucion
ok  y queda adentro sin tildar nada
ok  la segunda cuenta del mismo broker reusa la cartera
ok  una caja de ahorro NO crea cartera: tener plata no es invertir
```

La tercera y la segunda juntas son el ADR entero: **la misma compra, dos lecturas, las dos ciertas.**


---

## ADR-032 — Aportar a otro libro es gastar, y son dos movimientos, uno por libro

**Context.** El usuario planteó el caso de una cuenta compartida con una pareja: harían falta **tres**
libros —el de cada uno más el común— y poder pasar plata desde los personales al común. Dos cosas lo
impedían, y solo una era fácil.

**No se podía crear un libro.** El único lugar donde nacía uno era el trigger de alta, así que se era
dueño de exactamente uno; los demás llegaban solo por invitación, y entonces el "común" tendría que
ser el de alguno de los dos.

**Y un movimiento no puede cruzar libros**, por diseño:

```sql
constraint entry_account_same_ledger
  foreign key (account_id, ledger_id) references account(id, ledger_id)
```

Eso no es un límite a esquivar: es lo que hace que **cada libro cierre en cero por sí solo**. Si una
pata viviera afuera, ningún libro cerraría solo y la partida doble dejaría de servir como control.

**Decision.** Se puede crear un libro. Pasar plata a otro libro son **dos movimientos encadenados**,
uno en cada libro, unidos por una referencia común — y en el libro de origen es un **gasto**.

**Consequences.**
- **Aportar es gastar, y lo decidió el usuario.** Esa plata ya no la podés usar solo, así que tu
  patrimonio baja. La alternativa —que siguiera siendo tuya— exigiría modelar **qué parte** del fondo
  común te pertenece, y esa parte cambia cada vez que cualquiera aporta o el fondo gasta. Es un
  concepto nuevo, y el más caro de todo lo construido hasta acá.
- **La parte incómoda:** si el libro común se disuelve y te devuelven la plata, entra como ingreso. Tu
  historia va a mostrar un gasto y un ingreso donde hubo un ida y vuelta. Es el precio de no modelar
  participaciones, y se acepta porque la app es de finanzas personales, no de sociedades.
- `entry_account_same_ledger` **no se tocó.** La regla se cumple: cada mitad vive entera en su libro.
- Hizo falta arreglar antes cómo se identifica una categoría de sistema. Se buscaban por `is_system`
  **más el tipo** —"la de sistema de gasto" era la de ajustes—, y eso alcanzaba con dos roles y **se
  rompe con cuatro**: el aporte enviado también es `is_system` y de gasto, así que el resumen del mes
  lo habría contado como ajuste de saldo y habría desaparecido de *"en qué se fue"*. Ahora hay
  `category.system_role`, y `is_system` vuelve a significar solo lo que siempre significó: no se
  borra.
- Las categorías de aportes **se crean recién cuando se usan**: quien nunca comparta un libro no tiene
  por qué verlas.
- Se agregó una excepción mínima a RLS —`cuentas_de_libro()`— para poder elegir la cuenta de destino:
  devuelve nombre y moneda, solo de libros a los que pertenecés, y no abre los movimientos ni los
  saldos del otro libro.
- Solo entre cuentas de **la misma moneda**: un aporte no es un cambio. Si hay que cambiar, son dos
  operaciones y conviene que se vean las dos.

**Rejected alternatives.**
- *Un movimiento con patas en dos libros*: rompe el invariante que hace que cada libro cierre solo.
- *Una cuenta "Fondo común" en tu libro con lo aportado*: tu patrimonio no baja y el número miente en
  cuanto el fondo gasta. Solo no se nota porque los libros nunca se suman —
  [ADR-028](#adr-028--el-libro-activo-vive-en-la-base-y-compartir-uno-se-hace-por-código)— y apoyarse
  en eso es apoyarse en que nadie mire.
- *Modelar participaciones en el libro común*: la respuesta completa, y un proyecto entero.

**Evidence.** `supabase/migrations/20260918200000_aportes.sql`, `supabase/tests/15_libros.sql`,
`src/routes/libros/+page.svelte`.

**Verified against what already exists.**

```
docker: postgres:16 descartable, suite completa -> 165 aserciones ok

ok  ahora se puede ser duenio de mas de un libro
ok  el libro nuevo nace con la misma siembra que uno de alta
ok  en mi libro el aporte SALE de la cuenta
ok  y se registra como GASTO, no como transferencia
ok  en el libro comun la plata ENTRA
ok  las dos mitades quedan unidas por la misma referencia
ok  ningun movimiento quedo con lineas de dos libros

Y del lado del cliente:
ok  un aporte a otro libro es un GASTO, no un ajuste de saldo
ok  el ajuste de saldo sigue siendo un ajuste
```

La última de la base es la que importa: **se agregó plata entre libros sin que ningún movimiento
cruce libros.**
