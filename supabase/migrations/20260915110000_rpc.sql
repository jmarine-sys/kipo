-- kipo · escritura atomica de movimientos
--
-- Problema: registrar un movimiento significa insertar en 'transaction' y en 'entry'.
-- Desde el navegador eso son dos llamadas, y si la segunda falla queda un movimiento
-- huerfano. Ademas son dos viajes de red en un flujo que debe cerrarse en 10 segundos.
--
-- Esta funcion hace las dos cosas en UNA transaccion de base y UN viaje.

-- El libro del usuario. ADR-003 dice que el libro NO existe para la interfaz:
-- esta funcion es lo que lo hace cierto, porque el cliente nunca tiene que nombrarlo.
create or replace function my_ledger() returns uuid
language sql
stable
set search_path = public, pg_temp
as $$ select * from my_ledgers() limit 1 $$;

grant execute on function my_ledger() to authenticated;

-- Con esto el cliente jamas envia ledger_id: lo pone la base y RLS lo verifica.
-- El dia que ADR-002 cambie y haya libros compartidos, el cliente empezara a enviarlo
-- explicitamente y estos defaults se quitan.
alter table account         alter column ledger_id set default my_ledger();
alter table category        alter column ledger_id set default my_ledger();
alter table instrument      alter column ledger_id set default my_ledger();
alter table price           alter column ledger_id set default my_ledger();
alter table fx_rate         alter column ledger_id set default my_ledger();
alter table transaction     alter column ledger_id set default my_ledger();
alter table entry           alter column ledger_id set default my_ledger();
alter table budget          alter column ledger_id set default my_ledger();
alter table scheduled_event alter column ledger_id set default my_ledger();

-- SECURITY INVOKER (el default, explicito a proposito): la funcion corre con los
-- permisos de QUIEN LA LLAMA, asi que RLS sigue aplicando. Con SECURITY DEFINER
-- seria un agujero que saltearia todo el aislamiento de ADR-002.
create or replace function create_transaction(
  p_occurred_on date,
  p_kind        text,
  p_entries     jsonb,      -- [{account_id|category_id, amount, unit}, ...]
  p_description text default null
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

  insert into transaction (ledger_id, occurred_on, description, kind, created_by)
       values (v_ledger, p_occurred_on, nullif(trim(p_description), ''), p_kind, auth.uid())
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

grant execute on function create_transaction(date, text, jsonb, text) to authenticated;

comment on function create_transaction(date, text, jsonb, text) is
  'Registra un movimiento con sus lineas en una sola transaccion de base. '
  'SECURITY INVOKER: RLS sigue aplicando. Si las lineas no balancean segun ADR-010, '
  'se revierte todo.';
