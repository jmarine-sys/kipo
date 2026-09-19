-- Un aporte entre libros dice A QUE libro fue, y DE cual vino.
--
-- La descripcion por defecto era "Aporte a otro libro" y "Aporte recibido", que
-- en la lista de movimientos no dice nada: con dos libros compartidos no se
-- sabe cual. El dato existe -las dos mitades se crean juntas y cada una conoce
-- el nombre del otro libro- y no se estaba usando.
--
-- Va en la DESCRIPCION y no en una columna nueva: la otra mitad vive en otro
-- libro y RLS no la deja leer, asi que una columna con el id obligaria a una
-- funcion SECURITY DEFINER para resolver el nombre. Guardarlo cuando se crea es
-- mas barato y sobrevive aunque despues te saquen de ese libro.
--
-- Solo es el valor POR DEFECTO: si escribis un detalle, manda el tuyo.

create or replace function aportar_a_libro(
  p_destino        uuid,
  p_cuenta_origen  uuid,
  p_cuenta_destino uuid,
  p_monto          numeric,
  p_on             date default null,
  p_detalle        text default null
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_origen  uuid := my_ledger();
  v_ref     uuid := gen_random_uuid();
  v_fecha   date := coalesce(p_on, current_date);
  v_unidad  text;
  v_tx      uuid;
  v_cat     uuid;
  v_detalle text := nullif(trim(p_detalle), '');
  v_alla    text;
  v_aca     text;
begin
  if p_monto is null or p_monto <= 0 then
    raise exception 'El aporte tiene que ser mayor que cero';
  end if;
  if v_origen = p_destino then
    raise exception 'Ese es el mismo libro: usa una transferencia comun';
  end if;

  -- Tiene que ser miembro de LOS DOS. Es SECURITY DEFINER, asi que RLS no lo
  -- comprueba por nosotros: se comprueba aca, explicito.
  if not exists (select 1 from ledger_member where ledger_id = v_origen   and user_id = auth.uid())
  or not exists (select 1 from ledger_member where ledger_id = p_destino and user_id = auth.uid()) then
    raise exception 'Solo podes mover plata entre libros que sean tuyos';
  end if;

  select name into v_alla from ledger where id = p_destino;
  select name into v_aca  from ledger where id = v_origen;

  select unit into v_unidad from account
   where id = p_cuenta_origen and ledger_id = v_origen;
  if v_unidad is null then raise exception 'Esa cuenta de origen no es de tu libro'; end if;

  if not exists (select 1 from account
                  where id = p_cuenta_destino and ledger_id = p_destino and unit = v_unidad) then
    raise exception 'La cuenta de destino no existe en ese libro, o esta en otra moneda';
  end if;

  -- En TU libro: sale plata y es un GASTO. Esa plata ya no la podes usar sola.
  v_cat := categoria_de_rol(v_origen, 'aporte_enviado');
  insert into transaction (ledger_id, occurred_on, description, kind, created_by, cross_ref)
       values (v_origen, v_fecha, coalesce(v_detalle, 'Aporte a ' || v_alla),
               'expense', auth.uid(), v_ref)
    returning id into v_tx;
  insert into entry (transaction_id, ledger_id, account_id, category_id, amount, unit) values
    (v_tx, v_origen, p_cuenta_origen, null, -p_monto, v_unidad),
    (v_tx, v_origen, null, v_cat,        p_monto, v_unidad);

  -- En el OTRO libro: entra plata y es un ingreso.
  v_cat := categoria_de_rol(p_destino, 'aporte_recibido');
  insert into transaction (ledger_id, occurred_on, description, kind, created_by, cross_ref)
       values (p_destino, v_fecha, coalesce(v_detalle, 'Aporte de ' || v_aca),
               'income', auth.uid(), v_ref)
    returning id into v_tx;
  insert into entry (transaction_id, ledger_id, account_id, category_id, amount, unit) values
    (v_tx, p_destino, p_cuenta_destino, null,  p_monto, v_unidad),
    (v_tx, p_destino, null,             v_cat, -p_monto, v_unidad);

  return v_ref;
end $$;
