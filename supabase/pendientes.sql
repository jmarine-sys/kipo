-- GENERADO POR scripts/pendientes.sh — no editar a mano.
--
-- Migraciones desde 20260918210000, en orden. Pegar entero en el SQL Editor de
-- Supabase, en orden. Los ALTER llevan IF NOT EXISTS y los CREATE VIEW van
-- precedidos de DROP, asi que volver a correrlo no rompe nada; un INSERT de
-- datos semilla si podria duplicar, y por eso se avisa en vez de prometer.
--
--   20260918210000_archivar_libro.sql

-- ===========================================================================
-- 20260918210000_archivar_libro.sql
-- ===========================================================================

-- Archivar y borrar un libro, y la institucion en los movimientos.
--
-- Se podian crear libros y no sacarlos. Y la regla es la MISMA que ya rige para
-- cuentas y categorias, que es lo que la hace facil de explicar:
--
--   se BORRA lo que no tiene historia    -> no se pierde nada
--   se ARCHIVA lo que si la tiene        -> la historia no se toca
--
-- Un libro con movimientos no se borra ni pidiendo por favor: es exactamente lo
-- que ADR-018 vino a proteger.

alter table ledger add column if not exists archived_at timestamptz;

comment on column ledger.archived_at is
  'Un libro archivado deja de aparecer y deja de poder ser el activo, pero su '
  'historia queda entera.';

-- Los libros archivados dejan de contar como tuyos: ni para elegir, ni para RLS.
create or replace function my_ledgers() returns setof uuid
language sql stable security definer set search_path = public, pg_temp
as $$
  select m.ledger_id from ledger_member m
    join ledger l on l.id = m.ledger_id
   where m.user_id = auth.uid() and l.archived_at is null
$$;

create or replace function my_ledger() returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select a.ledger_id
       from active_ledger a
       join ledger_member m on m.ledger_id = a.ledger_id and m.user_id = a.user_id
       join ledger l on l.id = a.ledger_id and l.archived_at is null
      where a.user_id = auth.uid()),
    (select m.ledger_id from ledger_member m
       join ledger l on l.id = m.ledger_id and l.archived_at is null
      where m.user_id = auth.uid()
      order by m.joined_at, m.ledger_id
      limit 1)
  )
$$;

create or replace function archivar_libro(p_ledger uuid) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (select 1 from ledger_member
                  where ledger_id = p_ledger and user_id = auth.uid() and role = 'owner') then
    raise exception 'Solo quien creo el libro puede archivarlo';
  end if;

  -- Quedarse sin ningun libro deja la aplicacion sin nada que mostrar y sin
  -- forma de volver: no hay pantalla para crear el primero desde afuera.
  if (select count(*) from my_ledgers()) <= 1 then
    raise exception 'Es tu unico libro: no se puede archivar';
  end if;

  update ledger set archived_at = now() where id = p_ledger;

  -- Si era el que estabas mirando, hay que sacarte de ahi.
  delete from active_ledger where user_id = auth.uid() and ledger_id = p_ledger;
end $$;

grant execute on function archivar_libro(uuid) to authenticated;

create or replace function eliminar_libro(p_ledger uuid) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_movs int;
begin
  if not exists (select 1 from ledger_member
                  where ledger_id = p_ledger and user_id = auth.uid() and role = 'owner') then
    raise exception 'Solo quien creo el libro puede borrarlo';
  end if;
  if (select count(*) from my_ledgers()) <= 1 then
    raise exception 'Es tu unico libro: no se puede borrar';
  end if;

  select count(*) into v_movs from transaction where ledger_id = p_ledger;
  if v_movs > 0 then
    raise exception 'Ese libro tiene % movimientos: archivalo, no lo borres', v_movs;
  end if;

  delete from ledger where id = p_ledger;   -- todo lo demas cae por cascada
end $$;

grant execute on function eliminar_libro(uuid) to authenticated;

-- El selector solo muestra los vivos. `create or replace` no sirve cuando se
-- agrega una columna en el medio: hay que tirarla y rehacerla.
drop view if exists mi_libro;

create view mi_libro
with (security_invoker = off) as
  select l.id                                   as ledger_id,
         l.name,
         m.role,
         (l.id = my_ledger())                   as activo,
         (select count(*) from ledger_member x where x.ledger_id = l.id) as miembros,
         (select count(*) from transaction t where t.ledger_id = l.id)   as movimientos,
         m.joined_at
    from ledger l
    join ledger_member m on m.ledger_id = l.id
   where m.user_id = auth.uid()
     and l.archived_at is null;

grant select on mi_libro to authenticated;

-- ---------------------------------------------------------------------------
-- Y la institucion en la lista de movimientos: dos cuentas pueden llamarse
-- igual en bancos distintos, y ahi el nombre solo no alcanza para saber cual es.
-- ---------------------------------------------------------------------------

drop view if exists entry_detail;

create view entry_detail as
  select e.id,
         e.transaction_id,
         e.ledger_id,
         e.amount,
         e.unit,
         e.account_id,
         a.name        as account_name,
         a.kind        as account_kind,
         a.valuation   as account_valuation,
         a.institution as account_institution,
         e.category_id,
         c.name        as category_name,
         c.kind        as category_kind,
         c.is_system   as category_is_system,
         c.system_role as category_role,
         p.name        as category_parent,
         t.occurred_on,
         t.description,
         t.kind        as tx_kind,
         t.installments,
         t.created_at
    from entry e
    join transaction t on t.id = e.transaction_id
    left join account  a on a.id = e.account_id
    left join category c on c.id = e.category_id
    left join category p on p.id = c.parent_id;

alter view entry_detail set (security_invoker = on);
grant select on entry_detail to authenticated;

