-- Un bono no cotiza por unidad: cotiza por cada 100 nominales — OD-39.
--
-- Verificado el 2026-09-18 contra data912 con la cartera real del usuario:
--
--   AL30  -> 85100      no es el precio de UNO, es por 100 VN
--   PN43O -> 165700     idem, una obligacion negociable
--   YPFD  -> 8735       esto SI es por accion
--
-- Guardar 85100 como precio unitario haria que una tenencia de 10.000 nominales
-- valiera CIEN VECES de mas. Y no fallaria: mostraria un patrimonio enorme y
-- perfectamente creible.
--
-- Se arregla en el modelo y no en el script de precios a proposito. Si la
-- division viviera en el script, quien cargue un precio A MANO escribiria el
-- valor que ve en su broker -85100- y volveria a estar cien veces arriba. El
-- precio se guarda TAL COMO SE COTIZA, y el instrumento dice a cuantas unidades
-- corresponde.

alter table instrument
  add column if not exists quote_size numeric(38,18) not null default 1
  check (quote_size > 0);

comment on column instrument.quote_size is
  'A cuantas unidades corresponde el precio cotizado. 1 para acciones, CEDEARs y '
  'cripto; 100 para bonos y obligaciones negociables, que cotizan por cada 100 '
  'nominales. El valor de una posicion es saldo * precio / quote_size.';

-- Lo que ya existe: los bonos pasan a 100, el resto queda en 1.
update instrument set quote_size = 100 where kind = 'bond';

-- ---------------------------------------------------------------------------
-- Las dos vistas que multiplican por el precio tienen que dividir por la lamina.
-- Se recrean COMPLETAS desde su ultima version -20260916200000_portafolios.sql y
-- 20260916170000_cedears.sql-, no desde la primera: ya me equivoque una vez
-- recreando account_balance desde su definicion original y borre una columna.
-- ---------------------------------------------------------------------------

-- valor_portafolio cuelga de valor_cuenta, asi que cae y se vuelve a crear
-- IDENTICA, copiada de 20260916200000_portafolios.sql.
drop view if exists valor_portafolio;
drop view if exists valor_inversion;
drop view if exists valor_cuenta;

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
         coalesce(a.fx_source, pf.fx_source) as fx_source,
         i.symbol,
         i.kind          as kind,
         i.quote_currency,
         i.ratio,
         i.underlying_symbol,
         i.quote_size,
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

drop view if exists posicion;

create view posicion as
  select a.id           as account_id,
         a.ledger_id,
         a.name,
         a.institution,
         a.fx_source,
         i.id           as instrument_id,
         i.symbol,
         i.name         as instrument_name,
         i.kind,
         i.quote_currency,
         i.decimals,
         i.ratio,
         i.underlying_symbol,
         i.quote_size,
         coalesce(u.unidades, 0)                as unidades,
         p.price                                as precio,
         p.on_date                              as precio_al,
         p.source                               as precio_fuente,
         coalesce(u.unidades, 0) * p.price / coalesce(i.quote_size, 1) as valor,
         coalesce(f.invertido, 0)               as invertido,
         coalesce(u.unidades, 0) * p.price / coalesce(i.quote_size, 1)
           - coalesce(f.invertido, 0)           as ganancia
    from account a
    join instrument i on i.id = a.instrument_id
    left join lateral (
      select sum(e.amount) as unidades from entry e where e.account_id = a.id
    ) u on true
    left join lateral (
      select -sum(c.amount) as invertido
        from entry pe
        join entry c on c.transaction_id = pe.transaction_id
                    and c.account_id is not null
                    and c.account_id <> a.id
       where pe.account_id = a.id
    ) f on true
    left join lateral (
      select pr.price, pr.on_date, pr.source
        from price pr where pr.instrument_id = i.id
       order by pr.on_date desc limit 1
    ) p on true
   where a.valuation = 'market'
     and a.archived_at is null;

alter view posicion set (security_invoker = on);
grant select on posicion to authenticated;

-- ---------------------------------------------------------------------------
-- Al comprar, la lamina sale del tipo de instrumento.
-- ---------------------------------------------------------------------------

create or replace function lamina_de(p_kind text) returns numeric
language sql immutable
set search_path = public, pg_temp
as $$ select case when p_kind = 'bond' then 100 else 1 end $$;

grant execute on function lamina_de(text) to authenticated;

-- Un trigger y no un cambio en comprar_activo: esa funcion habria que copiarla
-- entera para no perderle nada, y ya me paso hoy de reescribir de memoria algo
-- que no habia leido. Ademas asi vale para cualquier alta de instrumento, venga
-- de donde venga.
--
-- Solo corrige el caso imposible -un bono con lamina 1 siempre esta mal-, asi que
-- un valor puesto a proposito sigue mandando.
create or replace function lamina_por_defecto() returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.quote_size = 1 and lamina_de(new.kind) <> 1 then
    new.quote_size := lamina_de(new.kind);
  end if;
  return new;
end $$;

create trigger instrument_lamina
  before insert on instrument
  for each row execute function lamina_por_defecto();

comment on function lamina_por_defecto() is
  'Un bono con lamina 1 siempre esta mal: cotiza por 100 nominales. Corrige solo '
  'ese caso, asi un valor explicito sigue ganando. OD-39.';
