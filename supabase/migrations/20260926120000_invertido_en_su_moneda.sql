-- Lo invertido, en la misma moneda en la que cotiza la posicion.  OD-58
--
-- La vista `posicion` sumaba las contrapartes de cada compra EN CRUDO y las
-- restaba de un valor expresado en la moneda de cotizacion. Mientras las dos
-- coincidan no se nota. El caso en que no coinciden es el mas comun que hay aca:
-- mandar pesos a Binance y comprar cripto.
--
--   1.500.000 ARS por 0,01 BTC, con el BTC a 100.000 USDT
--   -> invertido = 1500000, valor = 1000, ganancia = -1499000
--
-- con el precio SIN MOVERSE, y la pantalla lo rotulaba en USDT. Ninguna de las
-- 173 aserciones lo agarro porque todas compran con una cuenta en la misma
-- moneda en la que cotiza el activo.
--
-- `flujo_portafolio` ya convertia bien -con `convertir()` y la fecha de cada
-- movimiento-, asi que `posicion` era la unica que no lo hacia.
--
-- CON QUE COTIZACION. La del dia de CADA compra, no la de hoy. Con la de hoy, lo
-- que se mide es cuanto se movio el dolar desde entonces, que es exactamente lo
-- contrario de lo que esta pantalla quiere contestar (ADR-023, ADR-024).

-- ---------------------------------------------------------------------------
-- Convertir entre dos monedas cualesquiera, a la vara de una fecha.
--
-- `convertir()` solo sabe ir HACIA 'USD' o 'UVA', que es lo que necesitan las
-- vistas de medicion. Aca hace falta tambien el camino de vuelta: un CEDEAR
-- cotiza en pesos y se puede pagar con los dolares del broker.
--
-- El dolar y sus estables son la misma moneda a estos efectos, igual que en
-- `convertir()`: la diferencia son centesimas y el ruido que agregaria una
-- conversion mas -con su propia fuente, que se puede caer- es mayor.
-- ---------------------------------------------------------------------------

create or replace function convertir_a(
  p_monto  numeric,
  p_desde  text,
  p_hasta  text,
  p_fecha  date,
  p_fuente text default null   -- que dolar; null = el del libro
) returns numeric
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_dolares constant text[] := array['USD','USDT','USDC','DAI'];
  v_rate numeric;
begin
  if p_monto is null or p_desde is null or p_hasta is null then return null; end if;

  -- La misma moneda, o dos formas del dolar: no hay nada que convertir.
  if p_desde = p_hasta
     or (p_desde = any(v_dolares) and p_hasta = any(v_dolares)) then
    return p_monto;
  end if;

  -- Pesos hacia el dolar.
  if p_desde = 'ARS' and p_hasta = any(v_dolares) then
    return convertir(p_monto, 'ARS', p_fecha, 'USD', p_fuente);
  end if;

  -- Dolares hacia pesos.
  if p_desde = any(v_dolares) and p_hasta = 'ARS' then
    v_rate := cotizacion(p_fecha, coalesce(p_fuente, my_fx_source()));
    if v_rate is null or v_rate = 0 then return null; end if;
    return p_monto * v_rate;
  end if;

  -- Cualquier otro par -una unidad que no es moneda, como BTC o un CEDEAR- no
  -- se convierte aca: primero hay que valuarla con su precio. NULL, no cero:
  -- que la pantalla diga que no sabe es preferible a un numero inventado.
  return null;
end $$;

grant execute on function convertir_a(numeric, text, text, date, text) to authenticated;


-- ---------------------------------------------------------------------------
-- La vista, con lo invertido ya convertido.
--
-- Y SIN `coalesce(..., 0)`. Si falta la cotizacion de alguno de los dias en que
-- compraste, lo invertido no es cero: es desconocido. Con el coalesce anterior
-- una cotizacion faltante mostraba invertido = 0 y toda la posicion como
-- ganancia pura. `bool_or` propaga ese "no se" a la posicion entera, porque un
-- total al que le falta un pedazo no es un total.
-- ---------------------------------------------------------------------------

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
         f.invertido                            as invertido,
         coalesce(u.unidades, 0) * p.price / coalesce(i.quote_size, 1)
           - f.invertido                        as ganancia
    from account a
    join instrument i on i.id = a.instrument_id
    left join lateral (
      select sum(e.amount) as unidades from entry e where e.account_id = a.id
    ) u on true
    left join lateral (
      select case when bool_or(x.monto is null) then null else sum(x.monto) end as invertido
        from (
          select convertir_a(-c.amount, c.unit, i.quote_currency,
                             t.occurred_on, a.fx_source) as monto
            from entry pe
            join transaction t on t.id = pe.transaction_id
            join entry c on c.transaction_id = pe.transaction_id
                        and c.account_id is not null
                        and c.account_id <> a.id
           where pe.account_id = a.id
        ) x
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
