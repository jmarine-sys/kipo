# Modelo de datos

> **Capa 2 del orden de autoridad.** Si algo acá contradice a
> [ADRs.md](ADRs.md) o a [ODs.md](ODs.md), **ganan los registros**.
>
> Versión 1.0 — 2026-09-15. Deriva de las decisiones de [ADRs.md](ADRs.md).
>
> **Verificado, no afirmado.** Este esquema se ejecutó contra PostgreSQL 16 el 2026-09-15:
> las 4 migraciones aplican limpias, los 13 casos de uso de §5 se registran, las 11
> aserciones de saldos y resultado dan los números esperados, las 6 invariantes rechazan
> lo que deben rechazar, y el aislamiento por usuario se probó con un rol sin privilegios
> (el dueño ve 13 transacciones, un extraño ve 0). Reproducible con `./supabase/tests/run.sh`.

---

## 1. La idea en una página

Todo se apoya en una sola regla:

> **Cada transacción mueve la misma cantidad de valor entre dos o más lugares. La suma da cero.**

De ahí sale todo lo demás. El resto de este documento es esa regla llevada a tablas.

Hay **cinco entidades centrales** y todo lo demás las acompaña:

```
ledger ─┬─ account ──┬── entry ──┬── transaction
        │            │           │
        ├─ category ─┘           │
        │                        │
        ├─ instrument ── price   │
        └─ fx_rate               │
                                 │
        budget · scheduled_event ┘
```

| Entidad | Qué es | Decisión que la crea |
|---|---|---|
| `ledger` | El libro. Todo pertenece a uno | [ADR-003](ADRs.md#adr-003--toda-fila-del-dominio-pertenece-a-un-libro-ledger-no-a-un-usuario) |
| `account` | Un lugar donde hay valor tuyo | [ADR-012](ADRs.md#adr-012--las-cuentas-se-clasifican-por-cómo-se-valúan-no-por-cómo-las-llama-el-banco) |
| `category` | Para qué entró o salió valor del sistema | [ADR-001](ADRs.md#adr-001--el-modelo-registra-origen-y-destino-de-cada-movimiento-partida-doble-oculta) |
| `transaction` | Un hecho económico con fecha | [ADR-001](ADRs.md#adr-001--el-modelo-registra-origen-y-destino-de-cada-movimiento-partida-doble-oculta) |
| `entry` | Cada pata del hecho. **Es donde vive todo** | [ADR-001](ADRs.md#adr-001--el-modelo-registra-origen-y-destino-de-cada-movimiento-partida-doble-oculta), [ADR-010](ADRs.md#adr-010--el-tipo-de-cambio-de-una-operación-se-deduce-de-sus-montos-no-se-guarda) |

### La decisión de diseño que hace que esto sea chico

**Una posición NO es una tabla aparte. Es una cuenta cuya unidad es un activo.**

Tener 50 CEDEARs de AAPL en Balanz es una cuenta `Balanz · AAPL` con saldo `50 AAPL-CEDEAR`,
exactamente igual que tener mil dólares es una cuenta con saldo `1000 USD`. Comprar CEDEARs y
comprar dólares son **la misma operación** con distinta unidad.

Eso elimina las tablas `holding` y `position`, hace que
[ADR-010](ADRs.md#adr-010--el-tipo-de-cambio-de-una-operación-se-deduce-de-sus-montos-no-se-guarda)
aplique sin excepciones —el precio unitario es el cociente, igual que el tipo de cambio— y reduce el
número de casos especiales a cero.

### El convenio de signos, que hay que entender antes de seguir

**El signo es siempre desde la perspectiva de tu patrimonio.**

| En una cuenta… | Positivo significa | Ejemplo |
|---|---|---|
| **Activo** | Tenés más | `+1000 USD` en efectivo USD |
| **Pasivo** | **Debés menos** | `+800.000 ARS` en Visa = pagaste el resumen |
| **Categoría de gasto** | Salió valor hacia ahí | `+25.000 ARS` en *Supermercado* |
| **Categoría de ingreso** | Entró valor desde ahí | `-2.000.000 ARS` en *Sueldo* |

Las dos últimas filas incomodan al principio y son las que hacen que la suma dé cero. La consecuencia
buena: la fórmula correcta del resultado mensual —la que corrige el error 1 del análisis— cae sola.

```
Resultado del mes  =  −Σ(entries de categorías)
                   =  (ingresos)  −  (gastos)
```

El ahorro y la inversión **no aparecen en esa fórmula**, porque son movimientos entre cuentas y no
tocan ninguna categoría. Exactamente como debe ser.

---

## 2. Las tablas

### 2.1 Libro y miembros

```sql
create table ledger (
  id                   uuid primary key default gen_random_uuid(),
  name                 text not null,
  -- moneda en la que registrás el día a día
  registry_currency    text not null default 'ARS',
  -- moneda en la que se mide el rendimiento — ADR-009
  measurement_currency text not null default 'USD',
  -- fuente de cotización por defecto — ADR-011
  default_fx_source    text not null default 'mep',
  created_at           timestamptz not null default now()
);

create table ledger_member (
  ledger_id uuid not null references ledger(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  role      text not null default 'owner' check (role in ('owner','member')),
  primary key (ledger_id, user_id)
);
```

Hoy cada usuario tiene un libro con un solo miembro
([ADR-002](ADRs.md#adr-002--cada-usuario-ve-solo-sus-propios-datos)). El libro **no aparece en
la interfaz**: se crea solo al registrarse.

### 2.2 Cuentas — el corazón de ADR-012

```sql
create table account (
  id            uuid primary key default gen_random_uuid(),
  ledger_id     uuid not null references ledger(id) on delete cascade,
  name          text not null,

  -- ¿suma o resta al patrimonio?
  kind          text not null check (kind in ('asset','liability')),

  -- LAS TRES FAMILIAS DE ADR-012: cómo se responde "¿cuánto vale hoy?"
  valuation     text not null check (valuation in ('balance','accrual','market')),

  -- la unidad del saldo: 'ARS','USD' … o el activo, si instrument_id no es null
  unit          text not null,
  instrument_id uuid references instrument(id),

  -- ¿es plata que podés gastar hoy? efectivo y remunerada sí; plazo fijo y CEDEARs no
  is_spendable  boolean not null default true,

  -- ADR-011: con qué cotización se valúa. null = el default del libro
  fx_source     text,

  -- solo para valuation='accrual' (plazo fijo) — ADR-014
  matures_on       date,
  expected_amount  numeric(38,18),

  institution   text,           -- 'Balanz', 'Binance', 'Mercado Pago'
  archived_at   timestamptz,    -- nunca se borra: se archiva
  created_at    timestamptz not null default now(),

  constraint market_needs_instrument check (
    (valuation = 'market') = (instrument_id is not null)),
  constraint accrual_needs_maturity check (
    valuation <> 'accrual' or matures_on is not null)
);
```

Así queda el inventario real del usuario:

| Cuenta | `kind` | `valuation` | `unit` | `is_spendable` | `fx_source` |
|---|---|---|---|---|---|
| Efectivo ARS | asset | balance | ARS | ✅ | — |
| Efectivo USD (comprado en blue) | asset | balance | USD | ✅ | `blue` |
| Banco ARS | asset | balance | ARS | ✅ | — |
| Mercado Pago (remunerada) | asset | balance | ARS | ✅ | — |
| **Visa** | **liability** | balance | ARS | ❌ | — |
| Balanz · efectivo | asset | balance | ARS | ❌ | `mep` |
| **Balanz · AAPL** | asset | **market** | `AAPL-CEDEAR` | ❌ | `mep` |
| Binance · USDT | asset | balance | USDT | ❌ | `mep` |
| **Binance · BTC** | asset | **market** | `BTC` | ❌ | `mep` |
| **Plazo fijo 90d** | asset | **accrual** | ARS | ❌ | — |

La cuenta remunerada es `balance`, igual que el banco —
[ADR-013](ADRs.md#adr-013--la-cuenta-remunerada-es-una-cuenta-bancaria-su-interés-es-un-ingreso-mensual).
La palabra "inversión" no aparece en ningún lado: es una vista, no una columna.

### 2.3 Categorías

```sql
create table category (
  id          uuid primary key default gen_random_uuid(),
  ledger_id   uuid not null references ledger(id) on delete cascade,
  parent_id   uuid references category(id),
  name        text not null,
  kind        text not null check (kind in ('income','expense')),
  -- 'Ajustes' (ADR-005) e 'Intereses' (ADR-013) las necesita el modelo
  is_system   boolean not null default false,
  sort_order  int not null default 0,
  archived_at timestamptz,
  created_at  timestamptz not null default now()
);
```

Dos niveles, no tres. La jerarquía se limita con un trigger que rechaza un `parent_id` que ya tenga
padre.

### 2.4 Activos y precios

```sql
create table instrument (
  id              uuid primary key default gen_random_uuid(),
  ledger_id       uuid not null references ledger(id) on delete cascade,
  symbol          text not null,           -- 'AAPL-CEDEAR', 'BTC'
  name            text not null,
  kind            text not null check (kind in
                    ('cedear','crypto','stock','etf','fund','bond','other')),
  quote_currency  text not null,           -- ARS para CEDEARs, USD para cripto
  decimals        int  not null default 2, -- 8 para cripto, 0 para CEDEARs

  -- OD-17: un CEDEAR representa una fracción de la acción de afuera
  ratio             numeric(38,18),        -- cuántos CEDEARs = 1 acción
  underlying_symbol text,                  -- 'AAPL'

  archived_at timestamptz,
  unique (ledger_id, symbol)
);

create table price (
  instrument_id uuid not null references instrument(id) on delete cascade,
  ledger_id     uuid not null references ledger(id) on delete cascade,
  on_date       date not null,
  price         numeric(38,18) not null,
  currency      text not null,
  source        text not null default 'manual',
  primary key (instrument_id, on_date, source)
);

-- ADR-011: la misma fecha puede tener varias cotizaciones válidas a la vez
create table fx_rate (
  ledger_id uuid not null references ledger(id) on delete cascade,
  on_date   date not null,
  base      text not null,   -- 'USD'
  quote     text not null,   -- 'ARS'
  rate      numeric(38,18) not null,
  source    text not null check (source in ('oficial','mep','blue','ccl','manual')),
  primary key (ledger_id, on_date, base, quote, source)
);
```

`ratio` y `underlying_symbol` existen para OD-17 y **todavía no se usan**: están para que cuando se
decida cómo separar el rendimiento del activo del movimiento del CCL, no haya que migrar.

### 2.5 Transacciones y líneas — donde vive todo

```sql
create table transaction (
  id           uuid primary key default gen_random_uuid(),
  ledger_id    uuid not null references ledger(id) on delete cascade,
  occurred_on  date not null,
  description  text,
  -- la INTENCIÓN con la que se cargó, para reabrir el formulario correcto al editar.
  -- las entries son la verdad; esto es una pista de interfaz
  kind         text not null check (kind in
                 ('expense','income','transfer','exchange','trade','adjustment')),
  created_by   uuid not null references auth.users(id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table entry (
  id             uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references transaction(id) on delete cascade,
  -- desnormalizado a propósito: deja que RLS filtre sin joins
  ledger_id      uuid not null references ledger(id) on delete cascade,

  account_id     uuid references account(id),
  category_id    uuid references category(id),

  amount         numeric(38,18) not null,   -- con signo
  unit           text not null,             -- 'ARS','USD','BTC','AAPL-CEDEAR'

  constraint entry_targets_exactly_one
    check (num_nonnulls(account_id, category_id) = 1)
);

create index on entry (ledger_id, account_id);
create index on entry (ledger_id, category_id);
create index on entry (transaction_id);
```

`numeric(38,18)` cubre desde un satoshi hasta cualquier monto en pesos sin perder precisión. El
redondeo es un problema de presentación, nunca de almacenamiento.

### 2.6 Presupuestos y eventos futuros

```sql
create table budget (
  id          uuid primary key default gen_random_uuid(),
  ledger_id   uuid not null references ledger(id) on delete cascade,
  category_id uuid not null references category(id),
  period      date not null,        -- primer día del mes
  amount      numeric(38,18) not null,
  currency    text not null,
  unique (ledger_id, category_id, period)
);

-- OD-19: un gasto recurrente y el vencimiento de un plazo fijo son el mismo objeto
create table scheduled_event (
  id            uuid primary key default gen_random_uuid(),
  ledger_id     uuid not null references ledger(id) on delete cascade,
  kind          text not null check (kind in ('recurring','maturity')),
  description   text not null,
  category_id   uuid references category(id),
  account_id    uuid references account(id),   -- plazo fijo que vence
  amount        numeric(38,18),                -- null si varía cada período
  currency      text not null,
  frequency     text check (frequency in
                  ('weekly','monthly','bimonthly','quarterly','biannual','yearly')),
  next_on       date not null,
  ends_on       date,
  archived_at   timestamptz,
  constraint recurring_needs_frequency
    check (kind <> 'recurring' or frequency is not null)
);
```

---

## 3. La invariante — ADR-010 hecha código

> **Suma cero por unidad, salvo en transacciones de intercambio, donde las dos unidades quedan
> relacionadas por el cociente de sus montos.**

```sql
create or replace function check_transaction_balances()
returns trigger language plpgsql as $$
declare
  units_count int;
  bad_unit    text;
begin
  select count(distinct unit) into units_count
    from entry where transaction_id = coalesce(new.transaction_id, old.transaction_id);

  if units_count <= 1 then
    -- una sola unidad: suma cero, sin excepciones
    select unit into bad_unit
      from entry where transaction_id = coalesce(new.transaction_id, old.transaction_id)
      group by unit having sum(amount) <> 0;
    if bad_unit is not null then
      raise exception 'La transacción no balancea en %', bad_unit;
    end if;

  elsif units_count = 2 then
    -- intercambio: cada unidad debe tener exactamente un signo neto opuesto al otro.
    -- el tipo de cambio es el cociente y NO SE GUARDA (ADR-010)
    if (select count(*) from (
          select unit, sum(amount) s from entry
          where transaction_id = coalesce(new.transaction_id, old.transaction_id)
          group by unit) t where sign(t.s) = 0) > 0 then
      raise exception 'Un intercambio no puede tener una unidad con saldo neto cero';
    end if;

  else
    -- ADR-010 dice explícitamente que con 3+ unidades hay que RECHAZAR, no suponer
    raise exception 'Una transacción no puede mezclar más de dos unidades (tiene %)', units_count;
  end if;

  return null;
end $$;

create constraint trigger transaction_balances
  after insert or update or delete on entry
  deferrable initially deferred
  for each row execute function check_transaction_balances();
```

`deferrable initially deferred` es lo que permite insertar las líneas de a una dentro de una
transacción de base de datos: la validación corre recién al confirmar, cuando ya están todas.

### Lo que esta invariante NO puede verificar

Con dos unidades, la base puede exigir que ninguna pata quede en cero, pero **no puede juzgar si el
cociente es razonable**: registrar mil dólares a 145 en vez de a 1.450 es una transacción
perfectamente válida para el motor. No hay forma de saberlo sin una cotización externa.

**Esa validación es de interfaz, no de base de datos** — comparar contra la última `fx_rate` conocida
y pedir confirmación si se aparta demasiado. Registrado en OD-21.

**Dos invariantes más, por trigger:**

1. Si `entry.account_id` no es null, `entry.unit` **debe** coincidir con `account.unit`. La
   denormalización de `unit` es lo que hace barata la validación de arriba; el trigger es lo que
   evita que mienta.
2. `category.parent_id` no puede apuntar a una categoría que ya tenga padre. Dos niveles.

---

## 4. Aislamiento — ADR-002, ADR-003 y ADR-007

Todas las tablas del dominio llevan `ledger_id`, así que **la política es la misma en todas y no
necesita joins**:

```sql
create or replace function my_ledgers() returns setof uuid
language sql stable security definer as $$
  select ledger_id from ledger_member where user_id = auth.uid()
$$;

alter table account enable row level security;
create policy account_rw on account
  for all using (ledger_id in (select my_ledgers()))
        with check (ledger_id in (select my_ledgers()));
-- … idéntica en category, instrument, price, fx_rate,
--     transaction, entry, budget, scheduled_event
```

Hoy `my_ledgers()` devuelve siempre un libro. El día que
[ADR-002](ADRs.md#adr-002--cada-usuario-ve-solo-sus-propios-datos) cambie, **compartir es un `INSERT`
en `ledger_member`** y ninguna política se toca. Eso es lo que compró
[ADR-003](ADRs.md#adr-003--toda-fila-del-dominio-pertenece-a-un-libro-ledger-no-a-un-usuario).

---

## 5. Los casos de uso, resueltos contra el esquema

Esta es la prueba de que el modelo funciona. Cada caso real del usuario, con sus líneas.

### 5.1 Gasto con débito — `kind='expense'`

> Supermercado, $25.000, débito del banco

| cuenta / categoría | amount | unit |
|---|---:|---|
| Banco ARS | −25.000 | ARS |
| *Supermercado* | +25.000 | ARS |

Patrimonio: **baja 25.000**. ✅

### 5.2 Gasto con tarjeta — `kind='expense'` · ADR-004

> Restaurante, $18.000, Visa

| cuenta / categoría | amount | unit |
|---|---:|---|
| **Visa** (pasivo) | −18.000 | ARS |
| *Restaurantes* | +18.000 | ARS |

El pasivo se hace más negativo: **debés más**. El gasto queda en **su** mes y con **su** categoría.
Patrimonio: **baja 18.000**. ✅

### 5.3 Pago del resumen — `kind='transfer'` · ADR-004

> Pagás $800.000 del resumen de Visa

| cuenta / categoría | amount | unit |
|---|---:|---|
| Banco ARS | −800.000 | ARS |
| **Visa** (pasivo) | +800.000 | ARS |

**Ninguna categoría participa.** Patrimonio: **sin cambios** — el banco bajó y la deuda bajó igual.
Esto es lo que impide duplicar los gastos, y es literalmente imposible equivocarse porque no hay
ninguna categoría a la que imputarlo. ✅

### 5.4 Sueldo — `kind='income'`

| cuenta / categoría | amount | unit |
|---|---:|---|
| Banco ARS | +2.000.000 | ARS |
| *Sueldo* | −2.000.000 | ARS |

Patrimonio: **sube 2.000.000**. ✅

### 5.5 Compra de dólar blue — `kind='exchange'` · ADR-010

> Mil dólares a 1.450

| cuenta / categoría | amount | unit |
|---|---:|---|
| Banco ARS | −1.450.000 | ARS |
| Efectivo USD | +1.000 | USD |

Dos unidades → **el tipo de cambio 1.450 es el cociente**, no se guarda en ningún campo. Ninguna
categoría participa: **no es un gasto**. Patrimonio: **sin cambios**. ✅

### 5.6 Transferencia a Balanz — `kind='transfer'`

| cuenta / categoría | amount | unit |
|---|---:|---|
| Banco ARS | −500.000 | ARS |
| Balanz · efectivo | +500.000 | ARS |

Patrimonio sin cambios. Pero `is_spendable` pasa de `true` a `false`: **bajó lo disponible, no el
patrimonio.** ✅

### 5.7 Compra de CEDEARs — `kind='trade'`

> 50 CEDEARs de AAPL a $3.000

| cuenta / categoría | amount | unit |
|---|---:|---|
| Balanz · efectivo | −150.000 | ARS |
| **Balanz · AAPL** | +50 | AAPL-CEDEAR |

Idéntico en forma al caso 5.5. **El precio unitario de 3.000 es el cociente.** Patrimonio sin
cambios. ✅

### 5.8 Venta de CEDEARs — `kind='trade'` · el caso del error 7

> Vendés los 50 a $4.000

| cuenta / categoría | amount | unit |
|---|---:|---|
| **Balanz · AAPL** | −50 | AAPL-CEDEAR |
| Balanz · efectivo | +200.000 | ARS |

**Patrimonio: sin cambios.** La cuenta AAPL valía 200.000 a precio de mercado y ahora vale 0; el
efectivo subió 200.000. La ganancia ya estaba reconocida mientras el precio subía —era **no
realizada**— y vender solo la convierte en **realizada**.

**Ninguna categoría de ingreso participa**, y por eso el sistema no puede contar la ganancia dos
veces. Era el riesgo que planteaba el punto 14 del brief, y el modelo lo hace estructuralmente
imposible. ✅

La ganancia realizada es un **reporte**, no un movimiento: precio de venta menos costo de compra,
reconstruido del historial de entries. *(El método de costo — FIFO o promedio ponderado — queda
abierto en OD-20.)*

### 5.9 Compra de cripto — `kind='trade'`

| cuenta / categoría | amount | unit |
|---|---:|---|
| Binance · USDT | −500 | USDT |
| **Binance · BTC** | +0,00512 | BTC |

Los 18 decimales de `numeric(38,18)` están para esto. ✅

### 5.10 Interés mensual de Mercado Pago — `kind='income'` · ADR-013

| cuenta / categoría | amount | unit |
|---|---:|---|
| Mercado Pago | +12.400 | ARS |
| *Intereses* | −12.400 | ARS |

**Un movimiento por mes, no por día.** Patrimonio sube. Y como *Intereses* es su propia categoría, no
ensucia la proyección del sueldo. ✅

### 5.11 Constituir un plazo fijo — `kind='transfer'` · ADR-014

| cuenta / categoría | amount | unit |
|---|---:|---|
| Banco ARS | −1.000.000 | ARS |
| **Plazo fijo 90d** | +1.000.000 | ARS |

La cuenta se crea con `valuation='accrual'`, `matures_on`, `expected_amount = 1.090.000` y
`is_spendable=false`. Patrimonio sin cambios; lo disponible **baja un millón**. ✅

Y al crearla se genera su `scheduled_event` de tipo `maturity` — que es el mismo motor que avisa
"próximamente: seguro anual". OD-19.

### 5.12 Vencimiento del plazo fijo — `kind='income'` · ADR-014

| cuenta / categoría | amount | unit |
|---|---:|---|
| **Plazo fijo 90d** | −1.000.000 | ARS |
| Banco ARS | +1.090.000 | ARS |
| *Intereses* | −90.000 | ARS |

Tres líneas, **una sola unidad**, suma cero: `−1.000.000 + 1.090.000 − 90.000 = 0`. ✅

Acá se ve el salto de patrimonio que anticipa ADR-014: los 90.000 aparecen de golpe el día del
vencimiento. Es honesto, pero hay que leerlo como interés y no como un ingreso extraordinario — por
eso va a *Intereses*.

### 5.13 Ajuste de saldo — `kind='adjustment'` · ADR-005

> El banco dice 347.500 y la app dice 352.000

| cuenta / categoría | amount | unit |
|---|---:|---|
| Banco ARS | −4.500 | ARS |
| *Ajustes* (sistema) | +4.500 | ARS |

La válvula de escape de los saldos aproximados. Al ir a su propia categoría de sistema, **la deriva
queda medida**: si *Ajustes* crece mes a mes, es señal de que algo se está cargando mal. ✅

---

## 6. Las preguntas del brief, resueltas

### Saldo de una cuenta

```sql
select sum(amount) from entry
 where account_id = $1;   -- en la unidad de la cuenta
```

### Patrimonio a una fecha, en la moneda de medición

```
patrimonio = Σ  valor_de_cada_cuenta_a_esa_fecha  convertido con SU fx_source
```

| Familia | Valor de la cuenta |
|---|---|
| `balance` | El saldo |
| `accrual` | El saldo *(el interés se reconoce al vencimiento — ADR-014)* |
| `market` | Saldo en unidades **×** `price` de esa fecha |

Cada cuenta se convierte con **su propia** `fx_source` ([ADR-011](ADRs.md#adr-011--la-fuente-de-cotización-es-una-propiedad-de-la-cuenta-no-de-la-fecha)),
cayendo al `default_fx_source` del libro si es null. **Toda pantalla que muestre un total debe poder
decir qué cotización usó.**

### Cuánto tengo disponible

```sql
-- la pregunta del punto 8 del brief que la planilla no podía responder
select sum(amount) from entry e
  join account a on a.id = e.account_id
 where a.is_spendable and a.ledger_id = $1;
```

### Resultado del mes

```sql
select -sum(e.amount) as resultado
  from entry e
  join transaction t on t.id = e.transaction_id
 where e.category_id is not null
   and t.occurred_on between $desde and $hasta;
```

Ingresos menos gastos. **El ahorro y las inversiones no aparecen** porque no tocan categorías —
que es exactamente lo que corrige el error 1 del análisis.

### Tasa de ahorro

```
tasa = (ingresos − gastos) / ingresos
```

Con `ingresos = −Σ(entries de categorías income)` y `gastos = Σ(entries de categorías expense)`.

---

## 7. Lo que este modelo NO resuelve todavía

Honestidad sobre los bordes, para que nadie lo descubra a los tres meses:

| Límite | Dónde se trata |
|---|---|
| Una transacción no puede mezclar **más de dos unidades** — se rechaza, no se supone | [ADR-010](ADRs.md#adr-010--el-tipo-de-cambio-de-una-operación-se-deduce-de-sus-montos-no-se-guarda) |
| El precio de un CEDEAR **mezcla** rendimiento del activo y movimiento del CCL. Las columnas `ratio` y `underlying_symbol` están puestas, sin usar | OD-17 |
| El **método de costo** para la ganancia realizada (FIFO o promedio ponderado) | OD-20 |
| Durante un plazo fijo el patrimonio queda subestimado y **pega un salto** al vencimiento | [ADR-014](ADRs.md#adr-014--el-plazo-fijo-reconoce-su-interés-al-vencimiento) |
| Entre cargas mensuales, la cuenta remunerada queda subestimada | [ADR-013](ADRs.md#adr-013--la-cuenta-remunerada-es-una-cuenta-bancaria-su-interés-es-un-ingreso-mensual) |
| Los saldos son **estimaciones** y la interfaz tiene que decirlo | [ADR-005](ADRs.md#adr-005--los-saldos-son-aproximados-no-hay-conciliación-bancaria), OD-13 |
| No hay backups automáticos: hace falta `pg_dump` programado **y probar la restauración** | OD-16 |

---

## 8. Qué entra en el MVP

Del esquema completo, la interfaz del MVP toca solo esto:

| Tabla | ¿MVP? |
|---|---|
| `ledger`, `ledger_member` | ✅ automático, invisible |
| `account` — familias `balance` únicamente | ✅ |
| `category`, `transaction`, `entry` | ✅ |
| `fx_rate` — carga manual | ✅ (para el caso 5.5) |
| `instrument`, `price` | ⛔ existen, sin interfaz |
| `account` familias `market` y `accrual` | ⛔ existen, sin interfaz |
| `budget` | ⛔ etapa 2 |
| `scheduled_event` | ⛔ etapa 3 |

**Las tablas se crean todas desde el día uno.** Una tabla vacía no cuesta nada; migrar un modelo con
datos cargados cuesta carísimo. Es la regla del análisis: *el esquema soporta todo, la interfaz solo
el MVP.*


---

## 9. Cambiar las categorías

Dos rutas, y **cuál corresponde depende de qué lado de la puesta en marcha estés**
([ADR-018](ADRs.md#adr-018--la-puesta-en-marcha-separa-dos-regímenes-de-datos)).

### Antes de la puesta en marcha — borrón y cuenta nueva

Los datos de prueba son descartables. Se vacía todo y se vuelve a sembrar:

```bash
psql "$DATABASE_URL" -v reset_confirm=BORRAR_TODO -f supabase/reset_ledger.sql
```

Sin esa confirmación el script aborta sin tocar nada. Conserva el libro y el usuario: vacía el
contenido, no la identidad.

### Después de la puesta en marcha — remapear y archivar

**No hace falta borrar nada para cambiar las categorías por completo.** Se crean las nuevas, se
mudan los movimientos y se archivan las viejas:

```sql
begin;

-- 1. las categorías nuevas
insert into category (ledger_id, name, kind, sort_order)
  values ('<ledger>', 'Casa', 'expense', 10);

-- 2. mudar los movimientos
update entry
   set category_id = (select id from category where name = 'Casa')
 where category_id in (select id from category
                        where name in ('Alquiler / Expensas','Servicios'));

-- 3. archivar las viejas. NO se borran: 'archived_at' las saca de los
--    desplegables y las deja disponibles para leer el historial
update category set archived_at = now()
 where name in ('Alquiler / Expensas','Servicios');

commit;
```

**No se pierde un solo número.** Los montos, las fechas y las transacciones quedan intactos: lo único
que cambia es a qué categoría apuntan.

### Lo que la base no te va a dejar hacer nunca

```sql
delete from category where name = 'Supermercado';
-- ERROR: foreign_key_violation
```

Una categoría con movimientos **no se puede borrar**. El principio del brief —*"no destruir
información histórica"*— no está confiado a que alguien se acuerde: es una clave foránea.

Una categoría vacía sí se puede borrar, porque no hay nada que proteger.


---

## 10. Cómo se escribe y cómo se lee

### Escritura — una función, un viaje

Todo movimiento se registra con `create_transaction()`
([ADR-019](ADRs.md#adr-019--registrar-un-movimiento-es-una-función-de-base-no-dos-inserciones-del-cliente)):

```ts
await supabase.rpc('create_transaction', {
  p_occurred_on: '2026-09-15',
  p_kind: 'expense',
  p_entries: [
    { account_id: '…', amount: '-25000', unit: 'ARS' },
    { category_id: '…', amount: '25000', unit: 'ARS' }
  ],
  p_description: 'Chino de la esquina'
});
```

**El cliente nunca envía `ledger_id`**: lo pone la base vía `my_ledger()` como `DEFAULT`, y RLS lo
verifica. Si las líneas no balancean, no queda nada.

**El convenio de signos no se escribe a mano en ninguna pantalla.** Vive en
`src/lib/ledger/entries.ts`, que traduce intención a líneas: `expense()`, `income()`, `transfer()`,
`exchange()`, `adjustment()`. Una pantalla dice *"esto es un gasto"*; nunca decide un signo.

### Lectura — una vista

Las claves foráneas de `entry` hacia `account` y `category` son **compuestas**
(`(account_id, ledger_id)`), que es lo que garantiza sin triggers que todo pertenece al mismo libro.
El costo es que el inferidor de relaciones de PostgREST puede no resolver el embebido automático.

Por eso se lee de la vista `entry_detail`, que trae la unión ya hecha: un viaje, sin sintaxis de
embebido, y el join lo hace la base que es donde es barato. La vista declara `security_invoker = on`,
así que **RLS sigue aplicando** — verificado: un extraño ve cero filas.
