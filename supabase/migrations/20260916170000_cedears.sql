-- CEDEARs: separar el rendimiento del activo del movimiento del dolar.  OD-17.
--
-- EL PROBLEMA. Un CEDEAR cotiza en pesos y su precio ya lleva el CCL adentro:
--
--     precio_cedear_ARS = (precio_accion_USD / ratio) x CCL
--
-- Asi que sube por dos motivos que el precio mezcla: porque subio la accion en
-- dolares, o porque subio el CCL. Valuarlo en pesos y convertir al MEP -o a
-- cualquier otro dolar- arrastra esa mezcla.
--
-- LA SOLUCION. Convertir al CCL. El CCL se cancela y queda:
--
--     valor_USD = precio_cedear_ARS x unidades / CCL
--               = (precio_accion_USD / ratio) x unidades
--
-- o sea el valor en dolares de la accion subyacente. Sin necesitar el ratio ni
-- traer el precio del exterior: alcanza con usar la vara correcta.
--
-- Convertir al MEP responde otra pregunta, tambien legitima: "cuantos dolares
-- saco si vendo y extraigo por MEP". Por eso la fuente es una propiedad de la
-- CUENTA (ADR-011) y no una constante del sistema.
--
-- Lo que faltaba era que las vistas de medicion la respetaran: la declaraban y
-- no la usaban.

-- ---------------------------------------------------------------------------
-- Los flujos, con la vara de su cuenta
-- ---------------------------------------------------------------------------

drop view if exists flujo_inversion;

create view flujo_inversion as
  select a.id                                   as account_id,
         a.valuation,
         t.occurred_on                          as fecha,
         c.amount                               as monto,
         c.unit                                 as unidad,
         -- a.fx_source, no el del libro: un CEDEAR se mide al CCL aunque el
         -- resto de la aplicacion use MEP
         convertir(c.amount, c.unit, t.occurred_on, 'USD', a.fx_source) as usd,
         convertir(c.amount, c.unit, t.occurred_on, 'UVA', a.fx_source) as uva
    from entry pe
    join account a on a.id = pe.account_id
                  and a.valuation in ('market', 'accrual')
    join transaction t on t.id = pe.transaction_id
    join entry c on c.transaction_id = pe.transaction_id
                and c.account_id is not null
                and c.account_id <> a.id;

alter view flujo_inversion set (security_invoker = on);
grant select on flujo_inversion to authenticated;

-- ---------------------------------------------------------------------------
-- La valuacion, con la misma vara.
-- Tiene que ser LA MISMA que la de los flujos: medir lo que pusiste con un dolar
-- y lo que vale con otro daria un rendimiento inventado.
-- ---------------------------------------------------------------------------

drop view if exists valor_inversion;

create view valor_inversion as
  select a.id            as account_id,
         a.name,
         a.valuation,
         a.institution,
         a.matures_on,
         (a.archived_at is not null) as cerrada,
         a.fx_source,
         i.symbol,
         i.kind,
         i.quote_currency,
         i.ratio,
         i.underlying_symbol,
         coalesce(sal.saldo, 0) as saldo,
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
      select p.price, p.on_date from price p
       where p.instrument_id = a.instrument_id
       order by p.on_date desc limit 1
    ) pr on true
    left join lateral (
      select case
               when coalesce(sal.saldo, 0) = 0 then 0
               when a.valuation = 'market'     then sal.saldo * pr.price
               else sal.saldo
             end as valor_nativo
    ) v on true
   where a.valuation in ('market', 'accrual');

alter view valor_inversion set (security_invoker = on);
grant select on valor_inversion to authenticated;

-- ---------------------------------------------------------------------------
-- Al comprar un CEDEAR, la cuenta nace midiendose al CCL.
-- Es lo correcto por defecto y se puede cambiar despues: es una propiedad de la
-- cuenta, no una regla del sistema.
-- ---------------------------------------------------------------------------

-- OJO: agregar un parametro -aunque tenga valor por defecto- NO reemplaza la
-- funcion, crea una SOBRECARGA. Las dos quedan vivas y toda llamada con la
-- cantidad vieja de argumentos se vuelve ambigua. Hay que borrar la anterior.
drop function if exists comprar_activo(text, text, text, text, int, uuid, numeric, numeric, text, date);

create or replace function comprar_activo(
  p_symbol   text,
  p_nombre   text,
  p_kind     text,
  p_moneda   text,
  p_decimals int,
  p_desde    uuid,
  p_monto    numeric,
  p_unidades numeric,
  p_broker   text default null,
  p_on       date default null,
  p_ratio    numeric default null,   -- cuantos CEDEARs equivalen a una accion
  p_subyacente text default null     -- el simbolo de esa accion
) returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_ledger uuid := my_ledger();
  v_origen account%rowtype;
  v_inst   uuid;
  v_pos    uuid;
  v_tx     uuid;
  v_fecha  date := coalesce(p_on, current_date);
  v_fuente text;
begin
  if p_monto is null or p_monto <= 0 then raise exception 'El monto tiene que ser mayor que cero'; end if;
  if p_unidades is null or p_unidades <= 0 then raise exception 'Las unidades tienen que ser mayores que cero'; end if;

  select * into v_origen from account where id = p_desde;
  if not found then raise exception 'No existe la cuenta de origen'; end if;

  select id into v_inst from instrument
   where ledger_id = v_ledger and symbol = upper(trim(p_symbol));
  if v_inst is null then
    insert into instrument (ledger_id, symbol, name, kind, quote_currency, decimals,
                            ratio, underlying_symbol)
         values (v_ledger, upper(trim(p_symbol)), p_nombre, p_kind, p_moneda, p_decimals,
                 p_ratio, nullif(upper(trim(coalesce(p_subyacente,''))), ''))
      returning id into v_inst;
  end if;

  -- Un CEDEAR lleva el CCL adentro de su precio: medirlo con ese mismo dolar es
  -- lo que aisla el rendimiento de la accion del movimiento del tipo de cambio.
  v_fuente := case when p_kind = 'cedear' then 'ccl' else null end;

  select id into v_pos from account
   where ledger_id = v_ledger and instrument_id = v_inst and archived_at is null;
  if v_pos is null then
    insert into account (ledger_id, name, kind, valuation, unit, instrument_id,
                         is_spendable, institution, fx_source)
         values (v_ledger,
                 coalesce(p_broker || ' · ', '') || upper(trim(p_symbol)),
                 'asset', 'market', upper(trim(p_symbol)), v_inst,
                 false, coalesce(p_broker, v_origen.institution), v_fuente)
      returning id into v_pos;
  end if;

  insert into transaction (ledger_id, occurred_on, description, kind, created_by)
       values (v_ledger, v_fecha, 'Compra de ' || upper(trim(p_symbol)), 'trade', auth.uid())
    returning id into v_tx;

  insert into entry (transaction_id, ledger_id, account_id, amount, unit) values
    (v_tx, v_ledger, p_desde, -p_monto,    v_origen.unit),
    (v_tx, v_ledger, v_pos,    p_unidades, upper(trim(p_symbol)));

  return v_pos;
end $$;

grant execute on function comprar_activo(text, text, text, text, int, uuid, numeric, numeric, text, date, numeric, text) to authenticated;


-- La lista de posiciones tambien dice con que dolar se mide cada una: sin eso la
-- pantalla no puede cumplir ADR-011, que exige decir con que vara se midio.
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
         coalesce(u.unidades, 0)                as unidades,
         p.price                                as precio,
         p.on_date                              as precio_al,
         p.source                               as precio_fuente,
         coalesce(u.unidades, 0) * p.price      as valor,
         coalesce(f.invertido, 0)               as invertido,
         coalesce(u.unidades, 0) * p.price - coalesce(f.invertido, 0) as ganancia
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
