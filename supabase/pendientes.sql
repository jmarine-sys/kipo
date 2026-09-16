-- Expone si la categoria es de sistema, para poder mostrar los AJUSTES separados
-- de los gastos reales en el resumen del mes.
--
-- Un ajuste (ADR-005) resta del resultado igual que un gasto —esa plata se fue de
-- verdad, aunque no sepamos en que— pero mezclarlo con "Gastos" miente sobre en que
-- gastaste. Se muestra en su propia linea.

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
         p.name       as category_parent,
         t.occurred_on,
         t.description,
         t.kind       as tx_kind,
         t.created_at
    from entry e
    join transaction t on t.id = e.transaction_id
    left join account  a on a.id = e.account_id
    left join category c on c.id = e.category_id
    left join category p on p.id = c.parent_id;

alter view entry_detail set (security_invoker = on);
grant select on entry_detail to authenticated;

comment on view entry_detail is
  'Lineas con el nombre de su cuenta o categoria y los datos de su movimiento. '
  'Evita depender del embebido de PostgREST sobre claves foraneas compuestas.';
-- Cuantos movimientos usan cada cuenta y cada categoria.
--
-- La base ya IMPIDE borrar algo con movimientos: la clave foranea de entry no
-- tiene `on delete`, asi que salta foreign_key_violation. Pero la interfaz no
-- puede enterarse recien al fallar: necesita saberlo ANTES para ofrecer "borrar"
-- o "archivar" segun corresponda.

drop view if exists account_balance;

create view account_balance as
  select a.id           as account_id,
         a.ledger_id,
         a.name,
         a.kind,
         a.valuation,
         a.unit,
         a.is_spendable,
         a.institution,
         coalesce(sum(e.amount), 0) as balance,
         count(e.id)                as movimientos
    from account a
    left join entry e on e.account_id = a.id
   where a.archived_at is null
   group by a.id;

alter view account_balance set (security_invoker = on);
grant select on account_balance to authenticated;

comment on view account_balance is
  'Saldo en la UNIDAD de la cuenta, mas cuantos movimientos la usan. '
  'Para valuation=market el saldo son unidades, no plata.';

create view category_usage as
  select c.id  as category_id,
         c.ledger_id,
         c.name,
         c.kind,
         c.parent_id,
         c.is_system,
         c.sort_order,
         count(e.id) as movimientos
    from category c
    left join entry e on e.category_id = c.id
   where c.archived_at is null
   group by c.id;

alter view category_usage set (security_invoker = on);
grant select on category_usage to authenticated;
-- Gastos recurrentes y vencimientos — brief §10, sobre la tabla de ADR-016.
--
-- El brief es explicito: "no necesariamente quiero que el sistema ejecute pagos
-- automaticamente; inicialmente alcanza con que recuerde y proyecte". Asi que el
-- sistema NUNCA crea un movimiento solo: lo propone, y recien cuando el usuario
-- confirma se registra y se adelanta la fecha.

-- De que regla salio un movimiento. Sirve para dos cosas concretas:
--   ver el historial de un gasto recurrente ("todos los pagos del seguro")
--   saber si el periodo actual YA se registro, y no ofrecerlo dos veces
-- Primero la unicidad del lado referenciado: sin ella, la clave foranea
-- compuesta de abajo no tiene a que apuntar.
alter table scheduled_event add constraint scheduled_event_id_ledger_uk
  unique (id, ledger_id);

alter table transaction
  add column scheduled_event_id uuid,
  add constraint transaction_sched_same_ledger
    foreign key (scheduled_event_id, ledger_id)
    references scheduled_event(id, ledger_id) on delete set null;

create index transaction_sched_idx on transaction (scheduled_event_id)
  where scheduled_event_id is not null;

-- ---------------------------------------------------------------------------
-- Aritmetica de fechas
-- ---------------------------------------------------------------------------

create or replace function avanzar_fecha(p_desde date, p_frecuencia text)
returns date
language sql
immutable
set search_path = public, pg_temp
as $$
  select p_desde + case p_frecuencia
    when 'weekly'    then interval '1 week'
    when 'monthly'   then interval '1 month'
    when 'bimonthly' then interval '2 months'
    when 'quarterly' then interval '3 months'
    when 'biannual'  then interval '6 months'
    when 'yearly'    then interval '1 year'
  end
$$;

comment on function avanzar_fecha(date, text) is
  'Postgres ya resuelve bien el caso incomodo: 31 de enero + 1 mes da 28 de '
  'febrero, y no se rompe en anios bisiestos.';

-- ---------------------------------------------------------------------------
-- Registrar una ocurrencia: crea el movimiento Y adelanta la fecha, atomico.
--
-- Mismo criterio que create_transaction (ADR-019): si algo falla no puede quedar
-- el movimiento sin adelantar la fecha, ni la fecha adelantada sin movimiento.
-- SECURITY INVOKER explicito: RLS sigue aplicando.
-- ---------------------------------------------------------------------------

create or replace function register_scheduled(
  p_event    uuid,
  p_amount   numeric,
  p_on       date default null,   -- null = la fecha prevista de la regla
  p_account  uuid default null    -- null = la cuenta que tenga la regla
) returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  ev       scheduled_event%rowtype;
  v_cuenta uuid;
  v_fecha  date;
  v_tx     uuid;
  v_monto  numeric;
begin
  select * into ev from scheduled_event where id = p_event;
  if not found then
    raise exception 'No existe ese evento programado';
  end if;
  if ev.archived_at is not null then
    raise exception 'Ese evento esta archivado';
  end if;

  v_cuenta := coalesce(p_account, ev.account_id);
  v_fecha  := coalesce(p_on, ev.next_on);
  v_monto  := abs(coalesce(p_amount, ev.amount));

  if v_cuenta is null then
    raise exception 'Hace falta indicar con que cuenta se paga';
  end if;
  if v_monto is null or v_monto = 0 then
    raise exception 'Hace falta indicar el importe';
  end if;

  if ev.kind = 'recurring' then
    if ev.category_id is null then
      raise exception 'La regla no tiene categoria';
    end if;
    -- Un gasto normal: sale de la cuenta hacia la categoria. El convenio de
    -- signos es el mismo de siempre (modelo-de-datos §1).
    insert into transaction (ledger_id, occurred_on, description, kind, created_by,
                             scheduled_event_id)
         values (ev.ledger_id, v_fecha, ev.description, 'expense', auth.uid(), ev.id)
      returning id into v_tx;

    insert into entry (transaction_id, ledger_id, account_id, category_id, amount, unit)
    values (v_tx, ev.ledger_id, v_cuenta, null, -v_monto, ev.currency),
           (v_tx, ev.ledger_id, null, ev.category_id, v_monto, ev.currency);

    -- Se adelanta hasta pasar la fecha registrada: si estuvo vencido varios
    -- periodos, un solo registro no deberia dejarlo vencido otra vez.
    update scheduled_event
       set next_on = avanzar_fecha(next_on, frequency)
     where id = ev.id;

  else
    -- 'maturity': el vencimiento de un plazo fijo. Se resuelve en la etapa de
    -- inversiones; por ahora se rechaza en vez de inventar un asiento.
    raise exception 'Los vencimientos se registran desde la seccion de inversiones';
  end if;

  return v_tx;
end $$;

grant execute on function register_scheduled(uuid, numeric, date, uuid) to authenticated;
grant execute on function avanzar_fecha(date, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Lo que se viene
-- ---------------------------------------------------------------------------

create view upcoming as
  select s.id,
         s.ledger_id,
         s.kind,
         s.description,
         s.amount,
         s.currency,
         s.frequency,
         s.next_on,
         s.ends_on,
         s.category_id,
         c.name        as category_name,
         p.name        as category_parent,
         s.account_id,
         a.name        as account_name,
         (s.next_on - current_date) as dias,
         -- ya paso la fecha y nadie lo registro
         (s.next_on < current_date) as vencido
    from scheduled_event s
    left join category c on c.id = s.category_id
    left join category p on p.id = c.parent_id
    left join account  a on a.id = s.account_id
   where s.archived_at is null
     and (s.ends_on is null or s.ends_on >= current_date);

alter view upcoming set (security_invoker = on);
grant select on upcoming to authenticated;

comment on view upcoming is
  'Eventos programados vigentes, con cuantos dias faltan y si ya vencieron. '
  'No incluye los archivados ni los terminados.';

-- ---------------------------------------------------------------------------
-- Saltear un periodo sin registrar nada.
--
-- Hace falta de verdad: un impuesto que este bimestre no vino, una suscripcion
-- que se pauso. Sin esto el unico camino seria registrar un movimiento falso o
-- editar la fecha a mano, y las dos cosas ensucian los datos.
--
-- La aritmetica vive aca y no en el cliente: una sola definicion de "el proximo
-- periodo" evita que dos lugares del codigo no coincidan.
-- ---------------------------------------------------------------------------

create or replace function skip_scheduled(p_event uuid)
returns date
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare v_next date;
begin
  update scheduled_event
     set next_on = avanzar_fecha(next_on, frequency)
   where id = p_event and archived_at is null and kind = 'recurring'
returning next_on into v_next;

  if v_next is null then
    raise exception 'No se pudo saltear: el evento no existe, esta archivado o no es recurrente';
  end if;
  return v_next;
end $$;

grant execute on function skip_scheduled(uuid) to authenticated;
