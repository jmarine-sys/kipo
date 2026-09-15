# Prueba de humo

Diez minutos, en la computadora. **No alcanza con que no se rompa**: cada paso tiene un
número esperado, y ese número es el que prueba que el modelo hace lo que promete.

Estás en etapa de prueba, así que al final se borra todo
([ADR-018](ADRs.md#adr-018--la-puesta-en-marcha-separa-dos-regímenes-de-datos)). Cargá sin
miedo.

---

## Preparación

En **Cuentas → + Nueva**, creá tres:

| Nombre | Qué es | Moneda |
|---|---|---|
| `Banco` | Tengo plata acá | ARS |
| `Ahorro` | Tengo plata acá | ARS |
| `Visa` | **Debo plata acá** | ARS |

Y una cuarta, `Dólares`, en **USD** — cuando elijas USD te va a preguntar con qué cotización
valuarla ([ADR-011](ADRs.md#adr-011--la-fuente-de-cotización-es-una-propiedad-de-la-cuenta-no-de-la-fecha)).
Elegí **Blue**.

---

## 1 · Un ingreso

**Ingreso** → `1.000.000` → *Sueldo* → entra en `Banco`.

| Verificá en Inicio | Esperado |
|---|---|
| Resultado del mes | **+$1.000.000** |
| Ingresos | $1.000.000 |

## 2 · Un gasto

**Gasto** → `25.000` → *Supermercado* → pagás con `Banco`.

| | Esperado |
|---|---|
| Resultado del mes | **+$975.000** |
| Gastos | $25.000 |

Hasta acá cualquier app hace esto. Ahora viene lo interesante.

## 3 · Mover plata al ahorro — **la prueba principal**

**Mover** → `300.000` → desde `Banco` → hacia `Ahorro`.

Fijate que la app te avisa: *"Movés plata entre tus cuentas. No es un gasto."*

| | Esperado |
|---|---|
| Resultado del mes | **+$975.000 — EXACTAMENTE IGUAL que antes** |
| Disponible | bajó, porque salió del banco… pero sigue contando: está en Ahorro |

> **Este es el paso que justifica el proyecto entero.** En tu planilla, ahorrar $300.000
> empeoraba el resultado del mes en $300.000. Acá **no lo mueve ni un peso**, porque cambiar
> plata de lugar no es un gasto. Si este número cambió, algo está mal y quiero saberlo.

## 4 · Comprar con tarjeta

**Gasto** → `18.000` → *Restaurantes* → pagás con `Visa`.

La app avisa: *"Se suma a la deuda de Visa. El gasto queda en este mes, con su categoría."*

| | Esperado |
|---|---|
| Resultado del mes | **+$957.000** |
| Cuentas → Visa | **−$18.000** *(deuda)* |
| Inicio → Tarjetas | −$18.000 |

## 5 · Pagar el resumen — **la segunda prueba clave**

**Mover** → `18.000` → desde `Banco` → hacia `Visa`.

La app avisa: *"Pagás deuda de Visa. **No es un gasto**: ya lo contaste cuando compraste."*

| | Esperado |
|---|---|
| Resultado del mes | **+$957.000 — SIN CAMBIOS** |
| Visa | **$0** |

> Tu planilla contaba esto dos veces: el consumo *y* el pago del resumen. Acá es
> estructuralmente imposible, porque el pago no toca ninguna categoría.

## 6 · Comprar dólares

**Mover** → `145.000` → desde `Banco` → hacia `Dólares`.
Como cambian de moneda, aparece **Recibís**: poné `100`.

| | Esperado |
|---|---|
| Debajo del monto | *"Te queda a **$1.450,00** por USD"* — el tipo de cambio **deducido**, no escrito |
| Resultado del mes | **+$957.000 — SIN CAMBIOS** |
| Inicio → En dólares | **US$100** |

## 7 · Ajustar un saldo

**Cuentas** → tocá `Banco` → *¿Cuánto dice en realidad?* → escribí `500.000`.

Te muestra el ajuste que va a registrar, contra la categoría *Ajustes*. Confirmá.

| | Esperado |
|---|---|
| Banco | exactamente **$500.000** |
| El ajuste | aparece en Movimientos como un movimiento más, no como una corrección invisible |

> La deriva queda **medida**. Si *Ajustes* crece mes a mes, es señal de que algo se está
> cargando mal.

## 8 · Exportar

**Movimientos → Exportar CSV**. Abrilo. Tienen que estar los 7 movimientos con su fecha,
cuenta, categoría y monto. Ese archivo es tu garantía de no quedar atado a nadie.

---

## El balance final

| Dónde | Esperado |
|---|---|
| Resultado del mes | **+$957.000** |
| Ingresos / Gastos | $1.000.000 / $43.000 |
| Tasa de ahorro | **96%** |
| Banco | $500.000 |
| Ahorro | $300.000 |
| Visa | $0 |
| Dólares | US$100 |

Movimos $463.000 entre cuentas —ahorro, pago de tarjeta y compra de dólares— y **ninguno de
esos pesos tocó el resultado del mes**. Eso es todo el proyecto en una línea.

---

## Y ahora la prueba que de verdad importa

Lo anterior comprueba que el modelo está bien. **Esto comprueba si la app sirve:**

1. Abrí la URL en el **celular**.
2. *Agregar a pantalla de inicio*. Queda como app, con ícono y sin barra de direcciones.
3. **Cronometrate**: desde tocar el ícono hasta que el gasto quedó guardado.

> **El criterio de éxito del MVP es menos de diez segundos.** Y sostenerlo treinta días sin
> volver a la planilla.

Si no llegás, el problema está en la interfaz y se arregla ahí. Ese número, y no otro, dice
si esto reemplazó a la hoja de cálculo.

### Qué mirar mientras la usás

Tres cosas están anotadas como riesgos abiertos y **solo se resuelven usándola**:

| Mirá | Registrado en |
|---|---|
| ¿Cargar **cada** consumo con tarjeta se vuelve insoportable? | [OD-11](ODs.md) |
| Un mes con una compra grande en cuotas, ¿se lee mal? | [OD-24](ODs.md) |
| Las seis categorías frecuentes, ¿son las tuyas a la semana? | — |

---

## Borrar todo antes de arrancar en serio

```bash
psql "$DATABASE_URL" -v reset_confirm=BORRAR_TODO -f supabase/reset_ledger.sql
```

Vacía el contenido y resiembra las categorías. **Conserva tu usuario**: no hay que volver a
crear nada.

> Después de la puesta en marcha, esta ruta deja de estar permitida: ahí se remapea y se
> archiva ([ADR-018](ADRs.md#adr-018--la-puesta-en-marcha-separa-dos-regímenes-de-datos)).
> Y ojo: nada del sistema te lo impide — la línea la marcás vos ([OD-22](ODs.md)).
