-- Varios libros, y plata que pasa de uno a otro — ADR-032 / OD-41.
--
-- Dos cosas que hoy no se pueden, y solo una era facil.
--
-- 1. NO SE PUEDE CREAR UN LIBRO. El unico lugar donde nace uno es el trigger de
--    alta, asi que sos duenio de exactamente uno. Para una cuenta compartida con
--    una pareja hacen falta TRES: el de cada uno mas el comun.
--
-- 2. UN MOVIMIENTO NO PUEDE CRUZAR LIBROS, y eso no se toca. La restriccion
--    `entry_account_same_ledger` obliga a que toda linea viva en el mismo libro
--    que su movimiento, y es lo que hace que cada libro cierre en cero POR SI
--    SOLO. Si una pata viviera afuera, ningun libro cerraria solo y la partida
--    doble dejaria de servir como control.
--
--    Se resuelve con DOS movimientos encadenados, uno en cada libro, con la misma
--    referencia. Y con una respuesta que dio el usuario: aportar al libro comun
--    ES GASTAR. Esa plata ya no la podes usar sola, asi que tu patrimonio baja.
--    La alternativa -que siguiera siendo tuya- exigiria modelar QUE PARTE del
--    fondo comun te pertenece, y eso cambia cada vez que alguien aporta o gasta.

-- ---------------------------------------------------------------------------
-- Primero, arreglar como se identifica una categoria de sistema.
--
-- Se buscaban por `is_system` MAS el tipo: "la de sistema de gasto" era la de
-- ajustes y "la de ingreso" la de intereses. Eso alcanzaba con dos y se rompe con
-- cuatro: agregar los aportes haria que el ajuste de saldo se confundiera con
-- ellos, y el resumen del mes contaria los aportes como ajustes.
--
-- `is_system` decia que no se puede borrar; nunca dijo PARA QUE es.
-- ---------------------------------------------------------------------------

alter table category add column system_role text
  check (system_role in ('ajuste', 'interes', 'aporte_enviado', 'aporte_recibido'));

create unique index category_system_role_idx
  on category (ledger_id, system_role) where system_role is not null;

comment on column category.system_role is
  'Para que sirve una categoria de sistema. Antes se deducia de is_system + kind, '
  'que alcanzaba con dos roles y se rompe con cuatro.';

update category set system_role = 'ajuste'  where is_system and kind = 'expense';
update category set system_role = 'interes' where is_system and kind = 'income';

create or replace function sembrar_libro(p_ledger uuid) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into category (ledger_id, name, kind, is_system, sort_order, system_role) values
    (p_ledger, 'Sueldo',           'income',  false, 10, null),
    (p_ledger, 'Intereses',        'income',  true,  20, 'interes'),   -- ADR-013, ADR-014
    (p_ledger, 'Otros ingresos',   'income',  false, 30, null),
    (p_ledger, 'Gastos fijos',     'expense', false, 10, null),
    (p_ledger, 'Gastos variables', 'expense', false, 20, null),
    (p_ledger, 'Ajuste de saldo',  'expense', true,  90, 'ajuste');    -- ADR-005
end $$;

drop view if exists entry_detail;

create view entry_detail as
  select e.id,
         e.transaction_id,
         e.ledger_id,
         e.amount,
         e.unit,
         e.account_id,
         a.name       as account_name,
         a.kind       as account_kind,
         a.valuation  as account_valuation,
         e.category_id,
         c.name       as category_name,
         c.kind       as category_kind,
         c.is_system  as category_is_system,
         c.system_role as category_role,
         p.name       as category_parent,
         t.occurred_on,
         t.description,
         t.kind       as tx_kind,
         t.installments,
         t.created_at
    from entry e
    join transaction t on t.id = e.transaction_id
    left join account  a on a.id = e.account_id
    left join category c on c.id = e.category_id
    left join category p on p.id = c.parent_id;

alter view entry_detail set (security_invoker = on);
grant select on entry_detail to authenticated;

-- ---------------------------------------------------------------------------
-- Crear un libro.
-- ---------------------------------------------------------------------------

create or replace function crear_libro(p_nombre text) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_libro  uuid;
  v_nombre text := nullif(trim(p_nombre), '');
begin
  if v_nombre is null then raise exception 'El libro necesita un nombre'; end if;
  if auth.uid() is null then raise exception 'Hace falta estar identificado'; end if;

  insert into ledger (name) values (v_nombre) returning id into v_libro;
  insert into ledger_member (ledger_id, user_id, role) values (v_libro, auth.uid(), 'owner');
  perform sembrar_libro(v_libro);

  -- Crear un libro es querer usarlo. Si no, quedaria creado e invisible.
  insert into active_ledger (user_id, ledger_id) values (auth.uid(), v_libro)
  on conflict (user_id) do update set ledger_id = excluded.ledger_id, set_at = now();

  return v_libro;
end $$;

grant execute on function crear_libro(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Pasar plata a otro libro.
--
-- Dos movimientos, uno en cada libro, con la misma referencia para poder verlos
-- como lo que son: las dos mitades de una misma cosa.
-- ---------------------------------------------------------------------------

alter table transaction add column cross_ref uuid;

create index transaction_cross_ref_idx on transaction (cross_ref) where cross_ref is not null;

comment on column transaction.cross_ref is
  'Une las dos mitades de un aporte entre libros. No es una clave foranea: las '
  'dos mitades viven en libros distintos a proposito. ADR-032.';

/** La categoria de sistema de un rol, creandola la primera vez que hace falta. */
create or replace function categoria_de_rol(p_ledger uuid, p_rol text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cat uuid;
begin
  select id into v_cat from category where ledger_id = p_ledger and system_role = p_rol;
  if v_cat is not null then return v_cat; end if;

  -- Se crean reci­en cuando se usan: quien nunca comparta un libro no tiene por
  -- que ver estas categorias en su lista.
  insert into category (ledger_id, name, kind, is_system, sort_order, system_role)
  values (p_ledger,
          case p_rol when 'aporte_enviado' then 'Aporte a otro libro'
                     else 'Aporte recibido' end,
          case p_rol when 'aporte_enviado' then 'expense' else 'income' end,
          true, 95, p_rol)
  returning id into v_cat;

  return v_cat;
end $$;

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
       values (v_origen, v_fecha, coalesce(nullif(trim(p_detalle), ''), 'Aporte a otro libro'),
               'expense', auth.uid(), v_ref)
    returning id into v_tx;
  insert into entry (transaction_id, ledger_id, account_id, category_id, amount, unit) values
    (v_tx, v_origen, p_cuenta_origen, null, -p_monto, v_unidad),
    (v_tx, v_origen, null, v_cat,        p_monto, v_unidad);

  -- En el OTRO libro: entra plata y es un ingreso.
  v_cat := categoria_de_rol(p_destino, 'aporte_recibido');
  insert into transaction (ledger_id, occurred_on, description, kind, created_by, cross_ref)
       values (p_destino, v_fecha, coalesce(nullif(trim(p_detalle), ''), 'Aporte recibido'),
               'income', auth.uid(), v_ref)
    returning id into v_tx;
  insert into entry (transaction_id, ledger_id, account_id, category_id, amount, unit) values
    (v_tx, p_destino, p_cuenta_destino, null,  p_monto, v_unidad),
    (v_tx, p_destino, null,             v_cat, -p_monto, v_unidad);

  return v_ref;
end $$;

grant execute on function aportar_a_libro(uuid, uuid, uuid, numeric, date, text) to authenticated;

comment on function aportar_a_libro(uuid, uuid, uuid, numeric, date, text) is
  'Dos movimientos encadenados, uno por libro. No es una transferencia: aportar '
  'al libro comun es GASTAR, porque esa plata ya no la podes usar sola. ADR-032.';

-- ---------------------------------------------------------------------------
-- Para elegir la cuenta de destino hay que ver las cuentas del OTRO libro, y RLS
-- lo impide: la politica es `ledger_id = my_ledger()`, y esta bien que lo sea.
--
-- Esta funcion es la excepcion minima: devuelve nombre, moneda y nada mas, solo
-- de libros a los que el que pregunta pertenece. No abre la puerta a los
-- movimientos ni a los saldos del otro libro.
-- ---------------------------------------------------------------------------

create or replace function cuentas_de_libro(p_ledger uuid)
returns table (id uuid, name text, unit text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select a.id, a.name, a.unit
    from account a
   where a.ledger_id = p_ledger
     and a.archived_at is null
     and a.valuation = 'balance'
     and exists (select 1 from ledger_member m
                  where m.ledger_id = p_ledger and m.user_id = auth.uid())
   order by a.name
$$;

grant execute on function cuentas_de_libro(uuid) to authenticated;
