-- Posiciones: la familia 'market' de ADR-012 — unidades x precio.
--
-- Comprar un activo NO es un caso nuevo: es un intercambio de dos unidades, igual
-- que comprar dolares (ADR-010). Sale plata, entran unidades, y el precio unitario
-- es el cociente. Por eso no hace falta ningun asiento especial.
--
-- Lo nuevo es la VALUACION: para saber cuanto vale hoy hace falta un precio, y ese
-- si viene de afuera.

-- ---------------------------------------------------------------------------
-- Comprar. Crea el instrumento y la posicion si es la primera vez, asi el usuario
-- no tiene que darlos de alta por separado antes de poder comprar.
-- ---------------------------------------------------------------------------

create or replace function comprar_activo(
  p_symbol   text,
  p_nombre   text,
  p_kind     text,
  p_moneda   text,      -- en que se cotiza
  p_decimals int,
  p_desde    uuid,      -- de que cuenta sale la plata
  p_monto    numeric,   -- cuanto se pago
  p_unidades numeric,   -- cuantas unidades entraron
  p_broker   text default null,
  p_on       date default null
) returns uuid           -- la cuenta de la posicion
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
begin
  if p_monto is null or p_monto <= 0 then raise exception 'El monto tiene que ser mayor que cero'; end if;
  if p_unidades is null or p_unidades <= 0 then raise exception 'Las unidades tienen que ser mayores que cero'; end if;

  select * into v_origen from account where id = p_desde;
  if not found then raise exception 'No existe la cuenta de origen'; end if;

  -- el instrumento, si no estaba
  select id into v_inst from instrument
   where ledger_id = v_ledger and symbol = upper(trim(p_symbol));
  if v_inst is null then
    insert into instrument (ledger_id, symbol, name, kind, quote_currency, decimals)
         values (v_ledger, upper(trim(p_symbol)), p_nombre, p_kind, p_moneda, p_decimals)
      returning id into v_inst;
  end if;

  -- la posicion, si no estaba. Es una CUENTA cuya unidad es el activo: tener 0,05
  -- BTC es lo mismo que tener 1000 USD, solo cambia la unidad.
  select id into v_pos from account
   where ledger_id = v_ledger and instrument_id = v_inst and archived_at is null;
  if v_pos is null then
    insert into account (ledger_id, name, kind, valuation, unit, instrument_id,
                         is_spendable, institution)
         values (v_ledger,
                 coalesce(p_broker || ' · ', '') || upper(trim(p_symbol)),
                 'asset', 'market', upper(trim(p_symbol)), v_inst,
                 false, coalesce(p_broker, v_origen.institution))
      returning id into v_pos;
  end if;

  insert into transaction (ledger_id, occurred_on, description, kind, created_by)
       values (v_ledger, v_fecha,
               'Compra de ' || upper(trim(p_symbol)), 'trade', auth.uid())
    returning id into v_tx;

  -- dos unidades distintas: el precio unitario es el cociente (ADR-010)
  insert into entry (transaction_id, ledger_id, account_id, amount, unit) values
    (v_tx, v_ledger, p_desde, -p_monto,    v_origen.unit),
    (v_tx, v_ledger, v_pos,    p_unidades, upper(trim(p_symbol)));

  return v_pos;
end $$;

grant execute on function comprar_activo(text, text, text, text, int, uuid, numeric, numeric, text, date) to authenticated;

-- ---------------------------------------------------------------------------
-- Vender. El patrimonio NO cambia: cambia de forma.
-- La ganancia ya estaba reconocida mientras el precio subia; vender solo la pasa
-- de no realizada a realizada. Por eso ninguna categoria de ingreso participa.
-- ---------------------------------------------------------------------------

create or replace function vender_activo(
  p_pos      uuid,
  p_unidades numeric,
  p_hacia    uuid,
  p_monto    numeric,
  p_on       date default null
) returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_pos     account%rowtype;
  v_destino account%rowtype;
  v_tengo   numeric;
  v_tx      uuid;
begin
  select * into v_pos from account where id = p_pos and valuation = 'market';
  if not found then raise exception 'No existe esa posicion'; end if;
  select * into v_destino from account where id = p_hacia;
  if not found then raise exception 'No existe la cuenta de destino'; end if;
  if p_unidades is null or p_unidades <= 0 then raise exception 'Las unidades tienen que ser mayores que cero'; end if;
  if p_monto is null or p_monto <= 0 then raise exception 'El monto tiene que ser mayor que cero'; end if;

  select coalesce(sum(amount), 0) into v_tengo from entry where account_id = p_pos;
  if p_unidades > v_tengo then
    raise exception 'No tenes tantas unidades: hay % y queres vender %', v_tengo, p_unidades;
  end if;

  insert into transaction (ledger_id, occurred_on, description, kind, created_by)
       values (v_pos.ledger_id, coalesce(p_on, current_date),
               'Venta de ' || v_pos.unit, 'trade', auth.uid())
    returning id into v_tx;

  insert into entry (transaction_id, ledger_id, account_id, amount, unit) values
    (v_tx, v_pos.ledger_id, p_pos,   -p_unidades, v_pos.unit),
    (v_tx, v_pos.ledger_id, p_hacia,  p_monto,    v_destino.unit);

  -- Si se vendio todo, la posicion cumplio su ciclo. Se archiva, no se borra:
  -- sus movimientos siguen explicando que paso.
  if v_tengo - p_unidades = 0 then
    update account set archived_at = now() where id = p_pos;
  end if;

  return v_tx;
end $$;

grant execute on function vender_activo(uuid, numeric, uuid, numeric, date) to authenticated;

-- ---------------------------------------------------------------------------
-- Cuanto vale y cuanto gane.
--
-- La ganancia se calcula sin necesidad de FIFO ni promedio ponderado:
--
--     invertido = plata que salio  -  plata que volvio
--     ganancia  = valor actual     -  invertido
--
-- Eso es correcto incluso con ventas parciales, y es exactamente la "ganancia
-- absoluta" que pide el brief §13: la unica metrica que se explica sola. El
-- metodo de costo (OD-20) recien hace falta para separar realizada de no
-- realizada, que es otra pregunta.
-- ---------------------------------------------------------------------------

create view posicion as
  select a.id           as account_id,
         a.ledger_id,
         a.name,
         a.institution,
         i.id           as instrument_id,
         i.symbol,
         i.name         as instrument_name,
         i.kind,
         i.quote_currency,
         i.decimals,
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
      -- la otra pata de cada operacion: lo que salio menos lo que volvio
      select -sum(c.amount) as invertido
        from entry pe
        join entry c on c.transaction_id = pe.transaction_id
                    and c.account_id is not null
                    and c.account_id <> a.id
       where pe.account_id = a.id
    ) f on true
    left join lateral (
      select pr.price, pr.on_date, pr.source
        from price pr
       where pr.instrument_id = i.id
       order by pr.on_date desc
       limit 1
    ) p on true
   where a.valuation = 'market'
     and a.archived_at is null;

alter view posicion set (security_invoker = on);
grant select on posicion to authenticated;

comment on view posicion is
  'Posiciones vivas con su valuacion al ultimo precio cargado. Si nunca se cargo '
  'un precio, valor y ganancia quedan nulos: la app tiene que decir que no sabe, '
  'no mostrar cero.';
