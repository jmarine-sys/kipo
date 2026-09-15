-- kipo · esquema base
-- Deriva de docs/modelo-de-datos.md §2. Si algo acá contradice a docs/ADRs.md, ganan los ADRs.

-- ---------------------------------------------------------------------------
-- Libro y miembros — ADR-003
-- ---------------------------------------------------------------------------

create table ledger (
  id                   uuid primary key default gen_random_uuid(),
  name                 text not null,
  registry_currency    text not null default 'ARS',
  measurement_currency text not null default 'USD',   -- ADR-009
  default_fx_source    text not null default 'mep',   -- ADR-011
  created_at           timestamptz not null default now()
);

comment on table ledger is
  'El libro. ADR-003: toda fila del dominio le pertenece a uno, nunca a un usuario directo. '
  'Hoy cada usuario tiene exactamente uno y NO aparece en la interfaz.';

create table ledger_member (
  ledger_id uuid not null references ledger(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  role      text not null default 'owner' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (ledger_id, user_id)
);

comment on table ledger_member is
  'ADR-002 mantiene a los usuarios aislados. El día que eso cambie, compartir es un INSERT acá '
  'y ninguna politica de RLS se toca.';

-- ---------------------------------------------------------------------------
-- Activos y cotizaciones
-- ---------------------------------------------------------------------------

create table instrument (
  id                uuid primary key default gen_random_uuid(),
  ledger_id         uuid not null references ledger(id) on delete cascade,
  symbol            text not null,
  name              text not null,
  kind              text not null check (kind in
                      ('cedear','crypto','stock','etf','fund','bond','other')),
  quote_currency    text not null,
  decimals          int  not null default 2,
  -- OD-17: un CEDEAR representa una fraccion de la accion de afuera. Previsto, sin usar.
  ratio             numeric(38,18),
  underlying_symbol text,
  archived_at       timestamptz,
  created_at        timestamptz not null default now(),
  unique (ledger_id, symbol),
  unique (id, ledger_id)          -- habilita las claves foraneas compuestas de abajo
);

create table price (
  instrument_id uuid not null references instrument(id) on delete cascade,
  ledger_id     uuid not null references ledger(id) on delete cascade,
  on_date       date not null,
  price         numeric(38,18) not null check (price >= 0),
  currency      text not null,
  source        text not null default 'manual',
  primary key (instrument_id, on_date, source)
);

-- ADR-011: la misma fecha puede tener varias cotizaciones validas a la vez, porque lo son.
create table fx_rate (
  ledger_id uuid not null references ledger(id) on delete cascade,
  on_date   date not null,
  base      text not null,
  quote     text not null,
  rate      numeric(38,18) not null check (rate > 0),
  source    text not null check (source in ('oficial','mep','blue','ccl','manual')),
  primary key (ledger_id, on_date, base, quote, source)
);

-- ---------------------------------------------------------------------------
-- Cuentas — ADR-012, el corazon del modelo
-- ---------------------------------------------------------------------------

create table account (
  id              uuid primary key default gen_random_uuid(),
  ledger_id       uuid not null references ledger(id) on delete cascade,
  name            text not null,

  kind            text not null check (kind in ('asset','liability')),

  -- LAS TRES FAMILIAS DE ADR-012: como se responde "cuanto vale hoy"
  --   balance : lo que dice el saldo        (efectivo, banco, remunerada, tarjeta)
  --   accrual : saldo + lo devengado        (plazo fijo)        -- ADR-014
  --   market  : unidades x precio           (CEDEARs, cripto)
  valuation       text not null check (valuation in ('balance','accrual','market')),

  unit            text not null,
  instrument_id   uuid,

  is_spendable    boolean not null default true,
  fx_source       text check (fx_source in ('oficial','mep','blue','ccl','manual')),

  matures_on      date,                    -- solo accrual
  expected_amount numeric(38,18),          -- solo accrual

  institution     text,
  archived_at     timestamptz,
  created_at      timestamptz not null default now(),

  constraint market_needs_instrument
    check ((valuation = 'market') = (instrument_id is not null)),
  constraint accrual_needs_maturity
    check (valuation <> 'accrual' or matures_on is not null),
  constraint instrument_same_ledger
    foreign key (instrument_id, ledger_id) references instrument(id, ledger_id),
  unique (id, ledger_id)
);

comment on column account.valuation is
  'ADR-012: las cuentas se clasifican por COMO SE VALUAN, no por como las llama el banco. '
  'Por eso una cuenta remunerada es balance (ADR-013) y no una inversion.';
comment on column account.is_spendable is
  'Responde "cuanto tengo disponible" del punto 8 del brief: efectivo y remunerada si, '
  'plazo fijo y posiciones no.';

-- ---------------------------------------------------------------------------
-- Categorias
-- ---------------------------------------------------------------------------

create table category (
  id          uuid primary key default gen_random_uuid(),
  ledger_id   uuid not null references ledger(id) on delete cascade,
  parent_id   uuid references category(id),
  name        text not null,
  kind        text not null check (kind in ('income','expense')),
  is_system   boolean not null default false,   -- 'Ajustes' (ADR-005), 'Intereses' (ADR-013)
  sort_order  int not null default 0,
  archived_at timestamptz,
  created_at  timestamptz not null default now(),
  unique (id, ledger_id)
);

comment on table category is
  'ADR-012: "Ahorros" e "Inversiones" NO son categorias. Son cuentas. Sembrarlas aca seria '
  'reintroducir el error 1 del analisis, que restaba el ahorro del resultado del mes.';

-- ---------------------------------------------------------------------------
-- Transacciones y lineas — ADR-001
-- ---------------------------------------------------------------------------

create table transaction (
  id          uuid primary key default gen_random_uuid(),
  ledger_id   uuid not null references ledger(id) on delete cascade,
  occurred_on date not null,
  description text,
  -- la INTENCION con la que se cargo, para reabrir el formulario correcto al editar.
  -- las entries son la verdad; esto es una pista de interfaz.
  kind        text not null check (kind in
                ('expense','income','transfer','exchange','trade','adjustment')),
  created_by  uuid not null references auth.users(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (id, ledger_id)
);

create table entry (
  id             uuid primary key default gen_random_uuid(),
  transaction_id uuid not null,
  ledger_id      uuid not null references ledger(id) on delete cascade,

  account_id     uuid,
  category_id    uuid,

  amount         numeric(38,18) not null,   -- con signo, desde la perspectiva del patrimonio
  unit           text not null,             -- 'ARS','USD','BTC','AAPL-CEDEAR'

  constraint entry_targets_exactly_one
    check (num_nonnulls(account_id, category_id) = 1),

  -- claves foraneas compuestas: la base garantiza que todo pertenece al MISMO libro.
  -- con account_id/category_id en null no se aplica, que es justo lo que queremos.
  constraint entry_tx_same_ledger
    foreign key (transaction_id, ledger_id) references transaction(id, ledger_id) on delete cascade,
  constraint entry_account_same_ledger
    foreign key (account_id, ledger_id) references account(id, ledger_id),
  constraint entry_category_same_ledger
    foreign key (category_id, ledger_id) references category(id, ledger_id)
);

comment on column entry.amount is
  'El signo es SIEMPRE desde la perspectiva del patrimonio. En un pasivo, positivo = debes MENOS. '
  'En una categoria de ingreso, negativo. Es lo que hace que la suma de cero y que '
  'Resultado del mes = -SUM(entries de categorias).';

create index entry_ledger_account_idx  on entry (ledger_id, account_id);
create index entry_ledger_category_idx on entry (ledger_id, category_id);
create index entry_transaction_idx     on entry (transaction_id);
create index transaction_ledger_date_idx on transaction (ledger_id, occurred_on desc);

-- ---------------------------------------------------------------------------
-- Presupuestos y eventos futuros — etapas 2 y 3, previstos desde el dia uno
-- ---------------------------------------------------------------------------

create table budget (
  id          uuid primary key default gen_random_uuid(),
  ledger_id   uuid not null references ledger(id) on delete cascade,
  category_id uuid not null,
  period      date not null,
  amount      numeric(38,18) not null check (amount >= 0),
  currency    text not null,
  unique (ledger_id, category_id, period),
  constraint budget_category_same_ledger
    foreign key (category_id, ledger_id) references category(id, ledger_id)
);

-- ADR-016: un gasto recurrente y el vencimiento de un plazo fijo son el mismo objeto.
create table scheduled_event (
  id          uuid primary key default gen_random_uuid(),
  ledger_id   uuid not null references ledger(id) on delete cascade,
  kind        text not null check (kind in ('recurring','maturity')),
  description text not null,
  category_id uuid,
  account_id  uuid,
  amount      numeric(38,18),          -- null si el importe cambia cada periodo
  currency    text not null,
  frequency   text check (frequency in
                ('weekly','monthly','bimonthly','quarterly','biannual','yearly')),
  next_on     date not null,
  ends_on     date,
  archived_at timestamptz,
  constraint recurring_needs_frequency
    check (kind <> 'recurring' or frequency is not null),
  constraint sched_category_same_ledger
    foreign key (category_id, ledger_id) references category(id, ledger_id),
  constraint sched_account_same_ledger
    foreign key (account_id, ledger_id) references account(id, ledger_id)
);
