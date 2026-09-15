# Proyecto: aplicación de finanzas personales

Quiero desarrollar una aplicación web de finanzas personales, probablemente como una PWA, que pueda utilizarse cómodamente tanto desde el celular como desde una PC.

La aplicación nace de una necesidad personal y quiero desarrollarla iterativamente junto con vos. **No quiero que intentes resolver toda la aplicación de una sola vez.** Primero quiero que me ayudes a entender y definir correctamente el problema, detectar inconsistencias o decisiones que todavía no haya considerado y luego avanzar progresivamente hacia el diseño y la implementación.

Quiero que actúes combinando los roles de:

* Product Manager
* Software Architect
* UX/UI designer
* Backend/frontend developer
* Analista financiero cuando sea necesario

Priorizá soluciones simples, mantenibles, seguras y de bajo costo. No quiero sobrearquitectura para una aplicación pequeña.

---

## 1. Contexto y origen del proyecto

Durante bastante tiempo llevé mis finanzas personales utilizando hojas de cálculo.

La estructura original era relativamente sencilla.

Tenía una tabla donde registraba movimientos con información como:

* fecha
* categoría
* subcategoría
* monto
* moneda
* medio de pago
* notas

Las categorías principales eran aproximadamente:

* Ingresos
* Gastos fijos
* Gastos variables
* Ahorros
* Inversiones
* eventualmente Caridad/donaciones

"Ahorros" representaba principalmente dinero que separaba para comprar dólares y mantener una reserva.

"Inversiones" representaba principalmente transferencias de dinero hacia brokers o plataformas de inversión.

La tabla permitía trabajar con ARS y USD, aunque históricamente casi todos los movimientos cotidianos estaban expresados en ARS.

Además tenía una sección mensual que permitía calcular aproximadamente:

Ingresos - gastos - ahorros - inversiones = resultado del mes

También existían algunas gráficas y resúmenes.

El principal problema de la hoja de cálculo no era tanto la capacidad de análisis sino la **fricción para registrar información**, especialmente desde el celular.

Quiero reemplazarla por una aplicación que mantenga la simplicidad de la hoja de cálculo pero sea mucho más cómoda para registrar y consultar información.

---

# 2. Objetivo general

Quiero construir una aplicación personal de finanzas que permita:

1. Registrar fácilmente ingresos y gastos.
2. Organizar los movimientos mediante categorías y subcategorías.
3. Consultar rápidamente cómo salió cada mes.
4. Crear presupuestos mensuales.
5. Registrar gastos recurrentes, impuestos y suscripciones.
6. Llevar seguimiento del ahorro.
7. Llevar seguimiento del patrimonio.
8. Llevar seguimiento de inversiones.
9. Calcular correctamente el rendimiento de las inversiones a lo largo del tiempo.
10. Consultar la evolución financiera mediante dashboards y gráficos.
11. Utilizarse cómodamente desde celular y PC.
12. Mantener todos los datos sincronizados en la nube.

La aplicación será utilizada por aproximadamente tres personas.

No espero una carga elevada:

* aproximadamente 10–15 modificaciones por usuario por día como máximo
* probablemente incluso menos
* no necesito una infraestructura preparada para miles de usuarios

Por lo tanto, quiero optimizar principalmente por:

* simplicidad
* seguridad
* bajo costo
* facilidad de mantenimiento
* buena experiencia de usuario

y no por escalabilidad extrema.

---

# 3. Plataformas

La aplicación debería funcionar correctamente en:

* celular
* PC

Mi primera opción es una PWA.

Quiero poder abrirla desde el navegador y, si es posible, instalarla como aplicación en el celular.

No quiero desarrollar inicialmente una aplicación nativa para Android/iOS salvo que exista una razón importante.

---

# 4. Usuarios y autenticación

La aplicación será privada.

Inicialmente habrá aproximadamente tres usuarios.

Quiero algún sistema de autenticación sencillo, por ejemplo:

* email + contraseña
* Google
* o una combinación de ambos

También quiero evaluar si tiene sentido implementar:

* autenticación de dos factores
* registro/autorización de dispositivos
* sesiones seguras
* recuperación de contraseña

No quiero implementar mecanismos de seguridad innecesariamente complejos, pero sí quiero que los datos financieros estén correctamente protegidos.

Ayudame a determinar qué nivel de seguridad es razonable para una aplicación de este tamaño.

---

# 5. Almacenamiento y costos

Los datos deben almacenarse en la nube.

No quiero depender exclusivamente del almacenamiento local del dispositivo.

Mi objetivo inicial es que el proyecto pueda funcionar gratuitamente o con un costo extremadamente bajo.

Quiero evaluar servicios que tengan planes gratuitos suficientes para este volumen de uso.

Por ejemplo, podemos evaluar alternativas como:

* Supabase
* Firebase
* Neon
* otros servicios similares

No quiero elegir una tecnología simplemente porque sea popular.

Quiero comparar las alternativas considerando:

* costo
* límites del free tier
* base de datos
* autenticación
* seguridad
* facilidad de desarrollo
* backups
* posibilidad de crecer en el futuro
* facilidad de migración si algún día necesito abandonar el proveedor

También quiero evaluar hosting gratuito o muy económico para el frontend.

Una URL gratuita/subdominio sería suficiente inicialmente. Tener un dominio propio sería agradable pero no es prioritario.

---

# 6. Registro de movimientos

El núcleo de la aplicación debe permitir registrar movimientos financieros.

Cada movimiento debería poder contener como mínimo:

* fecha
* tipo de movimiento
* categoría
* subcategoría
* monto
* moneda
* medio de pago/cuenta
* descripción o nota

Quiero que el ingreso de datos desde el celular sea extremadamente rápido.

Idealmente, registrar un gasto cotidiano debería requerir pocos pasos.

Por ejemplo:

"Gasto → Supermercado → $25.000 → tarjeta → guardar"

No quiero que la aplicación convierta el registro de un gasto simple en un formulario burocrático.

---

# 7. Categorías

Inicialmente quiero categorías similares a:

### Ingresos

### Gastos fijos

Ejemplos:

* alquiler/expensas
* servicios
* seguros
* etc.

### Gastos variables

Ejemplos:

* comida
* transporte
* entretenimiento
* compras
* etc.

### Ahorros

Principalmente dinero separado para:

* compra de dólares
* fondo de emergencia
* reserva de efectivo

### Inversiones

Dinero destinado a:

* brokers
* cuentas remuneradas
* plazos fijos
* ETFs
* bonos
* acciones
* criptomonedas
* etc.

### Caridad

Donaciones u otros gastos similares.

Sin embargo, **no quiero asumir que esta estructura es la mejor solamente porque así funcionaba mi hoja de cálculo**.

Quiero que analices si conviene separar conceptualmente:

* gasto
* transferencia
* ahorro
* inversión
* ingreso
* movimiento entre cuentas

Por ejemplo, mover dinero desde mi cuenta bancaria hacia un broker no debería necesariamente interpretarse como un gasto.

Este tipo de decisiones de modelado son importantes y quiero que las discutamos antes de implementarlas.

---

# 8. Cuentas y dinero

Quiero poder representar dónde está realmente mi dinero.

Por ejemplo:

* efectivo ARS
* efectivo USD
* cuenta bancaria ARS
* cuenta bancaria USD
* billetera virtual ARS
* billetera virtual USD
* broker
* exchange
* cuenta remunerada
* etc.

No necesito necesariamente un sistema contable complejo.

Quiero algo suficientemente simple para responder preguntas como:

* ¿Cuánto dinero tengo?
* ¿Cuánto tengo en ARS?
* ¿Cuánto tengo en USD?
* ¿Cuánto tengo invertido?
* ¿Cuánto tengo disponible?
* ¿Cuánto aumentó mi patrimonio?

Quiero que podamos distinguir claramente entre:

**Movimiento de dinero**

y

**cambio en el valor de mi patrimonio.**

---

# 9. Presupuestos

Una de las funcionalidades nuevas más importantes será crear presupuestos.

Quiero poder definir anticipadamente cuánto espero gastar durante un mes.

Por ejemplo:

| Categoría       | Presupuesto |
| --------------- | ----------: |
| Supermercado    |    $250.000 |
| Restaurantes    |    $100.000 |
| Transporte      |     $80.000 |
| Entretenimiento |     $70.000 |

La aplicación debería poder mostrar:

* presupuesto
* gasto real
* diferencia
* porcentaje utilizado
* proyección al final del mes, si tiene sentido

También quiero evaluar presupuestos a nivel de categoría y subcategoría.

---

# 10. Gastos recurrentes

Quiero poder registrar obligaciones recurrentes.

Por ejemplo:

* impuestos
* servicios
* suscripciones
* seguros
* membresías
* etc.

Debería poder indicar que un gasto ocurre:

* semanalmente
* mensualmente
* bimestralmente
* trimestralmente
* semestralmente
* anualmente

Quiero que la aplicación pueda anticiparme estos gastos.

Por ejemplo:

"Próximamente: seguro anual — $XXX"

No necesariamente quiero que el sistema ejecute pagos automáticamente.

Inicialmente alcanza con que recuerde y proyecte los gastos.

También quiero analizar cómo representar correctamente gastos cuyo importe cambia cada período.

---

# 11. Ahorros

Quiero poder visualizar el ahorro de manera separada de los gastos.

Me interesa poder responder:

* ¿Cuánto ahorré este mes?
* ¿Cuánto ahorré este año?
* ¿Qué porcentaje de mis ingresos estoy ahorrando?
* ¿Cuánto dinero tengo reservado?
* ¿Estoy cumpliendo mi objetivo de ahorro?

También quiero poder establecer objetivos.

Por ejemplo:

* fondo de emergencia
* determinada cantidad de USD
* determinado patrimonio
* etc.

No quiero que "comprar dólares" sea tratado automáticamente como un gasto.

Es una transformación de patrimonio/dinero, y quiero que el modelo financiero lo represente correctamente.

---

# 12. Sección de inversiones

Esta es probablemente la parte técnicamente más interesante.

Quiero una sección específica para inversiones.

Los brokers suelen mostrar mucha información, pero no siempre responden fácilmente preguntas personales como:

> "¿Cuánto dinero gané realmente?"

Quiero poder registrar las operaciones o movimientos necesarios para reconstruir mi evolución.

Por ejemplo:

* deposité dinero
* compré un activo
* compré más unidades
* recibí dividendos
* vendí parte o todo
* retiré dinero
* el activo aumentó/disminuyó de valor

Quiero poder registrar activos como:

* acciones
* ETFs
* bonos
* fondos
* criptomonedas
* cuentas remuneradas
* plazos fijos
* otros instrumentos

---

# 13. Rendimiento de inversiones

Quiero poder determinar cuánto crecieron realmente mis inversiones.

Por ejemplo:

Si inicialmente aporté $1.000.000 y después de un año tengo activos por $1.100.000, podría parecer que gané 10%.

Pero si durante ese año agregué otros $500.000, ese cálculo es incorrecto.

Por lo tanto, quiero que el sistema diferencie entre:

* aportes
* retiros
* compras
* ventas
* dividendos/intereses
* variaciones de precio
* variaciones por tipo de cambio

Quiero investigar e implementar una metodología financiera correcta para calcular el rendimiento.

No quiero simplemente:

`valor_actual / dinero_aportado - 1`

si existen aportes y retiros durante el período.

Quiero evaluar métricas como:

* rendimiento absoluto
* rendimiento porcentual
* rendimiento anualizado
* evolución mensual/anual
* eventualmente TWR
* eventualmente XIRR/Money-Weighted Return

No hace falta implementar todas desde el principio.

Quiero que me expliques cuál corresponde a cada pregunta y que evitemos métricas que puedan inducir a conclusiones incorrectas.

---

# 14. Ventas de inversiones

Es especialmente importante que vender un activo no destruya la medición histórica del rendimiento.

Por ejemplo:

* compro 10 acciones
* suben de precio
* vendo las 10
* recibo dinero en efectivo

La aplicación debe poder entender que:

**vendí el activo, pero no perdí el patrimonio generado ni debo interpretar automáticamente la venta como una pérdida.**

La venta debe convertirse en una operación/movimiento correctamente contabilizado.

Quiero que el modelo de datos permita reconstruir el historial.

---

# 15. Tipo de cambio

Como vivo en Argentina, el tipo de cambio es importante.

La aplicación soportará inicialmente:

* ARS
* USD

Quiero poder visualizar información en ambas monedas.

También quiero analizar cómo tratar:

* tipo de cambio oficial
* MEP
* blue
* otro tipo de cambio configurable

No necesariamente quiero integrar todas estas cotizaciones desde el primer MVP.

Pero el diseño debería permitir incorporar fuentes de cotización en el futuro.

Es importante evitar que una variación del tipo de cambio sea confundida con rendimiento real de una inversión.

Por ejemplo:

un activo denominado en USD puede mantener exactamente su valor en dólares mientras aumenta significativamente su valor expresado en ARS.

La aplicación debería poder mostrar ambas perspectivas cuando tenga sentido.

---

# 16. Dashboard

Quiero un dashboard sencillo, útil y visual.

Al menos debería poder responder:

### Este mes

* ingresos
* gastos
* ahorro
* inversiones
* balance
* comparación contra presupuesto

### Patrimonio

* patrimonio total
* efectivo
* ahorros
* inversiones
* distribución por moneda
* evolución histórica

### Inversiones

* valor actual
* aportes
* rendimiento
* evolución temporal
* distribución por activo

### Presupuesto

* presupuesto total
* gasto acumulado
* porcentaje consumido
* categorías excedidas

Quiero evitar dashboards llenos de gráficos que no respondan ninguna pregunta concreta.

Cada visualización debería existir porque ayuda a tomar una decisión o entender algo.

---

# 17. Experiencia de usuario

La aplicación debe priorizar la rapidez.

Una persona debería poder registrar un gasto cotidiano en pocos segundos.

Me interesa especialmente:

* interfaz mobile-first
* botones grandes
* formularios simples
* valores recordados
* autocompletado
* categorías frecuentes
* posibilidad de repetir movimientos
* navegación sencilla

Si tiene sentido, podemos estudiar posteriormente:

* ingreso mediante lenguaje natural
* por ejemplo: "Gasté $18.500 en supermercado con débito"
* categorización automática
* sugerencias de categoría

Pero **la IA no es el objetivo principal del producto**.

Primero quiero una aplicación financiera sólida y sencilla.

---

# 18. Arquitectura

No tengo interés en utilizar una arquitectura compleja solamente para demostrar conocimiento técnico.

La aplicación tendrá pocos usuarios y poca carga.

Prefiero inicialmente algo como:

* frontend web/PWA
* backend sencillo o backend-as-a-service
* PostgreSQL o una base de datos relacional equivalente
* autenticación gestionada
* almacenamiento cloud
* hosting económico/gratuito

Podemos evaluar tecnologías como:

* SvelteKit
* React
* Next.js
* otro framework razonable

y servicios como:

* Supabase
* Firebase
* otros

No quiero que asumas ninguna tecnología todavía.

Primero quiero comparar las opciones y elegir una arquitectura coherente con el problema.

---

# 19. Seguridad

Aunque sea una aplicación pequeña, contiene información financiera privada.

Quiero considerar desde el principio:

* autenticación segura
* autorización por usuario
* aislamiento de los datos entre usuarios
* protección de credenciales
* HTTPS
* gestión segura de sesiones
* backups
* recuperación ante pérdida de datos
* protección de APIs
* validación de inputs
* auditoría de cambios si resulta necesaria

Quiero que evalúes especialmente qué mecanismos de seguridad son realmente necesarios y cuáles serían overengineering.

---

# 20. Principios del proyecto

Quiero seguir estos principios:

### Simplicidad primero

No agregar funcionalidades solamente porque "podrían ser útiles".

### Modelo financiero correcto

Es preferible dedicar tiempo a definir correctamente qué significa cada movimiento antes que construir una UI bonita sobre un modelo incorrecto.

### Evolución incremental

Primero MVP.

Después funcionalidades adicionales.

### Bajo mantenimiento

La aplicación debería requerir poca intervención manual.

### Bajo costo

Siempre que sea razonable, utilizar free tiers.

### Datos exportables

Quiero evitar quedar completamente atado al proveedor.

Idealmente debería ser posible exportar los datos a:

* CSV
* JSON
* eventualmente Excel

### Historial

No quiero destruir información histórica cuando se modifiquen categorías, activos o cuentas.

### Transparencia

Los cálculos financieros importantes deben poder explicarse.

Si la aplicación dice:

> "Tu inversión rindió 8,4%"

debería ser posible entender de dónde salió ese número.

---

# 21. Cómo quiero que trabajemos

No quiero que simplemente empieces a generar cientos de archivos.

Quiero trabajar de forma iterativa.

Primero:

1. Analizá este problema.
2. Detectá ambigüedades.
3. Señalá posibles errores conceptuales.
4. Proponé una estructura de dominio.
5. Proponé un MVP.
6. Compará las principales alternativas tecnológicas.
7. Recomendá una arquitectura inicial.
8. Definamos el modelo de datos.
9. Recién después empezaremos a implementar.

Cuando haya decisiones importantes, explicá:

* qué alternativas existen
* qué recomendás
* por qué
* qué costo tiene cambiar esa decisión posteriormente

No quiero respuestas complacientes.

Si una idea mía es mala, innecesaria o conceptualmente incorrecta, decímelo directamente.

Si existe una solución más sencilla que la que propongo, priorizala.

---

# 22. Primera tarea

Para comenzar, **NO escribas código todavía**.

Quiero que analices todo el problema y me devuelvas:

1. Los principales conceptos que debería tener el dominio.
2. Qué cosas de mi modelo original de hoja de cálculo conviene mantener.
3. Qué cosas conviene cambiar.
4. Qué errores conceptuales podrían aparecer al mezclar gastos, ahorro, transferencias, patrimonio e inversiones.
5. Qué debería incluir el MVP.
6. Qué funcionalidades deberían quedar para una segunda etapa.
7. Qué preguntas necesitás hacerme antes de diseñar definitivamente la base de datos.
8. Una comparación preliminar de las arquitecturas/servicios que podrían servir.
9. Una propuesta inicial de arquitectura, dejando claro qué decisiones todavía NO deberían considerarse definitivas.

No asumas que mi descripción actual es el diseño final.

El objetivo de esta primera etapa es **entender correctamente el problema antes de construir la solución**.
