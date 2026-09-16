-- Convertir a la moneda de medicion — ADR-009 y ADR-011.
--
-- Sin esto nada se puede expresar en dolares salvo lo que ya esta en dolares, y
-- la pregunta central del proyecto -"¿mis inversiones rinden 10% anual en
-- dolares?"- no tiene respuesta.

-- ---------------------------------------------------------------------------
-- La cotizacion vigente para una fecha.
--
-- Usa la ULTIMA anterior o igual, no la mas cercana: un sabado no cotiza, y el
-- valor que regia ese dia es el del viernes, no el del lunes siguiente. Tomar el
-- lunes seria usar informacion que en ese momento no existia.
-- ---------------------------------------------------------------------------

create or replace function cotizacion(
  p_fecha  date,
  p_fuente text,
  p_base   text default 'USD',
  p_quote  text default 'ARS'
) returns numeric
language sql
stable
set search_path = public, pg_temp
as $$
  select rate from fx_rate
   where ledger_id = my_ledger()
     and base = p_base and quote = p_quote and source = p_fuente
     and on_date <= p_fecha
   order by on_date desc
   limit 1
$$;

grant execute on function cotizacion(date, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Cuanto vale en dolares un monto, a la cotizacion de su fecha.
--
-- Devuelve NULL si falta la cotizacion. A proposito: es preferible que la
-- pantalla diga "no se" a que muestre un numero calculado con una cotizacion
-- inventada. Brief §20, transparencia.
-- ---------------------------------------------------------------------------

create or replace function en_usd(
  p_monto  numeric,
  p_unidad text,
  p_fecha  date,
  p_fuente text default null
) returns numeric
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_fuente text;
  v_rate   numeric;
begin
  if p_monto is null then return null; end if;

  -- USD, USDT y las stablecoins se toman como dolar. Es una aproximacion
  -- deliberada: un USDT puede despegarse unas centesimas, y esa diferencia es
  -- ruido frente a lo que se esta midiendo.
  if p_unidad in ('USD', 'USDT', 'USDC', 'DAI') then
    return p_monto;
  end if;

  if p_unidad <> 'ARS' then
    -- una unidad que no es moneda -BTC, un CEDEAR- no se convierte aca: primero
    -- hay que valuarla con su precio
    return null;
  end if;

  v_fuente := coalesce(p_fuente, (select default_fx_source from ledger where id = my_ledger()));
  v_rate := cotizacion(p_fecha, v_fuente);
  if v_rate is null or v_rate = 0 then return null; end if;
  return p_monto / v_rate;
end $$;

grant execute on function en_usd(numeric, text, date, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Que cotizaciones faltan para poder medir.
--
-- La pantalla necesita poder decir "no puedo calcularlo y esto es lo que falta",
-- no simplemente mostrar un hueco.
-- ---------------------------------------------------------------------------

create view cotizacion_faltante as
  with fechas as (
    -- cada fecha en que se movio plata en una cuenta de inversion
    select distinct t.occurred_on as fecha, e2.unit as unidad
      from entry e
      join account a on a.id = e.account_id
      join entry e2 on e2.transaction_id = e.transaction_id and e2.id <> e.id
      join transaction t on t.id = e.transaction_id
     where a.valuation in ('market', 'accrual')
       and e2.unit = 'ARS'
    union
    select current_date, 'ARS'
  )
  select f.fecha, f.unidad
    from fechas f
   where cotizacion(f.fecha, (select default_fx_source from ledger where id = my_ledger())) is null;

alter view cotizacion_faltante set (security_invoker = on);
grant select on cotizacion_faltante to authenticated;

comment on view cotizacion_faltante is
  'Fechas en que hubo movimientos de inversion en pesos y no hay cotizacion '
  'cargada. Sin ellas no se puede medir el rendimiento en dolares.';
