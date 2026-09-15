# Análisis inicial — aplicación de finanzas personales

> Respuesta a la "Primera tarea" del `porposal.md`. **Cero código.**
> Este documento NO es un diseño cerrado: es el material para discutir. Todo lo marcado
> con 🟡 es una decisión abierta que necesito que resuelvas vos.

---

## 0. Antes que nada: dónde se rompe tu modelo actual

Empiezo por acá y no por la lista de conceptos, porque estos siete errores son los que
determinan cómo tiene que ser el modelo. Si no los vemos primero, vamos a diseñar una
base de datos preciosa sobre una idea equivocada.

Vos ya detectaste dos de ellos en el documento. Los otros cinco no.

### Error 1 — Tu fórmula del resultado mensual está mal

Escribiste:

```
Ingresos - Gastos - Ahorros - Inversiones = resultado del mes
```

Esto NO mide tu resultado. Mide **cuánta plata te sobró en la cuenta corriente**, que es
otra cosa completamente distinta.

Mirá lo que implica: si este mes ahorrás $300.000 más que el mes pasado, tu "resultado"
**empeora en $300.000**. La fórmula te castiga por ahorrar. Es exactamente al revés de lo
que querés medir.

El ahorro y la inversión **no son restas del resultado: son destinos del resultado**.

Lo correcto son dos preguntas separadas:

```
1) ¿Cómo me fue?        Resultado = Ingresos - Gastos
2) ¿Dónde quedó?        Resultado → se reparte entre: caja / ahorro / inversión
```

Un mes donde ganaste $2.000.000, gastaste $1.400.000 y mandaste $600.000 al broker
tuvo un resultado de **+$600.000**, no de **$0**. Tu patrimonio creció $600.000.

Esta distinción — **flujo de resultado** vs. **asignación del resultado** — es la columna
vertebral de todo el modelo.

### Error 2 — La columna "categoría" está haciendo dos trabajos incompatibles

En tu hoja, la columna categoría contiene cosas como `Ingresos`, `Gastos fijos`,
`Ahorros`, `Inversiones`, `Supermercado`, `Alquiler`.

Ahí hay **dos ejes distintos mezclados en una sola columna**:

| Eje | Qué responde | Valores |
|---|---|---|
| **Tipo de movimiento** | ¿qué clase de operación es? | ingreso, gasto, transferencia, cambio de moneda, compra/venta de activo |
| **Concepto** | ¿para qué fue la plata? | supermercado, alquiler, transporte, sueldo |

Son ortogonales. `Supermercado` es un concepto, `Gasto fijo` es un tipo. Mezclarlos es por
qué la hoja no puede responder "¿cuánto transferí a ahorro este mes?" sin que ese número
contamine "¿cuánto gasté?".

En el modelo nuevo van separados y no se negocia.

### Error 3 — Comprar dólares como gasto (este lo detectaste vos) ✅

Correcto, y coincido: comprar USD no es un gasto, es una **transformación**. Tu patrimonio
antes y después es el mismo, solo cambió de denominación.

Pero hay un corolario que **no** mencionaste y que es más traicionero:

> Si comprás USD a $1.200 y el dólar se va a $1.500, tu patrimonio medido en pesos
> aumentó **sin que haya existido ningún movimiento**.

Eso es una **ganancia de valuación no realizada**. No es un ingreso. Si la metés en la
misma bolsa que tu sueldo, tu "ingreso mensual" se vuelve ruido puro y no podés proyectar
nada. Tiene que vivir en un lugar aparte del modelo.

Regla general que se desprende: **tu patrimonio puede cambiar sin que haya movimientos**.
Cualquier modelo que solo tenga una tabla de movimientos es incapaz de representar esto.

### Error 4 — La tarjeta de crédito

Este es el caso que rompe el 90% de las hojas de cálculo de finanzas personales, y tu
documento no lo menciona ni una vez.

El problema: **el momento del gasto y el momento del pago son distintos**. Comprás en
marzo, pagás el resumen en abril. ¿En qué mes fue el gasto?

Tres formas de resolverlo:

| Opción | Cómo | Ventaja | Costo |
|---|---|---|---|
| **A** | Registrar solo el pago del resumen | 1 movimiento por mes, mínima fricción | Perdés TODO el detalle por categoría. Un renglón de $800.000 "Tarjeta" no te dice nada. Y el gasto queda corrido un mes |
| **B** | Cada compra contra un **pasivo** `Tarjeta Visa`; el pago del resumen es una transferencia | Correcto. El gasto queda en su mes y con su categoría. Tu patrimonio refleja la deuda | Más movimientos que cargar |
| **C** | Híbrido: compras grandes en detalle, el resto al bulto | — | Lo peor de los dos: números que no cierran |

**Recomiendo B**, y con una consecuencia que quiero que veas clarísima:

> **Pagar el resumen de la tarjeta NO es un gasto.** Es cancelar una deuda: sale plata del
> banco y baja tu pasivo. Tu patrimonio no cambia en ese momento — ya había cambiado
> cuando compraste.

Si el sistema cuenta la compra Y el pago del resumen, **duplica todos tus gastos**. Este
error es tan común que vale la pena escribirlo dos veces.

### Error 5 — Guardar inversiones en plata en vez de en unidades

Si registrás "tengo $500.000 en el broker", el modelo es **incapaz** de distinguir entre:

- puse $500.000 y no rindió nada
- puse $400.000 y rindió $100.000
- puse $600.000, perdí $200.000 y aporté $100.000 más

Son tres realidades opuestas con el mismo número. Para separarlas hay que guardar dos
cosas distintas:

- **cuántas unidades tenés** de cada activo (10 acciones de AAPL, 350 cuotapartes del FCI)
- **cuánto vale cada unidad** en cada fecha (una serie de precios)

El valor es el resultado, nunca el dato de entrada. Esto no es opcional para cumplir con
tus puntos 12, 13 y 14.

### Error 6 — Medir rendimiento en pesos nominales (Argentina)

Este es el más peligroso de todos y es por el que te dije que quería el rol de analista
financiero.

Si en Argentina tu plazo fijo "rindió 90% anual" y la inflación fue 100%, **perdiste
plata**. El sistema te va a mostrar un +90% en verde y va a estar mintiendo.

Medir rendimiento en ARS nominal hace que **todo parezca una gran inversión**. Es el
equivalente financiero de medir tu altura con una regla que se estira.

Opciones de moneda de medición:

| Opción | Pros | Contras |
|---|---|---|
| **USD (MEP)** | Simple, es lo que la gente usa en la práctica para saber si ganó | Depende de una cotización; el dólar tampoco es estable en términos reales |
| **Pesos constantes (ajuste por IPC)** | Técnicamente lo más correcto | Requiere serie de IPC; el INDEC publica con retraso |
| **ARS nominal** | Cero trabajo | Sistemáticamente engañoso |

🟡 **Mi recomendación: USD como moneda de medición del rendimiento, ARS como moneda de
registro del día a día.** Nominal en pesos solo como dato secundario, nunca como el número
grande de la pantalla.

### Error 7 — Vender no es ganar (tu punto 14)

Planteaste bien la preocupación pero la conclusión correcta es más fuerte de lo que
escribiste. Si el sistema valúa tus activos a precio de mercado de forma continua:

> **En el momento de la venta tu patrimonio NO cambia.**

Comprás 10 acciones a $100 ($1.000). Suben a $150: tu patrimonio ya vale $1.500 y ya
registró +$500 de ganancia **no realizada**. Cuando vendés, cambiás $1.500 en acciones
por $1.500 en efectivo. Patrimonio: idéntico. Lo único que pasó es que la ganancia pasó
de **no realizada** a **realizada**.

Si el sistema trata la venta como un ingreso de $1.500, te cuenta la ganancia dos veces.
Ese es el bug que temés, y la vacuna es tener explícito en el modelo el concepto de
**resultado no realizado vs. realizado**.

---

## 1. Los conceptos que debería tener el dominio

De los siete errores se desprende el modelo. La idea central:

> **Todo movimiento de dinero tiene origen y destino.** Siempre. Sin excepción.

Eso es partida doble. Antes de que te asustes, dos aclaraciones:

1. **No estoy proponiendo un sistema contable.** No hay plan de cuentas, ni balance, ni
   asientos de ajuste, ni debe/haber en la pantalla.
2. **La UI nunca lo muestra.** Vos apretás "Gasto → Supermercado → $25.000 → Débito →
   Guardar". El modelo por detrás escribe origen y destino. Son 5 taps igual.

Lo que ganás con eso: **es imposible registrar algo inconsistente**. La plata no aparece
ni desaparece. Y todas las preguntas del punto 8 de tu documento salen de una sola
consulta.

### Entidades núcleo

| Concepto | Qué representa | Ejemplos |
|---|---|---|
| **Cuenta** (`Account`) | Un lugar donde hay plata tuya | Efectivo ARS, Santander ARS, Mercado Pago, Broker (efectivo), Plazo fijo, **Visa (pasivo)** |
| **Categoría** (`Category`) | Para qué entró o salió la plata del sistema | Sueldo, Supermercado, Alquiler, Transporte. Jerárquica: categoría → subcategoría |
| **Movimiento** (`Transaction`) | Un hecho económico, con fecha y descripción | "Compra semanal en el chino" |
| **Línea** (`Entry`) | Cada pata del movimiento: cuenta o categoría + monto | −25.000 de Santander / +25.000 a Supermercado |
| **Activo** (`Instrument`) | Algo invertible que cotiza | AAPL, SPY, AL30, BTC, un FCI |
| **Posición** (`Holding`) | Cuántas **unidades** tenés de un activo | 10 AAPL, 0,05 BTC |
| **Precio** (`Price`) | Cuánto vale una unidad en una fecha | AAPL @ 2026-09-15 = USD 214 |
| **Cotización** (`FxRate`) | Tipo de cambio en una fecha, **con su fuente** | USD/ARS MEP @ 2026-09-15 = 1.487 |
| **Presupuesto** (`Budget`) | Cuánto esperás gastar en una categoría en un período | Supermercado, sep-2026, $250.000 |
| **Regla recurrente** (`RecurringRule`) | Plantilla + frecuencia de un gasto que se repite | Seguro del auto, anual, cada julio |

### Cómo se ve cada operación tuya en este modelo

| Lo que hacés | Origen | Destino | ¿Cambia tu patrimonio? |
|---|---|---|---|
| Gasto con débito | Cuenta banco | Categoría *Supermercado* | **Sí**, baja |
| Cobrás el sueldo | Categoría *Sueldo* | Cuenta banco | **Sí**, sube |
| Pasás plata a la billetera | Cuenta banco | Cuenta Mercado Pago | **No** |
| **Comprás USD** | Cuenta ARS | Cuenta USD | **No** (registra el tipo de cambio) |
| Transferís al broker | Cuenta banco | Cuenta broker (efectivo) | **No** |
| **Comprás un ETF** | Cuenta broker (efectivo) | Posición en SPY | **No** |
| Cobrás dividendos | Categoría *Dividendos* | Cuenta broker (efectivo) | **Sí**, sube |
| **Vendés el ETF** | Posición en SPY | Cuenta broker (efectivo) | **No** (la ganancia ya estaba) |
| Comprás con tarjeta | **Pasivo Visa** | Categoría *Restaurantes* | **Sí**, baja |
| **Pagás el resumen** | Cuenta banco | **Pasivo Visa** | **No** |
| Sube el dólar / sube AAPL | *(no hay movimiento)* | — | **Sí**, por revaluación |

Mirá la última fila: **es la única que no tiene movimiento**. Por eso el patrimonio no
puede calcularse solo sumando movimientos. Necesita la capa de precios y cotizaciones.

### Las tres preguntas que el modelo separa

```
FLUJO      ¿de dónde vino y adónde fue?   → movimientos
STOCK      ¿cuánto tengo y dónde?          → saldos por cuenta + unidades por activo
VALOR      ¿cuánto valgo?                  → stock × precios × tipo de cambio, a una fecha
```

Tu hoja de cálculo intentaba responder las tres con una sola tabla. Por eso no cerraba.

---

## 2. Qué conviene MANTENER de tu hoja de cálculo

Sé duro conmigo si te parece, pero esto lo hiciste bien y no lo pienso tocar:

1. **El set de categorías.** Ingresos / fijos / variables / ahorro / inversión / caridad
   es una taxonomía sana, probada por vos durante años. Se mantiene casi tal cual —
   con la corrección de que *Ahorro* e *Inversión* dejan de ser categorías de gasto y
   pasan a ser **cuentas**.
2. **Categoría + subcategoría.** Dos niveles. Suficiente y correcto. No agregamos un
   tercero.
3. **El campo `notas`.** Parece menor, es lo que salva el contexto seis meses después.
4. **El período mensual como unidad de análisis.** Es el ritmo real de la vida financiera.
5. **Multi-moneda desde el día uno.** ARS + USD. Acertaste en no dejarlo para después:
   agregarlo más tarde obliga a reescribir todo.
6. **El diagnóstico de cuál era el problema real.** Dijiste que el problema NO era el
   análisis sino **la fricción de carga**. Eso es una definición de producto excelente y
   ordena todas las prioridades del MVP. La mayoría de la gente construye el dashboard
   primero y abandona la app a los dos meses porque cargar un gasto es un suplicio.

---

## 3. Qué conviene CAMBIAR

1. **Una tabla plana → movimientos con origen y destino** (errores 1, 2, 3).
2. **"Ahorro" e "Inversión" dejan de ser categorías de gasto y pasan a ser cuentas**
   (error 1). Mover plata al fondo de emergencia es una transferencia, no un gasto.
3. **Aparecen los pasivos.** Tarjetas de crédito y préstamos. Sin esto tu patrimonio está
   inflado (error 4).
4. **Aparece la capa de valuación:** precios y cotizaciones con fecha y fuente
   (errores 3, 5, 6).
5. **Las inversiones se guardan en unidades, no en pesos** (error 5).
6. **Ganancia realizada y no realizada son conceptos distintos y explícitos** (error 7).
7. **Nada se borra, todo se archiva.** Vos mismo lo pediste en tus principios. Categorías,
   cuentas y activos se desactivan; jamás se eliminan si tienen historia.
8. **La moneda de medición se elige y se muestra.** Todo número grande de la pantalla dice
   en qué moneda está y con qué cotización se calculó (tu principio de transparencia).

---

## 4. Qué debería incluir el MVP

Criterio de corte, y es innegociable: **el MVP existe para reemplazar la hoja de cálculo
en lo que la hoja hacía mal — cargar. Nada más.**

Si el MVP incluye inversiones, no lo vas a terminar. Y si lo terminás, vas a haber pasado
tres meses sin usar la app.

### Entra

- **Autenticación** para ~3 usuarios
- **Cuentas**: crear, editar, archivar. Tipos: efectivo, banco, billetera, tarjeta (pasivo)
- **Categorías** con subcategorías, precargadas con tu set actual y editables
- **Registrar movimiento en ≤ 5 toques**, con estos tipos:
  - Gasto
  - Ingreso
  - Transferencia entre cuentas
  - Cambio de moneda (ARS ↔ USD)
- **Lista del mes**: ver, filtrar, editar, borrar
- **Saldos**: por cuenta y totales por moneda
- **Resumen del mes**: ingresos, gastos, resultado, tasa de ahorro
- **Export CSV + JSON** (tu principio de no quedar atado)
- **PWA instalable**

### NO entra

- Presupuestos
- Gastos recurrentes
- Inversiones y rendimiento
- Dashboard con gráficos
- Cotizaciones automáticas
- Lenguaje natural / IA
- Modo offline *(ver pregunta 8)*

### La regla que hace que esto funcione

> **El esquema de base de datos soporta TODO desde el día uno. La UI, solo el MVP.**

Cambiar una pantalla es barato. Cambiar el modelo de datos con dos años de historia
cargada es carísimo. Por eso invertimos el tiempo de diseño en el modelo y recortamos sin
culpa en la interfaz.

### Cómo sé que el MVP está listo

Un solo criterio, medible: **cargás un gasto cotidiano desde el celular, parado en la caja
del supermercado, en menos de 10 segundos** — y lo hacés durante 30 días seguidos sin
volver a abrir la planilla.

---

## 5. Qué queda para después

| Etapa | Qué incluye | Por qué acá |
|---|---|---|
| **2** | Presupuestos por categoría/subcategoría, con real vs. presupuestado y proyección | Necesita ≥1 mes de datos cargados para servir de algo |
| **3** | Gastos recurrentes y anticipación de vencimientos | Alto valor, bajo riesgo de modelo. Podría adelantarse si te resulta más urgente que presupuestos |
| **4** | Dashboard con gráficos y evolución histórica | Necesita 3-6 meses de datos. Antes de eso, un gráfico de 2 puntos no informa nada |
| **5** | **Inversiones**: activos, posiciones, compras/ventas, dividendos, precios manuales | El bloque más grande. Merece su propio ciclo de diseño |
| **6** | **Rendimiento**: ganancia absoluta → TWR → XIRR | Depende enteramente de la etapa 5 |
| **7** | Cotizaciones y precios automáticos por API | Optimización de fricción, no capacidad nueva |
| **8** | Objetivos de ahorro y seguimiento | Simple sobre el modelo ya hecho |
| **9** | Carga por lenguaje natural, sugerencia de categoría | Último. Coincido con vos: la IA no es el producto |

### Sobre las métricas de rendimiento (tu punto 13)

Pediste que te explique cuál responde a cada pregunta. Acá va, y el orden importa:

| Métrica | Responde | Necesita | Cuándo |
|---|---|---|---|
| **Ganancia absoluta**<br>`valor actual + retiros − aportes` | "¿Cuánta plata gané?" | Solo los flujos | **Primera.** Es la única que se explica sola, y tu principio de transparencia la exige |
| **XIRR / MWR** | "¿Qué tan bien me fue **a mí**?" — incluye el efecto de cuándo pusiste la plata | Flujos con fecha + valor final | **Segunda.** Es la respuesta correcta a tu pregunta "¿cuánto gané realmente?" del punto 12 |
| **TWR** | "¿Qué tan bueno fue **el activo**?" — ignora tus aportes y retiros | Valuación en **cada** fecha de flujo | **Tercera, y solo si querés comparar contra un benchmark.** Es cara: obliga a valuar la cartera cada vez que movés plata |
| **Rendimiento anualizado** | "¿Cómo se compara con un plazo fijo?" | Cualquiera de las anteriores + tiempo | Derivada, sale gratis |

**El error que quiero evitarte:** mostrar TWR como respuesta a "¿cuánto gané?". TWR puede
dar +15% mientras vos perdiste plata en términos absolutos, si metiste el grueso del
capital justo antes de una caída. Son preguntas distintas y la app tiene que decir cuál
está contestando.

Y lo del error 6 vale acá con toda su fuerza: **estas métricas en pesos nominales
argentinos no significan nada.**

---

## 6. Preguntas que necesito antes de diseñar la base de datos

Están ordenadas por impacto.

> **Las cuatro marcadas 🔴 ya fueron respondidas el 2026-09-15. Ver la sección 9.**
> Las que siguen abiertas son la 4, 5, 6, 7 y 9.

**1. Los tres usuarios: ¿libro compartido o libros separados?** ✅ **RESUELTA → aislados**
   - (a) Cada uno ve **solo lo suyo**, aislado
   - (b) Finanzas **compartidas** — pareja o familia, un solo libro, todos ven todo
   - (c) Mixto: cuentas propias + algunas compartidas

   Es la pregunta de mayor impacto de todas. Cambia el modelo de permisos, el esquema y
   la UI. (c) cuesta cerca del triple que (a).

**2. Tarjetas de crédito: ¿opción A o B del error 4?** ✅ **RESUELTA → B, como pasivo**
   Fricción vs. exactitud. Y decime cuántas tarjetas usás en la práctica.

**3. ¿Los saldos tienen que cuadrar con el banco al peso?** ✅ **RESUELTA → aproximado**
   - (a) Sí, cargo todo y quiero conciliar
   - (b) No, cargo lo relevante y me alcanza con que sea aproximado

   Si es (a) hace falta un mecanismo de ajuste de saldo. Si es (b), los números del
   dashboard son estimaciones y hay que decirlo en pantalla.

**4. ¿Vas a migrar el histórico de la planilla?** 🔴
   ¿Cuántos años, cuántas filas, y en qué formato la podés exportar? Si son años de datos,
   la importación deja de ser un script y pasa a ser una funcionalidad con su propio
   diseño (y me obliga a validar el modelo contra tus datos reales, que es lo mejor que
   nos puede pasar).

**5. ¿Qué tipo de cambio usás mentalmente para saber "cuánto tengo en dólares"?**
   Oficial, MEP, blue, cripto. Y: ¿el sistema debe guardar el tipo de cambio **real de cada
   operación** (lo que efectivamente pagaste) o alcanza con una cotización diaria de
   referencia? No es lo mismo.

**6. Inversiones: ¿qué tenés hoy, concretamente?**
   Plazos fijos, FCI, cuenta remunerada, acciones locales, CEDEARs, cripto, broker del
   exterior. Cada familia tiene su particularidad — un plazo fijo no tiene "precio de
   mercado", devenga; un FCI tiene cuotaparte diaria. El diseño de la etapa 5 depende de
   esto.

**7. ¿Precios manuales o automáticos?**
   Cargar precios a mano es sostenible con 5 activos; es insoportable con 30.

**8. ¿La app tiene que funcionar SIN señal?** ✅ **RESUELTA → online-only**
   Ojo con esta: **"PWA instalable" y "funciona offline" son dos cosas distintas y la
   segunda cuesta varias veces más.** Offline-first obliga a resolver cola de
   sincronización, conflictos e IDs generados en el cliente.

   Mi lectura: si cargás el gasto parado en la caja del supermercado, tenés señal. Yo
   arrancaría **online-only** y agregaría offline si la realidad te demuestra que hace
   falta. Pero es tu llamada, y es de las caras de revertir.

**9. ¿Cuál es tu nivel de tolerancia a que la carga tenga un paso más a cambio de que los
   números sean exactos?** Esta pregunta atraviesa todo el producto y prefiero tenerla
   explícita antes que adivinarla.

---

## 7. Arquitectura

### Lo que ya puedo afirmar

Tu carga de trabajo es **3 usuarios × ~15 escrituras/día ≈ 45 escrituras diarias**. Eso
son unas 1.400 filas por mes. En diez años no llegás a 200.000 filas.

**Cualquier base de datos del planeta se ríe de ese volumen.** Una Raspberry Pi con SQLite
lo maneja sin transpirar. Por lo tanto:

> **El rendimiento NO es un criterio de selección.** Quien te venda escalabilidad acá te
> está vendiendo algo que no necesitás.

Los criterios reales, en orden:

1. **Que no se te caiga ni se pause solo.** Varios free tiers pausan proyectos inactivos.
2. **Auth gestionada y decente.** No quiero que escribas manejo de contraseñas. Nadie
   debería.
3. **Aislamiento de datos por usuario a nivel base de datos**, no a nivel código de la
   app. Si el aislamiento vive solo en tu frontend, un bug = un usuario viendo las
   finanzas de otro.
4. **Costo de salida.** Tu principio de "datos exportables" se cumple mucho mejor
   **eligiendo un motor estándar** que escribiendo capas de abstracción.

### La tensión que hay en tu documento

Pediste dos cosas que tiran para lados opuestos:

- *"No quiero sobrearquitectura"*
- *"No quiero quedar atado al proveedor"*

La forma barata de resolverla no es construir adaptadores por si acaso. Es **elegir un
proveedor cuyo formato de datos sea estándar**. Si abajo hay Postgres común, migrar es un
`pg_dump` y una tarde. Si abajo hay un almacén propietario de documentos, migrar es
reescribir la app entera.

> **La portabilidad se compra en el momento de elegir el motor, no programándola después.**

Esto, por sí solo, ya pesa fuerte en la comparación.

### Sobre la autenticación (tu punto 4) — nivel razonable

Para 3 usuarios con datos financieros privados:

| Mecanismo | ¿Vale la pena? | Por qué |
|---|---|---|
| Email + contraseña | **Sí** | Base. Que lo maneje el proveedor |
| Google OAuth | **Sí, si los 3 tienen Google** | Menos fricción, cero contraseñas que perder |
| **Magic link (link por email)** | **No como único método** | Suena cómodo y es una trampa en PWA: el cliente de correo abre el link en **su propio** navegador embebido, distinto de donde arrancaste el flujo, y la sesión falla. Es un problema estructural, no un bug que se arregle |
| 2FA / TOTP | **Sí, opcional por usuario** | Barato de agregar si el proveedor ya lo trae. Con datos financieros, razonable |
| Aislamiento por usuario en la DB | **Obligatorio** | No es opcional ni es overengineering |
| HTTPS | **Obligatorio** | Viene gratis con cualquier hosting serio |
| Registro/autorización de dispositivos | **No** | Overengineering para 3 personas. Sesiones bien configuradas alcanzan |
| Auditoría de cambios | **No al principio** | Agregalo si alguna vez te preguntás "¿quién borró esto?". Con 3 usuarios, improbable |
| Backups | **Sí, y verificá que restauren** | Un backup que nunca probaste no es un backup. Además, tu export a CSV/JSON ya es media red de seguridad |

### Comparación de proveedores

Datos verificados contra las páginas oficiales el **2026-09-15**. Lo que no se pudo
confirmar en fuente oficial está marcado como **NO VERIFICADO** en vez de completado a ojo.

#### Antes de mirar precios: el modelo elige la base de datos

Un free tier no puede rescatarte de un motor que no encaja con tu modelo.
[ADR-001](docs/ADRs.md) define transacciones con líneas que deben sumar cero, saldos que se
calculan agregando líneas por cuenta, y consultas por categoría y por mes. Eso es
**relacional**: necesita joins, agregaciones y restricciones de integridad.

**Por eso Firestore queda descartado antes de discutir su plan gratuito.** No tiene joins,
las agregaciones son caras, y reconstruir un saldo implicaría leer y sumar documentos en el
cliente. Además es el único del grupo con dificultad de salida **ALTA**: es NoSQL
propietario, no hay equivalente a `pg_dump`, y migrar significa reescribir el modelo. Eso
choca de frente con tu principio de datos exportables.

**Firebase queda afuera por el modelo, no por el precio.**

#### El segundo filtro: dónde vive el aislamiento entre usuarios

Mi criterio 3 era que el aislamiento viva **en la base de datos**, no en el código de la
aplicación. Con datos financieros de tres personas, un bug de aplicación no puede poder
mostrarle a alguien las finanzas de otro.

Eso elimina dos más:

- **Cloudflare D1** y **Turso** corren SQLite, que **no tiene RLS**. El aislamiento habría
  que escribirlo a mano en cada consulta. Turso directamente recomienda otro patrón: una
  base de datos por usuario.
- Ninguno de los dos trae autenticación: habría que sumar un tercero.

Es una lástima, porque Cloudflare era el más sólido en todo lo demás: egress $0 siempre, sin
concepto de pausa por inactividad, y el **único con recuperación punto-en-el-tiempo gratis**
(Time Travel, 7 días).

**PocketBase auto-hospedado** también sale, por un motivo distinto y verificado: Fly.io
**eliminó su free tier persistente** — hoy da un trial de 2 horas de cómputo o 7 días, y
después exige tarjeta. El piso real ronda **US$2-3/mes**. Es barato, no gratis, y suma
mantenimiento de servidor que vos explícitamente no querés.

#### Los dos que quedan

Ambos son **Postgres real**, ambos tienen **RLS nativo**, y en ambos la salida es un
`pg_dump` (dificultad **BAJA**). La decisión es entre dos formas distintas de equivocarse.

| | **Supabase** | **Neon** |
|---|---|---|
| Almacenamiento | 500 MB | 0,5 GB *(lo mismo)* |
| Egress mensual | 5 GB + 5 GB cacheado | 5 GB |
| **Pausa por inactividad** | ⚠️ **Sí: pausa el proyecto a los 7 días.** Máximo 2 proyectos activos | ✅ **No.** Suspende el cómputo a los 5 min y despierta al conectar. Textual de su doc: *"None of these limits delete your data"* |
| Autenticación | Email/password, OAuth social, **MFA/TOTP incluido gratis** | Better Auth gestionado nativo: email/pass, OAuth Google, OTP |
| MAU de auth | 50.000 | 60.000 |
| **Backups en free** | ⚠️ **Ninguno.** PITR recién en Pro (7 días) | 6 h de restauración instantánea + 1 snapshot manual |
| Aislamiento | RLS de Postgres vía `auth.uid()` | RLS de Postgres, recomendado junto a su auth |
| Primer escalón pago | **US$25/mes** (piso fijo) | Por uso, sin piso. Gasto típico que cita Neon: ~US$15/mes |
| Salida | **BAJA** — `pg_dump` | **BAJA** — `pg_dump` |

**El almacenamiento no es criterio.** Tus ~200.000 filas en diez años entran varias veces
en 500 MB. Tampoco lo es el rendimiento. Lo único que los diferencia de verdad es **cómo te
fallan**.

| | Cómo te falla Supabase | Cómo te falla Neon |
|---|---|---|
| | Si nadie abre la app durante una semana, **el proyecto se pausa** | Su producto de auth es **mucho más nuevo** y **no documenta MFA/TOTP** |
| | **No hay backups.** Con diez años de historia financiera, eso pesa | Neon fue **adquirida por Databricks** y se rebrandeó como *Lakebase*; riesgo estratégico de producto |

#### Recomendación: Supabase 🟡 *(falta tu firma — OD-01)*

Por tres motivos, en orden de peso:

1. **Es el único donde el TOTP está confirmado e incluido gratis.** Vos preguntaste por
   2FA en datos financieros; Neon Auth no lo documenta. Un dato verificado le gana a uno
   desconocido.
2. **Auth, base de datos y almacenamiento en un solo lugar** — es literalmente tu criterio
   de bajo mantenimiento. Neon obliga a coordinar dos productos, uno de ellos muy reciente.
3. **Es el más maduro de los dos** para lo que vas a hacer, y su RLS es el camino trillado.

**Y ahora la parte incómoda, porque sus dos debilidades son reales:**

- **Sin backups en free.** Se cierra con un `pg_dump` programado (GitHub Actions, gratis) que
  guarde un volcado periódico. **No es un parche: es tu principio de "no quedar atado al
  proveedor" convertido en rutina.** Un backup que nunca restauraste no es un backup — hay
  que probar la restauración una vez.
- **Pausa a los 7 días.** Si tres personas la usan a diario, nunca se dispara. Si se
  dispara, es señal de que la app dejó de usarse, que es un problema más grave que la pausa.
  **Pero hay un dato que NO se pudo verificar y que sí importa:** si un proyecto pausado
  revive solo con la primera request o exige un clic manual en el panel. Conviene
  confirmarlo antes de firmar.

Si el TOTP no te importa tanto como la tranquilidad de que nunca se pause, **Neon es la
elección correcta y no te voy a discutir**. Es una decisión de qué riesgo preferís, no de
cuál es mejor.

#### Sobre el frontend

Para una PWA de este tamaño, la elección de framework es **de las decisiones más baratas de
revertir** de todo el proyecto. No merece discusión larga. Requisitos: que genere sitio
estático y que tenga buen soporte de PWA.

Para el hosting, los tres candidatos sirven y son gratis, pero hay letra chica de contrato:

| | Free | Letra chica |
|---|---|---|
| **Cloudflare Pages** | Ancho de banda **ilimitado** | Cloudflare está empujando a migrar de Pages a *Workers static assets* |
| **Vercel** | 100 GB/mes | Hobby es *"personal, non-commercial use"* |
| **GitHub Pages** | 1 GB de sitio, ~100 GB/mes | Prohíbe explícitamente el uso como SaaS comercial |

Tu app es personal y privada, así que los tres están dentro de sus términos. **Si en algún
momento la ofrecieras a terceros, Vercel Hobby y GitHub Pages dejarían de estar permitidos.**
Cloudflare Pages es el único sin esa restricción.

---

## 8. Cuánto cuesta revertir cada decisión

Pediste esto explícitamente y me parece lo más útil del documento. Dónde poner el esfuerzo
de discusión:

| Decisión | Costo de cambiarla después | Cuándo decidir |
|---|---|---|
| **Modelo de dominio** (origen/destino, unidades, valuación) | 🔴 **Altísimo.** Con datos cargados, es migrar toda la historia | **Ahora, y con cuidado** |
| **Libro compartido vs. separado** | 🔴 **Altísimo.** Afecta esquema, permisos y UI | **Ahora** |
| **Modelo de tarjeta de crédito** | 🟠 Alto. Recategorizar meses de movimientos | **Ahora** |
| **Proveedor de base de datos** | 🟠 Medio-alto, y depende enteramente de si es estándar o propietario | Ahora, pero el riesgo se mitiga eligiendo bien |
| **Offline-first** | 🟠 Alto si se agrega tarde | **Ahora** (aunque la respuesta sea "no") |
| **Proveedor de autenticación** | 🟡 Medio. Migrar usuarios es molesto pero con 3 personas es trivial | Ahora, sin angustia |
| **Framework de frontend** | 🟢 Bajo. Es reescribir pantallas sobre el mismo modelo | Se puede cambiar de opinión |
| **Diseño de la UI** | 🟢 Bajísimo | Iteramos siempre |
| **Métricas de rendimiento** | 🟢 Bajo. Se calculan sobre los datos; si los datos están bien, se agregan cuando quieras | Etapa 6 |

La lectura: **hay cuatro conversaciones que tenemos que tener bien tenidas** (modelo,
usuarios compartidos, tarjetas, offline). El resto lo podemos cambiar sobre la marcha sin
drama.

---

## 9. Decisiones tomadas — 2026-09-15

Las cuatro decisiones más caras de revertir, ya resueltas.

### D-01 — Usuarios aislados

Cada usuario ve **solo sus propios datos**. Sin libros compartidos, sin invitaciones, sin
permisos por cuenta.

**Consecuencias:** una única regla de aislamiento por dueño, aplicada en la base de datos.
Es el modelo más simple posible y elimina el bloque entero de permisos del MVP.

**Lo que esto te cuesta:** los tres usuarios **nunca** pueden ver una vista combinada. Si
en algún momento querés finanzas de pareja o familiares, hay que migrar. Ver la propuesta
de mitigación en la sección 10.

### D-02 — Tarjeta de crédito como pasivo

Cada compra se registra **contra la deuda de la tarjeta**, con su categoría y en el mes en
que ocurrió. El pago del resumen es una **transferencia** (banco → tarjeta), nunca un gasto.

**Consecuencias:**
- El tipo de cuenta `liability` entra al MVP (no queda para después).
- El patrimonio resta la deuda de tarjeta pendiente.
- La UI tiene que dejar OBVIO que pagar el resumen no es un gasto, o vas a duplicar tus
  números a mano sin darte cuenta.
- Queda abierto para más adelante: fecha de cierre y vencimiento, y cuotas.

### D-03 — Saldos aproximados, sin conciliación

No hace falta que los saldos cuadren al peso con el homebanking.

**Consecuencias:**
- No hay mecanismo de conciliación bancaria en el MVP.
- **La app tiene que ser honesta en pantalla**: los saldos son estimados, no verdad
  absoluta. Esto es tu principio de transparencia aplicado.
- Igual hace falta una válvula de escape barata: un movimiento de **"ajuste de saldo"**
  (contra una categoría *Ajustes*) para cuando la deriva te moleste. Es media hora de
  trabajo y evita que abandones la app el día que el número no cierra.

### D-04 — Online-only

La app requiere conexión para registrar. **PWA instalable, no offline-first.**

**Consecuencias:**
- Sin cola de sincronización, sin resolución de conflictos, sin IDs generados en el cliente.
- El *service worker* cachea la interfaz (que abra rápido), **no** los datos.
- Si se corta la señal, la app lo dice claro en vez de fingir que guardó.
- Si con el uso real resulta que sí hace falta offline, se agrega — pero es caro, así que
  esperamos a tener evidencia y no a una corazonada.

---

## 10. Propuesta: un seguro barato contra D-01

D-01 es la única de las cuatro que compraste con un costo futuro real. Hay una forma de
neutralizarlo casi gratis, y quiero que la decidas vos.

**El problema:** si cada fila apunta directamente al usuario dueño (`owner_id → usuario`),
pasar a finanzas compartidas más adelante obliga a migrar **todas** las filas de la base.

**La mitigación:** que las filas apunten a un **libro** (`ledger_id`), y que el libro tenga
miembros. Hoy cada usuario tiene exactamente un libro con un solo miembro: él mismo.

```
usuario  →  miembro_de_libro  →  libro  →  cuentas, movimientos, categorías…
```

| | Hoy | Si algún día querés compartir |
|---|---|---|
| **Sin el libro** | 1 columna, lo más simple posible | Migrar todas las filas + rehacer las reglas de acceso. 🔴 Caro |
| **Con el libro** | 1 tabla extra con 3 filas + 1 join en la regla de acceso | Insertar una fila en `miembros`. 🟢 Trivial |

**Mi recomendación: hacerlo.** El costo hoy es prácticamente nulo y convierte la decisión
más cara de revertir en la más barata. Pero es una capa de indirección que hoy no usás, y
vos pediste explícitamente no sobrearquitectura — así que la decisión es tuya, no mía.

### D-05 — Aceptada: se adopta el libro (`ledger`) ✅

**Decidido el 2026-09-15.** Toda fila del dominio pertenece a un **libro**, no a un usuario.

**Consecuencias:**
- Tabla `ledger` (libro) + tabla `ledger_member` (miembro).
- Al registrarse, cada usuario obtiene automáticamente su libro personal con un solo
  miembro: él mismo. **Esto tiene que ser automático** — si el usuario ve la palabra
  "libro" en la interfaz del MVP, fracasamos: es una decisión de esquema, no de producto.
- La regla de aislamiento pasa a ser "pertenezco a este libro" en vez de "soy el dueño de
  esta fila". Una línea más, misma garantía.
- **Sigue valiendo D-01**: hoy cada usuario está aislado y nadie comparte nada. Lo único
  que cambia es que mañana compartir cuesta un `INSERT` en vez de una migración.

---

## Próximo paso

Con D-01 a D-04 cerradas puedo escribir el **modelo de datos concreto**: tablas, campos,
relaciones, y cada caso de uso de la sección 1 resuelto uno por uno contra ese esquema.

Antes necesito las preguntas 4, 5, 6 y 7 de la sección 6 — las de migración del histórico,
tipo de cambio e inversiones — aunque las de inversiones no bloquean el MVP.

La comparación de proveedores se completa aparte, en cuanto termine de verificar los datos
contra las fuentes oficiales.
