-- Cuantas cuotas y cuando caen — OD-23.
--
-- LO QUE NO SE HACE, Y POR QUE. El registro decia que una cuota futura "entra
-- gratis en scheduled_event". No entra: un `scheduled_event` es algo que va a
-- pasar y que vas a REGISTRAR, y registrarlo crea un movimiento. Una cuota no es
-- eso. La compra en cuotas YA se registro entera el dia 1 contra la tarjeta
-- (ADR-004): la deuda esta completa desde el primer momento. Agendar las cuotas
-- como eventos contaria el gasto una vez por cuota.
--
-- Lo que falta no es agendar: es PROYECTAR. El saldo de la tarjeta dice cuanto
-- debes; lo que no dice es CUANDO, y con dos o tres compras en cuotas se vuelve
-- imposible anticipar el resumen del mes que viene.
--
-- Por eso alcanza con UN dato -en cuantas cuotas fue- y todo lo demas se deriva.
-- El mes de la primera cuota no se pregunta: una compra con tarjeta cae en el
-- resumen del mes siguiente. Preguntarlo seria friccion para precisar un dia que
-- el modelo igual no usa, porque la proyeccion es por MES.

alter table transaction
  add column if not exists installments int
  check (installments is null or installments between 2 and 60);

comment on column transaction.installments is
  'En cuantas cuotas se pago. null = de una. No cambia la contabilidad -la deuda '
  'ya esta entera desde el dia 1- solo permite proyectar cuando cae. OD-23.';

-- ---------------------------------------------------------------------------
-- Una fila por cuota: que tarjeta, que mes, cuanto.
--
-- Se expande con generate_series en vez de guardar N filas: son datos derivados
-- de dos columnas y guardarlos abriria la puerta a que discrepen del movimiento
-- que los origino.
-- ---------------------------------------------------------------------------

create view cuota as
  select t.id                     as transaction_id,
         t.ledger_id,
         t.description,
         t.occurred_on            as comprado_el,
         a.id                     as account_id,
         a.name                   as tarjeta,
         n                        as numero,
         t.installments           as total,
         -- La primera cuota cae en el resumen del mes SIGUIENTE a la compra.
         (date_trunc('month', t.occurred_on) + (n || ' month')::interval)::date as mes,
         round(abs(e.amount) / t.installments, 2) as monto,
         e.unit
    from transaction t
    join entry e on e.transaction_id = t.id
                and e.account_id is not null
    join account a on a.id = e.account_id
                  and a.kind = 'liability'
    cross join generate_series(1, t.installments) as n
   where t.installments is not null;

alter view cuota set (security_invoker = on);
grant select on cuota to authenticated;

-- ---------------------------------------------------------------------------
-- Lo que de verdad se queria: cuanto va a venir en cada resumen.
-- ---------------------------------------------------------------------------

create view resumen_tarjeta as
  select account_id,
         tarjeta,
         ledger_id,
         mes,
         unit,
         sum(monto)  as total,
         count(*)    as cuotas
    from cuota
   where mes >= date_trunc('month', current_date)
   group by account_id, tarjeta, ledger_id, mes, unit;

alter view resumen_tarjeta set (security_invoker = on);
grant select on resumen_tarjeta to authenticated;

comment on view resumen_tarjeta is
  'Lo que cae en cada resumen futuro por compras en cuotas. NO incluye los '
  'consumos de una sola cuota: esos ya estan en el saldo y se pagan enseguida.';



-- ---------------------------------------------------------------------------
-- El cliente necesita poder decirlo al registrar.
--
-- Es la MISMA funcion de 20260915110000_rpc.sql con un parametro mas: se copio
-- entera a proposito, porque reescribirla de memoria habria perdido la
-- validacion de las dos lineas y el comentario sobre la atomicidad diferida.
--
-- Y el `drop` explicito porque agregar un parametro con valor por defecto NO
-- reemplaza la funcion: crea una sobrecarga y las llamadas de cuatro argumentos
-- quedan ambiguas. Ya paso con comprar_activo.
-- ---------------------------------------------------------------------------

drop function if exists create_transaction(date, text, jsonb, text);

create or replace function create_transaction(
  p_occurred_on  date,
  p_kind         text,
  p_entries      jsonb,      -- [{account_id|category_id, amount, unit}, ...]
  p_description  text default null,
  p_installments int default null
) returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_ledger uuid := my_ledger();
  v_tx     uuid;
  v_n      int;
begin
  if v_ledger is null then
    raise exception 'El usuario no pertenece a ningun libro';
  end if;

  v_n := jsonb_array_length(p_entries);
  if v_n is null or v_n < 2 then
    raise exception 'Un movimiento necesita al menos dos lineas (recibio %)', coalesce(v_n, 0);
  end if;

  insert into transaction (ledger_id, occurred_on, description, kind, created_by, installments)
       values (v_ledger, p_occurred_on, nullif(trim(p_description), ''), p_kind, auth.uid(),
               p_installments)
    returning id into v_tx;

  insert into entry (transaction_id, ledger_id, account_id, category_id, amount, unit)
  select v_tx,
         v_ledger,
         nullif(e->>'account_id', '')::uuid,
         nullif(e->>'category_id', '')::uuid,
         (e->>'amount')::numeric,
         e->>'unit'
    from jsonb_array_elements(p_entries) e;

  -- Al salir de la funcion se confirma la transaccion de base y recien ahi dispara
  -- el trigger diferido de ADR-010. Si no balancea, no queda NADA: ni el movimiento
  -- ni las lineas. Esa es la atomicidad que se buscaba.
  return v_tx;
end $$;

grant execute on function create_transaction(date, text, jsonb, text, int) to authenticated;
