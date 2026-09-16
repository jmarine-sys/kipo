-- El portafolio es el BORDE — ADR-026.
--
-- Hasta acá el rendimiento se medía por posición: `flujo_inversion` solo miraba
-- cuentas `market` y `accrual`. Eso tiene tres agujeros, y los tres son el mismo:
--
--   1. El efectivo quieto en el broker no existía. Vendías ETH, dejabas los
--      dólares ahí, y el portafolio marcaba cero.
--   2. La plata depositada que espera no penalizaba. El aporte se fechaba en la
--      COMPRA, no en el depósito, así que los meses ociosos no aparecían y el
--      rendimiento salía mejor de lo que fue.
--   3. Comprar adentro contaba como aporte nuevo, cuando es la misma plata
--      cambiando de forma.
--
-- Con el portafolio como borde, una sola condición los cierra a los tres: es
-- flujo solo lo que tiene la contraparte AFUERA.

create table portfolio (
  id          uuid primary key default gen_random_uuid(),
  ledger_id   uuid not null default my_ledger() references ledger(id) on delete cascade,
  name        text not null,
  -- Con qué dólar se mide TODO lo de adentro, salvo que una cuenta diga otra
  -- cosa. Balanz al CCL, Binance al cripto. Null = el del libro.
  fx_source   text,
  archived_at timestamptz,
  created_at  timestamptz not null default now(),
  unique (ledger_id, name),
  unique (id, ledger_id)           -- habilita la clave foranea compuesta de abajo
);

-- Pertenecer a un portafolio es OPCIONAL y esa es la diferencia con agrupar por
-- institución: tu cuenta remunerada de Mercado Pago no tiene por qué entrar,
-- aunque Mercado Pago también sea una institución. ADR-013 ya había decidido que
-- una cuenta remunerada es un banco, no una inversión.
alter table account add column portfolio_id uuid;

-- Compuesta contra (id, ledger_id): garantiza en el esquema que una cuenta no
-- pueda apuntar a un portafolio de OTRO libro. Sin triggers.
alter table account add constraint account_portfolio_fk
  foreign key (portfolio_id, ledger_id) references portfolio(id, ledger_id)
  on delete set null;

create index account_portfolio_idx on account (portfolio_id) where portfolio_id is not null;

alter table portfolio enable row level security;
alter table portfolio force row level security;
create policy portfolio_member_rw on portfolio for all to authenticated
  using      (ledger_id in (select my_ledgers()))
  with check (ledger_id in (select my_ledgers()));

grant select, insert, update, delete on portfolio to authenticated;

-- ---------------------------------------------------------------------------
-- Cuánto vale UNA cuenta, la que sea.
--
-- `valor_inversion` sabía valuar posiciones y plazos fijos, pero no el efectivo.
-- Ahora hay UNA sola definición de "cuánto vale una cuenta" y valor_inversion
-- pasa a ser un recorte de ella. La lección ya apareció tres veces en este
-- proyecto: cuando algo se define en seis lugares, los seis dejan de coincidir.
-- ---------------------------------------------------------------------------

drop view if exists valor_inversion;

create view valor_cuenta as
  select a.id            as account_id,
         a.ledger_id,
         a.portfolio_id,
         a.name,
         a.kind          as account_kind,
         a.valuation,
         a.unit,
         a.institution,
         a.matures_on,
         (a.archived_at is not null) as cerrada,
         -- La cuenta manda sobre el portafolio, y el portafolio sobre el libro.
         coalesce(a.fx_source, pf.fx_source) as fx_source,
         i.symbol,
         i.kind          as kind,
         i.quote_currency,
         i.ratio,
         i.underlying_symbol,
         coalesce(sal.saldo, 0) as saldo,
         v.valor_nativo,
         case when a.valuation = 'market' then i.quote_currency else a.unit end as moneda,
         pr.on_date as precio_al,
         convertir(v.valor_nativo,
                   case when a.valuation = 'market' then i.quote_currency else a.unit end,
                   current_date, 'USD', coalesce(a.fx_source, pf.fx_source)) as usd,
         convertir(v.valor_nativo,
                   case when a.valuation = 'market' then i.quote_currency else a.unit end,
                   current_date, 'UVA', coalesce(a.fx_source, pf.fx_source)) as uva
    from account a
    left join portfolio pf on pf.id = a.portfolio_id
    left join instrument i on i.id = a.instrument_id
    left join lateral (
      select sum(e.amount) as saldo from entry e where e.account_id = a.id
    ) sal on true
    left join lateral (
      select p.price, p.on_date from price p
       where p.instrument_id = a.instrument_id
       order by p.on_date desc limit 1
    ) pr on true
    left join lateral (
      select case
               -- Saldo cero vale cero sin necesitar precio: una posición cerrada
               -- no deja de existir por no tener cotización.
               when coalesce(sal.saldo, 0) = 0 then 0
               when a.valuation = 'market'     then sal.saldo * pr.price
               else sal.saldo
             end as valor_nativo
    ) v on true;

alter view valor_cuenta set (security_invoker = on);
grant select on valor_cuenta to authenticated;

create view valor_inversion as
  select * from valor_cuenta where valuation in ('market', 'accrual');

alter view valor_inversion set (security_invoker = on);
grant select on valor_inversion to authenticated;

-- ---------------------------------------------------------------------------
-- Cuánto vale un portafolio entero: posiciones MÁS efectivo quieto.
--
-- `sin_valuar` no es decorativo: sum() ignora los nulos, así que una posición
-- sin precio desaparecería del total sin dejar rastro y el número se vería
-- completo. La pantalla tiene que poder decir "no incluye 2 posiciones".
-- ---------------------------------------------------------------------------

create view valor_portafolio as
  select p.id          as portfolio_id,
         p.ledger_id,
         p.name,
         p.fx_source,
         (p.archived_at is not null) as cerrado,
         count(v.account_id)                                  as cuentas,
         count(*) filter (where v.usd is null
                            and v.account_id is not null)     as sin_valuar,
         sum(v.usd)                                           as usd,
         sum(v.uva)                                           as uva
    from portfolio p
    left join valor_cuenta v on v.portfolio_id = p.id
   group by p.id, p.ledger_id, p.name, p.fx_source, p.archived_at;

alter view valor_portafolio set (security_invoker = on);
grant select on valor_portafolio to authenticated;

-- ---------------------------------------------------------------------------
-- Qué cruzó el borde. LA vista de este ADR.
--
-- Se mide sobre la pata de AFUERA -igual que flujo_inversion- y no sobre la de
-- adentro: cuando comprás un CEDEAR con pesos, lo que cruzó son los pesos, y los
-- pesos se convierten a dólares con la cotización del día. Convertir la pata de
-- adentro exigiría el precio del activo en esa fecha, que puede no existir.
--
-- Una contraparte con account_id NULL es una categoría, o sea un ingreso o un
-- gasto: el interés que paga el broker NO es plata que aportaste, es rendimiento
-- generado adentro. Por eso el join exige account_id not null.
-- ---------------------------------------------------------------------------

create view flujo_portafolio as
  with participa as (
    select distinct a.portfolio_id, e.transaction_id
      from entry e
      join account a on a.id = e.account_id
     where a.portfolio_id is not null
  )
  select pa.portfolio_id,
         t.occurred_on           as fecha,
         c.unit                  as unidad,
         sum(c.amount)           as monto,
         convertir(sum(c.amount), c.unit, t.occurred_on, 'USD', pf.fx_source) as usd,
         convertir(sum(c.amount), c.unit, t.occurred_on, 'UVA', pf.fx_source) as uva
    from participa pa
    join portfolio pf on pf.id = pa.portfolio_id
    join transaction t on t.id = pa.transaction_id
    join entry c on c.transaction_id = t.id
                and c.account_id is not null
    join account ca on ca.id = c.account_id
   where ca.portfolio_id is distinct from pa.portfolio_id
   group by pa.portfolio_id, t.id, t.occurred_on, c.unit, pf.fx_source;

alter view flujo_portafolio set (security_invoker = on);
grant select on flujo_portafolio to authenticated;

comment on view flujo_portafolio is
  'Solo lo que cruza el borde del portafolio. Comprar adentro no es flujo: es la '
  'misma plata cambiando de forma. ADR-026.';
