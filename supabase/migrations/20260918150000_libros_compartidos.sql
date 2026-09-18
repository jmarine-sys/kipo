-- Compartir un libro, y el concepto que faltaba para que eso no rompa nada.
-- ADR-028 / OD-36.
--
-- EL PROBLEMA REAL, verificado antes de escribir una linea:
--
--   create function my_ledger() as $$ select * from my_ledgers() limit 1 $$;
--   create policy ... using (ledger_id in (select my_ledgers()))
--
-- El dia que alguien perteneciera a dos libros, SIN CAMBIAR NADA:
--   1. toda lectura mostraria los dos libros MEZCLADOS -la politica filtra por
--      "alguno de los tuyos", no por "el que estas mirando"-, y
--   2. toda escritura iria a uno arbitrario: `limit 1` sin `order by`.
--
-- Asi que lo que faltaba no era una pantalla de invitaciones: era el concepto de
-- LIBRO ACTIVO. Y vive en la base, no en el cliente, por la misma razon de
-- ADR-003: si cada consulta tuviera que acordarse de filtrar, alcanza con
-- olvidarse en una para volver a mezclar, y consultas nuevas se escriben siempre.

create table active_ledger (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  ledger_id uuid not null references ledger(id) on delete cascade,
  set_at    timestamptz not null default now()
);

alter table active_ledger enable row level security;
alter table active_ledger force row level security;

-- La politica NO puede llamar a my_ledger(): my_ledger() lee esta tabla.
create policy active_ledger_self on active_ledger for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select on active_ledger to authenticated;

-- ---------------------------------------------------------------------------
-- Cual es el libro que estoy mirando.
--
-- SECURITY DEFINER porque lo llaman las politicas de RLS de todas las tablas: si
-- fuera invoker, leer `active_ledger` disparia su propia politica y entraria en
-- recursion.
--
-- El respaldo tiene ORDER BY a proposito. El original decia `limit 1` a secas y
-- eso no es "el primero": es cualquiera, y podia cambiar entre dos consultas.
-- ---------------------------------------------------------------------------

create or replace function my_ledger() returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    -- el elegido, siempre que siga siendo mio
    (select a.ledger_id
       from active_ledger a
       join ledger_member m on m.ledger_id = a.ledger_id and m.user_id = a.user_id
      where a.user_id = auth.uid()),
    -- si no eligio ninguno, el primero al que entro. Determinista.
    (select m.ledger_id from ledger_member m
      where m.user_id = auth.uid()
      order by m.joined_at, m.ledger_id
      limit 1)
  )
$$;

grant execute on function my_ledger() to authenticated;

/** Que soy en el libro que estoy mirando: 'owner' o 'member'. */
create or replace function mi_rol() returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select m.role from ledger_member m
   where m.user_id = auth.uid() and m.ledger_id = my_ledger()
$$;

grant execute on function mi_rol() to authenticated;

-- ---------------------------------------------------------------------------
-- RLS: de "alguno de los tuyos" a "el que estas mirando".
--
-- Y la linea de los permisos, que decidio el usuario: un invitado carga y borra
-- MOVIMIENTOS, pero no toca la ESTRUCTURA. La linea esta donde duele el error —
-- un movimiento mal cargado se corrige, una cuenta borrada se lleva su historia.
-- ---------------------------------------------------------------------------

do $$
declare t text;
begin
  -- Datos del dia a dia: cualquier miembro.
  foreach t in array array['transaction','entry','budget','scheduled_event','price','fx_rate'] loop
    execute format('drop policy if exists %1$I_member_rw on %1$I', t);
    execute format($p$
      create policy %1$I_activo_rw on %1$I for all to authenticated
        using      (ledger_id = my_ledger())
        with check (ledger_id = my_ledger())
    $p$, t);
  end loop;

  -- Estructura: todos la ven, solo el duenio la cambia.
  foreach t in array array['account','category','instrument'] loop
    execute format('drop policy if exists %1$I_member_rw on %1$I', t);
    execute format($p$
      create policy %1$I_activo_ro on %1$I for select to authenticated
        using (ledger_id = my_ledger())
    $p$, t);
    execute format($p$
      create policy %1$I_activo_rw on %1$I for insert to authenticated
        with check (ledger_id = my_ledger() and mi_rol() = 'owner')
    $p$, t);
    execute format($p$
      create policy %1$I_activo_up on %1$I for update to authenticated
        using      (ledger_id = my_ledger() and mi_rol() = 'owner')
        with check (ledger_id = my_ledger() and mi_rol() = 'owner')
    $p$, t);
    execute format($p$
      create policy %1$I_activo_del on %1$I for delete to authenticated
        using (ledger_id = my_ledger() and mi_rol() = 'owner')
    $p$, t);
  end loop;
end $$;

-- El libro y sus miembros: se ven los propios, pero solo el duenio suma o saca.
drop policy if exists ledger_member_rw on ledger;
create policy ledger_activo on ledger for select to authenticated
  using (id in (select my_ledgers()));

drop policy if exists ledger_member_self on ledger_member;
create policy ledger_member_ver on ledger_member for select to authenticated
  using (ledger_id in (select my_ledgers()));
create policy ledger_member_admin on ledger_member for all to authenticated
  using      (ledger_id = my_ledger() and mi_rol() = 'owner')
  with check (ledger_id = my_ledger() and mi_rol() = 'owner');

-- ---------------------------------------------------------------------------
-- Invitaciones por codigo, no por correo.
--
-- Buscar a alguien por su correo exigiria una funcion que diga si ese correo
-- esta registrado, y eso es un enumerador de usuarios. Con un codigo no hace
-- falta saber nada del otro: se lo pasas por donde quieras.
--
-- La tabla NO tiene grants para `authenticated`: si se pudiera leer, se podrian
-- listar los codigos vigentes. Se toca solo por las dos funciones de abajo.
-- ---------------------------------------------------------------------------

create table ledger_invite (
  code       text primary key,
  ledger_id  uuid not null references ledger(id) on delete cascade,
  role       text not null default 'member' check (role in ('owner','member')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  used_by    uuid references auth.users(id),
  used_at    timestamptz
);

alter table ledger_invite enable row level security;
alter table ledger_invite force row level security;
-- Sin politicas ni grants: nadie llega por el Data API. A proposito (ADR-020).

create or replace function crear_invitacion(p_role text default 'member')
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_libro  uuid := my_ledger();
  v_codigo text;
begin
  if mi_rol() is distinct from 'owner' then
    raise exception 'Solo quien creo el libro puede invitar';
  end if;
  if p_role not in ('owner','member') then
    raise exception 'Rol invalido';
  end if;

  -- Ocho caracteres: suficiente con vencimiento y un solo uso, y corto como para
  -- dictarlo por telefono sin equivocarse.
  v_codigo := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into ledger_invite (code, ledger_id, role, created_by)
  values (v_codigo, v_libro, p_role, auth.uid());

  return v_codigo;
end $$;

grant execute on function crear_invitacion(text) to authenticated;

create or replace function aceptar_invitacion(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_inv ledger_invite%rowtype;
begin
  select * into v_inv from ledger_invite
   where code = upper(trim(p_code)) for update;

  -- El mismo mensaje para "no existe", "ya se uso" y "vencio": distinguirlos
  -- convertiria esto en un oraculo para adivinar codigos.
  if not found or v_inv.used_at is not null or v_inv.expires_at < now() then
    raise exception 'Ese codigo no sirve: puede estar vencido o ya usado';
  end if;

  if exists (select 1 from ledger_member
              where ledger_id = v_inv.ledger_id and user_id = auth.uid()) then
    raise exception 'Ya formas parte de ese libro';
  end if;

  insert into ledger_member (ledger_id, user_id, role)
  values (v_inv.ledger_id, auth.uid(), v_inv.role);

  update ledger_invite set used_by = auth.uid(), used_at = now() where code = v_inv.code;

  -- Entrar a un libro es querer verlo: se pasa a ser el activo.
  insert into active_ledger (user_id, ledger_id) values (auth.uid(), v_inv.ledger_id)
  on conflict (user_id) do update set ledger_id = excluded.ledger_id, set_at = now();

  return v_inv.ledger_id;
end $$;

grant execute on function aceptar_invitacion(text) to authenticated;

create or replace function cambiar_libro(p_ledger uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (select 1 from ledger_member
                  where ledger_id = p_ledger and user_id = auth.uid()) then
    raise exception 'Ese libro no es tuyo';
  end if;

  insert into active_ledger (user_id, ledger_id) values (auth.uid(), p_ledger)
  on conflict (user_id) do update set ledger_id = excluded.ledger_id, set_at = now();
end $$;

grant execute on function cambiar_libro(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Para el selector. Definer a proposito: ADR-020 le niega al cliente la tabla
-- `ledger`, y esta vista le da exactamente lo que necesita y nada mas.
-- ---------------------------------------------------------------------------

create view mi_libro
with (security_invoker = off) as
  select l.id                                   as ledger_id,
         l.name,
         m.role,
         (l.id = my_ledger())                   as activo,
         (select count(*) from ledger_member x where x.ledger_id = l.id) as miembros,
         m.joined_at
    from ledger l
    join ledger_member m on m.ledger_id = l.id
   where m.user_id = auth.uid();

grant select on mi_libro to authenticated;

comment on view mi_libro is
  'Los libros a los que pertenece quien pregunta, y cual esta mirando. Es lo '
  'unico que la interfaz sabe del libro: ADR-003 sigue valiendo.';
