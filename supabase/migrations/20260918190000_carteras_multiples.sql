-- Una posicion puede estar en varias carteras — OD-40.
--
-- `account.portfolio_id` era UN campo, asi que AAPL podia estar en "Todo" o en
-- "Tecnologia", nunca en las dos. El usuario pidio poder armar carteras logicas
-- que se solapen, y ademas que exista una por defecto en vez de tildar a mano.
--
-- LO QUE PARECIA UN PROBLEMA Y NO LO ES. Si una posicion esta en dos carteras,
-- la misma operacion puede ser aporte en una y no en la otra. Suena a
-- contradiccion y es exactamente lo correcto:
--
--   "Todo"        tiene AAPL y el efectivo de Balanz
--   "Tecnologia"  tiene solo AAPL
--
--   Comprar AAPL con pesos de Balanz:
--     para "Todo"        las dos patas estan adentro  -> NO es aporte
--     para "Tecnologia"  la plata vino de afuera      -> SI es aporte
--
-- Las dos lecturas son ciertas porque los bordes son distintos, y ADR-026 define
-- el flujo por borde, no por operacion. No hubo que cambiar la regla: solo hubo
-- que dejar de suponer que cada cuenta tiene un solo borde.
--
-- LO QUE SI SE ROMPIA: la fuente de cotizacion. `valor_cuenta` resolvia
-- cuenta -> cartera -> libro, y con varias carteras "la cartera" es ambigua. Se
-- resolvio bajando esa resolucion un nivel: la CUENTA se mide con su propia
-- fuente (o la del libro), y la fuente de la cartera se aplica al valuar ESA
-- cartera. Cada borde convierte con su vara, que es lo que ADR-023 ya decia.

create table portfolio_account (
  portfolio_id uuid not null,
  account_id   uuid not null,
  ledger_id    uuid not null,
  added_at     timestamptz not null default now(),
  primary key (portfolio_id, account_id),
  constraint pa_portfolio_same_ledger
    foreign key (portfolio_id, ledger_id) references portfolio(id, ledger_id) on delete cascade,
  constraint pa_account_same_ledger
    foreign key (account_id, ledger_id) references account(id, ledger_id) on delete cascade
);

create index portfolio_account_cuenta_idx on portfolio_account (account_id);

alter table portfolio_account enable row level security;
alter table portfolio_account force row level security;
create policy portfolio_account_activo on portfolio_account for all to authenticated
  using      (ledger_id = my_ledger())
  with check (ledger_id = my_ledger());

grant select, insert, update, delete on portfolio_account to authenticated;

-- Lo que ya estaba asignado se muda, y recien despues cae la columna: dos
-- fuentes de verdad conviviendo es como empiezan a discrepar.
insert into portfolio_account (portfolio_id, account_id, ledger_id)
select a.portfolio_id, a.id, a.ledger_id
  from account a where a.portfolio_id is not null
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Las vistas. Se recrean COMPLETAS desde su ultima version.
-- ---------------------------------------------------------------------------

drop view if exists valor_portafolio;
drop view if exists flujo_portafolio;
drop view if exists valor_inversion;
drop view if exists valor_cuenta;

alter table account drop column portfolio_id;

create view valor_cuenta as
  select a.id            as account_id,
         a.ledger_id,
         a.name,
         a.kind          as account_kind,
         a.valuation,
         a.unit,
         a.institution,
         a.matures_on,
         (a.archived_at is not null) as cerrada,
         -- Ya NO mezcla la cartera: una cuenta puede estar en varias y "la
         -- cartera" seria ambiguo. Cada cartera aplica la suya al valuarse.
         a.fx_source,
         i.symbol,
         i.kind          as kind,
         i.quote_currency,
         i.ratio,
         i.underlying_symbol,
         i.quote_size,
         coalesce(sal.saldo, 0) as saldo,
         -- En cuantas carteras esta. Con pertenencia multiple, "suelta" ya no es
         -- un campo nulo: es este contador en cero. Y una cuenta suelta mide mal
         -- en silencio, asi que la pantalla necesita poder decirlo.
         coalesce(car.n, 0) as carteras,
         v.valor_nativo,
         case when a.valuation = 'market' then i.quote_currency else a.unit end as moneda,
         pr.on_date as precio_al,
         convertir(v.valor_nativo,
                   case when a.valuation = 'market' then i.quote_currency else a.unit end,
                   current_date, 'USD', a.fx_source) as usd,
         convertir(v.valor_nativo,
                   case when a.valuation = 'market' then i.quote_currency else a.unit end,
                   current_date, 'UVA', a.fx_source) as uva
    from account a
    left join instrument i on i.id = a.instrument_id
    left join lateral (
      select sum(e.amount) as saldo from entry e where e.account_id = a.id
    ) sal on true
    left join lateral (
      select count(*) as n from portfolio_account pa where pa.account_id = a.id
    ) car on true
    left join lateral (
      select p.price, p.on_date from price p
       where p.instrument_id = a.instrument_id
       order by p.on_date desc limit 1
    ) pr on true
    left join lateral (
      select case
               when coalesce(sal.saldo, 0) = 0 then 0
               when a.valuation = 'market'
                 then sal.saldo * pr.price / coalesce(i.quote_size, 1)
               else sal.saldo
             end as valor_nativo
    ) v on true;

alter view valor_cuenta set (security_invoker = on);
grant select on valor_cuenta to authenticated;

create view valor_inversion as
  select * from valor_cuenta where valuation in ('market', 'accrual');

alter view valor_inversion set (security_invoker = on);
grant select on valor_inversion to authenticated;

-- Cada cartera convierte con SU vara: la de la cuenta si la tiene, la de la
-- cartera si no. Un CEDEAR sigue midiendose al CCL aunque la cartera diga MEP.
create view valor_portafolio as
  select p.id          as portfolio_id,
         p.ledger_id,
         p.name,
         p.fx_source,
         (p.archived_at is not null) as cerrado,
         count(v.account_id)                              as cuentas,
         count(*) filter (where v.account_id is not null
                            and convertir(v.valor_nativo, v.moneda, current_date,
                                          'USD', coalesce(v.fx_source, p.fx_source)) is null)
                                                          as sin_valuar,
         sum(convertir(v.valor_nativo, v.moneda, current_date,
                       'USD', coalesce(v.fx_source, p.fx_source)))  as usd,
         sum(convertir(v.valor_nativo, v.moneda, current_date,
                       'UVA', coalesce(v.fx_source, p.fx_source)))  as uva
    from portfolio p
    left join portfolio_account pa on pa.portfolio_id = p.id
    left join valor_cuenta v on v.account_id = pa.account_id
   group by p.id, p.ledger_id, p.name, p.fx_source, p.archived_at;

alter view valor_portafolio set (security_invoker = on);
grant select on valor_portafolio to authenticated;

-- Es flujo lo que tiene la contraparte fuera de ESTA cartera. Con carteras que
-- se solapan, "fuera" se evalua por cartera, y por eso la misma compra puede ser
-- aporte en una y movimiento interno en otra.
create view flujo_portafolio as
  with participa as (
    select distinct pa.portfolio_id, e.transaction_id
      from entry e
      join portfolio_account pa on pa.account_id = e.account_id
  )
  select pp.portfolio_id,
         t.occurred_on           as fecha,
         c.unit                  as unidad,
         sum(c.amount)           as monto,
         convertir(sum(c.amount), c.unit, t.occurred_on, 'USD', pf.fx_source) as usd,
         convertir(sum(c.amount), c.unit, t.occurred_on, 'UVA', pf.fx_source) as uva
    from participa pp
    join portfolio pf on pf.id = pp.portfolio_id
    join transaction t on t.id = pp.transaction_id
    join entry c on c.transaction_id = t.id
                and c.account_id is not null
   where not exists (
           select 1 from portfolio_account x
            where x.portfolio_id = pp.portfolio_id
              and x.account_id  = c.account_id)
   group by pp.portfolio_id, t.id, t.occurred_on, c.unit, pf.fx_source;

alter view flujo_portafolio set (security_invoker = on);
grant select on flujo_portafolio to authenticated;

comment on view flujo_portafolio is
  'Solo lo que cruza el borde de cada cartera. Con carteras que se solapan, la '
  'misma operacion puede cruzar una y no otra: los bordes son distintos y las '
  'dos lecturas son ciertas. ADR-026 / OD-40.';

-- ---------------------------------------------------------------------------
-- La cartera por defecto: la del broker.
--
-- El usuario tenia que crear la cartera y tildar cuenta por cuenta, y hasta que
-- lo hiciera el rendimiento se medi­a mal en silencio (ADR-026: una cuenta suelta
-- hace que comprar con ese efectivo cuente como aporte nuevo).
--
-- La regla: si una cuenta es de broker -una posicion, o efectivo que NO es
-- gastable- y dice donde esta, entra sola a la cartera de ese lugar, creandola
-- si no existe. Es exactamente "una cartera por cuenta comitente con sus activos
-- adentro", y sale gratis porque `comprar_activo` ya guarda el broker en
-- `institution`.
--
-- Lo que NO entra: una caja de ahorro. Tener plata en el Macro no es una cartera
-- de inversion, y meterla ahi dentro haria que mover plata del banco al broker
-- dejara de contarse como aporte.
--
-- Es un trigger y no un cambio en `comprar_activo` por la misma razon de siempre:
-- esa funcion habria que copiarla entera para no perderle nada, y asi la regla
-- vale para cualquier alta de cuenta, venga de donde venga.

create or replace function cartera_del_broker() returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cartera uuid;
  v_donde   text := nullif(trim(coalesce(new.institution, '')), '');
begin
  if v_donde is null then return new; end if;
  if not (new.valuation = 'market' or (new.valuation = 'balance' and not new.is_spendable)) then
    return new;
  end if;

  select id into v_cartera
    from portfolio
   where ledger_id = new.ledger_id and lower(name) = lower(v_donde) and archived_at is null;

  if v_cartera is null then
    insert into portfolio (ledger_id, name) values (new.ledger_id, v_donde)
    returning id into v_cartera;
  end if;

  insert into portfolio_account (portfolio_id, account_id, ledger_id)
  values (v_cartera, new.id, new.ledger_id)
  on conflict do nothing;

  return new;
end $$;

create trigger account_cartera_del_broker
  after insert on account
  for each row execute function cartera_del_broker();

comment on function cartera_del_broker() is
  'Una cuenta de broker entra sola a la cartera de su institucion. Sin esto habia '
  'que tildar cuenta por cuenta, y hasta hacerlo el rendimiento se media mal en '
  'silencio. OD-40.';
